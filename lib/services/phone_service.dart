import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Places a real phone call via the device's own dialer app — replaces the
/// old CallScreen, which only simulated a call in-app and never actually
/// dialed anything. A normal Flutter app can't place a call itself; handing
/// off to `tel:` and letting Android's Phone app take over is the standard,
/// reliable way every delivery app does this.
class PhoneService {
  PhoneService._();

  static Future<void> call(BuildContext context, String phone) async {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number saved for this contact.')),
      );
      return;
    }

    final uri = Uri(scheme: 'tel', path: trimmed);
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the phone dialer.')),
      );
    }
  }
}
