import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Sends customer-facing order-status push notifications through the same
/// API the Admin Dashboard and customer panel use — hosted on the customer
/// panel's own Vercel deployment, since this app has no server of its own
/// for this.
class PushNotificationService {
  PushNotificationService._();

  static const _endpoint = 'https://local-delivery-app-zeta.vercel.app/api/push/send';

  /// Fire-and-forget by design: never `await` this at the call site. The
  /// order status update it follows must already have succeeded and must
  /// never be blocked or rolled back by a push notification failing to
  /// send — any failure here is just logged.
  static void sendOrderStatusPush({
    required String? customerId,
    required String orderId,
    required String title,
    required String body,
    String tag = 'order-update',
  }) {
    if (customerId == null || customerId.isEmpty) {
      debugPrint('Push notification skipped: order $orderId has no customer_id');
      return;
    }

    http.post(
      Uri.parse(_endpoint),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'customerId': customerId,
        'title': title,
        'body': body,
        'url': '/orders/$orderId',
        'tag': tag,
      }),
    ).then((response) {
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          'Push notification for order $orderId returned ${response.statusCode}: ${response.body}',
        );
      }
    }).catchError((Object e) {
      debugPrint('Push notification failed for order $orderId: $e');
    });
  }
}
