import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'order_service.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  // "_v2" forces Android to create a fresh channel with our custom sound —
  // channel settings (sound, importance) are locked in on first creation and
  // ignored on later app updates, so a renamed id is the only way to fix a
  // previously-installed channel that was created without sound.
  static const _channelId = 'new_orders_v2';
  static const _channelName = 'New Orders';
  static const _channelDescription = 'Alerts when a new delivery order is available to claim';
  static const _soundResource = 'new_order_alert';

  /// How long the alert ring plays before auto-stopping.
  static const _alertDuration = Duration(seconds: 10);

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _initialized = false;
  Timer? _stopTimer;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidSettings),
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(_soundResource),
      enableVibration: true,
    ));
    await androidPlugin?.requestNotificationsPermission();

    // Loop mode so the alert rings continuously until we stop it.
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.setVolume(1.0);

    _initialized = true;
  }

  /// Plays the alert sound in a loop for [_alertDuration] then stops automatically.
  /// Calling this again while already ringing restarts the 10-second window.
  Future<void> showNewOrders(List<AvailableOrderSummary> orders) async {
    if (!_initialized || orders.isEmpty) return;

    final first = orders.first;
    final title = orders.length == 1 ? 'New order available' : '${orders.length} new orders available';
    final body = orders.length == 1
        ? '${first.restaurantName} → ${first.dropoffAddress} • ₹${first.deliveryFee.toStringAsFixed(2)}'
        : 'Tap to view available deliveries';

    // Start (or restart) the looping alert ring.
    // The stop-timer is reset so every new-order event gives a fresh 10 s window.
    try {
      _stopTimer?.cancel();
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/new_order_alert.ogg'));
      // Auto-stop after the configured duration.
      _stopTimer = Timer(_alertDuration, stopAlert);
    } catch (_) {
      // Best-effort — the system notification sound below is the fallback.
    }

    try {
      await _plugin.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            sound: RawResourceAndroidNotificationSound(_soundResource),
            enableVibration: true,
          ),
        ),
      );
    } catch (_) {
      // Best-effort — the in-app sound above already fired.
    }
  }

  /// Immediately stops the alert ring (called when rider accepts or dismisses).
  Future<void> stopAlert() async {
    _stopTimer?.cancel();
    _stopTimer = null;
    try {
      await _audioPlayer.stop();
    } catch (_) {}
  }
}
