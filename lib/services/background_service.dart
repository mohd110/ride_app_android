import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import 'settings_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Background service public API — called from AppState
// ─────────────────────────────────────────────────────────────────────────────

/// Call once on app launch (before runApp). Sets up the Android foreground
/// service channel and options. Idempotent — safe to call multiple times.
void initForegroundTask() {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'rider_bg_service',
      channelName: 'Rider Background Service',
      channelDescription:
          'Keeps RiderConnect connected to receive new delivery orders',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      // Health-check / Realtime reconnect interval.
      eventAction: ForegroundTaskEventAction.repeat(30000),
      autoRunOnBoot: true,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );
}

/// Starts (or updates) the foreground service.
/// Safe to call when already running — it just updates the notification text.
Future<void> startRiderForegroundService() async {
  final isRunning = await FlutterForegroundTask.isRunningService;
  if (isRunning) {
    await FlutterForegroundTask.updateService(
      notificationTitle: 'Rider Connect — Online',
      notificationText: 'Watching for new delivery orders…',
    );
    return;
  }
  await FlutterForegroundTask.startService(
    serviceId: 1001,
    notificationTitle: 'Rider Connect — Online',
    notificationText: 'Watching for new delivery orders…',
    callback: _backgroundEntryPoint,
  );
}

/// Stops the foreground service and removes its persistent notification.
Future<void> stopRiderForegroundService() async {
  await FlutterForegroundTask.stopService();
}

// ─────────────────────────────────────────────────────────────────────────────
// Background isolate entry point
// ─────────────────────────────────────────────────────────────────────────────

/// Top-level entry point invoked by the Android foreground service in a
/// background Dart isolate. Must be annotated with @pragma('vm:entry-point').
@pragma('vm:entry-point')
void _backgroundEntryPoint() {
  FlutterForegroundTask.setTaskHandler(_RiderTaskHandler());
}

// ─────────────────────────────────────────────────────────────────────────────
// Task handler — runs inside the background Dart isolate
// ─────────────────────────────────────────────────────────────────────────────

class _RiderTaskHandler extends TaskHandler {
  RealtimeChannel? _realtimeChannel;
  RealtimeChannel? _sessionChannel;
  Set<String> _seenOrderIds = {};
  String? _myDeviceId;
  final _notif = FlutterLocalNotificationsPlugin();

  static const _ordersChannelId = 'new_orders_v2';
  static const _seenIdsKey = 'bg_seen_order_ids';

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // supabase_flutter persists the auth session in SharedPreferences, which
    // is shared between the main and background isolates on Android. So
    // initializing here will automatically restore the rider's session.
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey, // ignore: deprecated_member_use
      );
    } catch (_) {
      // Already initialized in this isolate (e.g. service restarted after
      // boot where Supabase was already inited by a prior restart).
    }

    // Set up the local-notification plugin inside this isolate so we can show
    // order alerts without the main Flutter app being open.
    await _notif.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await _notif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _ordersChannelId,
          'New Orders',
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('new_order_alert'),
          enableVibration: true,
        ));

    // Restore the set of order IDs we've already alerted about, so we don't
    // spam the rider with duplicates when Realtime reconnects.
    final prefs = await SharedPreferences.getInstance();
    _seenOrderIds = (prefs.getStringList(_seenIdsKey) ?? []).toSet();
    // Load the device ID so we can detect if OUR session is deactivated.
    _myDeviceId = prefs.getString('device_id');

    _subscribeRealtime();
    _subscribeSessionWatch();
    // Also do an immediate poll so the rider isn't waiting for the first
    // Realtime event if the service started while orders were already pending.
    await _pollOrders();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Reconnect Realtime if the WebSocket silently dropped (common on mobile
    // when the device wakes from deep sleep or switches networks), then poll
    // regardless as a backup — catches anything that arrived during the gap,
    // and covers the case where reconnecting itself silently fails.
    _ensureRealtimeConnected().then((_) => _pollOrders());
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    await _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
    await _sessionChannel?.unsubscribe();
    _sessionChannel = null;
  }

  // ── Realtime subscription ──────────────────────────────────────────────────

  void _subscribeRealtime() {
    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) return;

    _realtimeChannel?.unsubscribe();
    _realtimeChannel = client
        .channel('bg-orders')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'orders',
          callback: (payload) => _onNewOrderInserted(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          callback: (payload) => _onOrderUpdated(payload.newRecord),
        )
        .subscribe();
  }

  /// Checking `_realtimeChannel == null` alone isn't enough — the socket can
  /// silently drop (Doze, network switch, OS killing the connection) without
  /// the channel *reference* ever becoming null, so that check alone would
  /// never notice and never reconnect. `client.realtime.isConnected` reads
  /// the actual socket state, so a genuine silent drop gets caught here and
  /// forces both a socket reconnect and a fresh channel resubscribe. This
  /// was the main reason order alerts were inconsistent — Realtime could go
  /// stale for the rest of the session with everything still relying on the
  /// separate 30s poll (itself subject to the same Doze throttling) as the
  /// only remaining path.
  Future<void> _ensureRealtimeConnected() async {
    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) return;

    if (!client.realtime.isConnected) {
      // RealtimeChannel.subscribe() reconnects the underlying socket itself
      // (`if (!socket.isConnected) socket.connect();`) before joining, so a
      // fresh subscribe is enough — no need to touch the socket directly.
      _subscribeRealtime();
      _subscribeSessionWatch();
      return;
    }

    if (_realtimeChannel == null) _subscribeRealtime();
    if (_sessionChannel == null) _subscribeSessionWatch();
  }

  /// Watches rider_sessions for this rider. If OUR device's session is
  /// deactivated (another phone logged in), stop the foreground service
  /// immediately so the old phone stops receiving order notifications.
  void _subscribeSessionWatch() {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    if (session == null || _myDeviceId == null) return;

    final riderId = client.auth.currentUser?.id;
    if (riderId == null) return;

    _sessionChannel?.unsubscribe();
    _sessionChannel = client
        .channel('bg-session-watch-$riderId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'rider_sessions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'rider_id',
            value: riderId,
          ),
          callback: (payload) async {
            final row = payload.newRecord;
            final rowDeviceId = row['device_id'] as String?;
            final isActive = row['is_active'] as bool? ?? true;

            if (rowDeviceId == _myDeviceId && !isActive) {
              // Our session was superseded — stop everything.
              await _realtimeChannel?.unsubscribe();
              _realtimeChannel = null;
              await _sessionChannel?.unsubscribe();
              _sessionChannel = null;
              await FlutterForegroundTask.stopService();
            }
          },
        )
        .subscribe();
  }

  // ── New order inserted ─────────────────────────────────────────────────────

  void _onNewOrderInserted(Map<String, dynamic> record) async {
    final id = record['id'] as String?;
    final status = record['status'] as String?;
    final riderId = record['rider_id'];

    if (id == null) return;
    if (_seenOrderIds.contains(id)) return;
    // Only alert for unassigned orders that are ready for pickup.
    if (riderId != null) return;
    if (status != 'ready') return;

    await _markSeen(id);
    await _showOrderNotification(
      title: 'New Order Available',
      body: 'A new delivery is ready for pickup. Tap to claim it.',
    );
    // Tell the main isolate to refresh the list AND show the floating bubble
    // immediately (before the refresh cycle completes).
    FlutterForegroundTask.sendDataToMain({'action': 'show_overlay', 'count': 1});
    FlutterForegroundTask.sendDataToMain({'action': 'refresh_orders'});
  }

  // ── Order status updated ───────────────────────────────────────────────────

  void _onOrderUpdated(Map<String, dynamic> record) async {
    final id = record['id'] as String?;
    final status = record['status'] as String?;
    final riderId = record['rider_id'] as String?;

    if (id == null) return;

    final myId = Supabase.instance.client.auth.currentUser?.id;

    // Alert if this order just became available (unassigned, ready).
    if (riderId == null &&
        status == 'ready' &&
        !_seenOrderIds.contains(id)) {
      await _markSeen(id);
      await _showOrderNotification(
        title: 'New Order Available',
        body: 'A new delivery is ready for pickup. Tap to claim it.',
      );
      FlutterForegroundTask.sendDataToMain({'action': 'show_overlay', 'count': 1});
      FlutterForegroundTask.sendDataToMain({'action': 'refresh_orders'});
      return;
    }

    // Alert if THIS rider was just assigned this order.
    if (myId != null && riderId == myId && !_seenOrderIds.contains('assigned_$id')) {
      await _markSeen('assigned_$id');
      await _showOrderNotification(
        title: 'Order Assigned to You',
        body: 'You have been assigned a delivery. Tap to open.',
      );
      FlutterForegroundTask.sendDataToMain({'action': 'refresh_orders'});
    }
  }

  // ── Backup polling ─────────────────────────────────────────────────────────

  Future<void> _pollOrders() async {
    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) return;

    try {
      final rows = await client
          .from('orders')
          .select('id, status, rider_id')
          .inFilter('status', ['ready'])
          .isFilter('rider_id', null)
          .limit(20);

      bool hasNew = false;
      for (final row in (rows as List<dynamic>)) {
        final id = row['id'] as String?;
        if (id == null || _seenOrderIds.contains(id)) continue;
        await _markSeen(id);
        hasNew = true;
      }

      if (hasNew) {
        await _showOrderNotification(
          title: 'New Order Available',
          body: 'A new delivery is ready for pickup. Tap to claim it.',
        );
        FlutterForegroundTask.sendDataToMain({'action': 'refresh_orders'});
      }
    } catch (_) {
      // Transient error — the next poll or Realtime event will catch it.
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<void> _markSeen(String id) async {
    _seenOrderIds.add(id);
    // Cap at 200 entries to keep SharedPreferences from growing unbounded.
    if (_seenOrderIds.length > 200) {
      _seenOrderIds = _seenOrderIds.skip(_seenOrderIds.length - 200).toSet();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_seenIdsKey, _seenOrderIds.toList());
  }

  // Must match NotificationService.newOrderPayload (lib/services/
  // notification_service.dart) — duplicated rather than imported to avoid a
  // circular import between the two isolates' notification setup; each
  // isolate already duplicates its own copy of the channel id/settings for
  // the same reason.
  static const _newOrderPayload = 'new_order';

  // Guaranteed OS-level buzz tied directly to the notification post itself
  // (not a separate app-triggered Vibration.vibrate() call) — this is the
  // ONLY vibration source when the main isolate isn't alive to run its own
  // richer continuous ring, so it needs to fire reliably on its own rather
  // than depending on a second, independent vibration call that could be
  // suppressed separately. Three buzzes, finite (not looped) since this
  // isolate has no clean way to stop an indefinite one.
  static final _vibrationPattern = Int64List.fromList([0, 700, 300, 700, 300, 700]);

  Future<void> _showOrderNotification({
    required String title,
    required String body,
  }) async {
    // Settings screen — "Push notifications" off means no alert at all,
    // read directly from SharedPreferences since this isolate never runs
    // through AppState. "Sound alerts" off keeps the notification itself
    // but drops sound/vibration.
    if (!await SettingsService.pushNotificationsEnabled()) return;
    final soundEnabled = await SettingsService.soundAlertsEnabled();

    try {
      await _notif.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _ordersChannelId,
            'New Orders',
            importance: Importance.max,
            priority: Priority.high,
            playSound: soundEnabled,
            sound: soundEnabled ? const RawResourceAndroidNotificationSound('new_order_alert') : null,
            enableVibration: soundEnabled,
            vibrationPattern: soundEnabled ? _vibrationPattern : null,
            // Wake the screen so the rider sees the alert immediately.
            fullScreenIntent: true,
            category: AndroidNotificationCategory.call,
          ),
        ),
        payload: _newOrderPayload,
      );
    } catch (_) {
      // Best-effort — if the notification fails, the poll/Realtime event
      // will still update the app when it's opened.
    }
  }
}
