import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class PermissionService {
  PermissionService._();

  /// Requests every permission the app needs in one pass.
  /// Called once after the rider logs in. Dialogs are shown in sequence so
  /// the rider understands WHY each permission is needed.  Non-fatal if any
  /// is denied — features degrade gracefully rather than blocking the rider.
  static Future<void> requestAll(BuildContext context) async {
    // 1. POST_NOTIFICATIONS (Android 13+) — order alert notifications
    final notif = await FlutterForegroundTask.checkNotificationPermission();
    if (notif != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (!context.mounted) return;

    // 2. SYSTEM_ALERT_WINDOW — floating order bubble over other apps
    final hasOverlay = await FlutterOverlayWindow.isPermissionGranted();
    if (!hasOverlay) {
      if (context.mounted) await _showOverlayDialog(context);
    }

    if (!context.mounted) return;

    // 3. Battery optimization exemption — keeps background service alive
    try {
      final isIgnoring = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
      if (!isIgnoring && context.mounted) {
        await _showBatteryDialog(context);
      }
    } catch (_) {
      // Method may not be available on all versions; skip silently.
    }
  }

  static Future<void> _showOverlayDialog(BuildContext context) async {
    final allow = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Show Order Bubbles?'),
        content: const Text(
          'To alert you about new orders while you\'re using other apps '
          '(Maps, WhatsApp, etc.), we need permission to draw over other apps.\n\n'
          'This shows a small delivery bubble — similar to how Rapido and Uber work.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Allow'),
          ),
        ],
      ),
    );
    if (allow == true) {
      await FlutterOverlayWindow.requestPermission();
    }
  }

  static Future<void> _showBatteryDialog(BuildContext context) async {
    final allow = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Keep Orders Reliable?'),
        content: const Text(
          'Some Android phones stop background services to save battery, '
          'causing missed orders.\n\n'
          'Tap Allow on the next screen to keep order alerts working even '
          'when the app is in the background.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Allow'),
          ),
        ],
      ),
    );
    if (allow == true) {
      try {
        await FlutterForegroundTask.openIgnoreBatteryOptimizationSettings();
      } catch (_) {
        // Method unavailable on this version — skip.
      }
    }
  }
}
