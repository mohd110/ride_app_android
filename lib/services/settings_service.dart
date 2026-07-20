import 'package:shared_preferences/shared_preferences.dart';

/// Rider-facing app preferences (Settings screen) — device-local, read
/// directly from SharedPreferences (not routed through AppState) so the
/// background foreground-task isolate and NotificationService can check
/// them too. Those run in a separate Dart isolate/fresh memory space with
/// their own uninitialized AppState.instance, but SharedPreferences is the
/// one storage all of them can see — same reason background_service.dart
/// already reads `device_id` directly instead of through AppState.
class SettingsService {
  SettingsService._();

  static const _pushNotificationsKey = 'settings_push_notifications';
  static const _soundAlertsKey = 'settings_sound_alerts';

  static Future<bool> pushNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pushNotificationsKey) ?? true;
  }

  static Future<void> setPushNotificationsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pushNotificationsKey, value);
  }

  static Future<bool> soundAlertsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_soundAlertsKey) ?? true;
  }

  static Future<void> setSoundAlertsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundAlertsKey, value);
  }
}
