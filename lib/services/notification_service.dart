import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'order_service.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _channelId = 'new_orders';
  static const _channelName = 'New Orders';
  static const _channelDescription = 'Alerts when a new delivery order is available to claim';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

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
      enableVibration: true,
    ));
    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<void> showNewOrders(List<AvailableOrderSummary> orders) async {
    if (!_initialized || orders.isEmpty) return;

    final first = orders.first;
    final title = orders.length == 1 ? 'New order available' : '${orders.length} new orders available';
    final body = orders.length == 1
        ? '${first.restaurantName} → ${first.dropoffAddress} • ₹${first.deliveryFee.toStringAsFixed(2)}'
        : 'Tap to view available deliveries';

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
          enableVibration: true,
        ),
      ),
    );
  }
}
