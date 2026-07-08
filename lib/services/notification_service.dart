import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import 'background_service.dart';
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

  /// Safety cap on how long the ring/vibration continues if the rider never
  /// opens the app, accepts, or rejects. There's no server-side order TTL to
  /// key off, so this is what stands in for "the order expired" — every
  /// other stop condition (open app / accept / reject) calls [stopAlert]
  /// directly and fires well before this.
  static const _ringExpiryDuration = Duration(seconds: 60);

  /// Vibrate/pause pattern in ms: [initial delay, buzz, pause, buzz, pause].
  /// `repeat: 1` loops from the first buzz (skipping the initial delay) for
  /// as long as the ring is active — mimics an incoming-call buzz.
  static const _vibrationPattern = [0, 800, 400, 800, 400];

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _initialized = false;
  Timer? _stopTimer;

  Future<void> initialize() async {
    if (_initialized) return;

    // Configure the Android foreground-service options (channel, restart on
    // boot, wake-lock). Must happen before the service is started.
    initForegroundTask();

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

    // Route playback over the ringtone stream — like an incoming call —
    // instead of the default media stream. Media volume is very often turned
    // down or muted independently of ringer volume, which was why the alert
    // was barely audible; USAGE_NOTIFICATION_RINGTONE plays on the stream
    // riders actually expect an "incoming order" alert to use.
    await _audioPlayer.setAudioContext(AudioContext(
      android: const AudioContextAndroid(
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.notificationRingtone,
        audioFocus: AndroidAudioFocus.gainTransient,
      ),
    ));
    // Loop mode so the alert rings continuously until we stop it.
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.setVolume(1.0);

    _initialized = true;
  }

  /// Plays the alert ring + vibration in a loop until [stopAlert] is called
  /// (rider opens the app, accepts, or rejects) or [_ringExpiryDuration]
  /// elapses. Calling this again while already ringing restarts the window.
  Future<void> showNewOrders(List<AvailableOrderSummary> orders) async {
    if (!_initialized || orders.isEmpty) return;

    final first = orders.first;
    final title = orders.length == 1 ? 'New order available' : '${orders.length} new orders available';
    final body = orders.length == 1
        ? '${first.restaurantName} → ${first.dropoffAddress} • ₹${first.estimatedEarnings.toStringAsFixed(2)} est. earnings'
        : 'Tap to view available deliveries';

    // Start (or restart) the looping alert ring.
    try {
      _stopTimer?.cancel();
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/new_order_alert.mp3'));
      _stopTimer = Timer(_ringExpiryDuration, stopAlert);
    } catch (_) {
      // Best-effort — the system notification sound below is the fallback.
    }

    // Continuous vibration alongside the ring — separate from the
    // notification channel's one-shot vibrate-on-post.
    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(pattern: _vibrationPattern, repeat: 1);
      }
    } catch (_) {
      // Best-effort — not every device has a controllable vibrator.
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
            fullScreenIntent: true,
          ),
        ),
      );
    } catch (_) {
      // Best-effort — the in-app sound above already fired.
    }
  }

  /// Immediately stops the ring + vibration (rider opened the app, accepted,
  /// or rejected the order).
  Future<void> stopAlert() async {
    _stopTimer?.cancel();
    _stopTimer = null;
    try {
      await _audioPlayer.stop();
    } catch (_) {}
    try {
      await Vibration.cancel();
    } catch (_) {}
  }
}
