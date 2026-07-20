import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../app_state.dart';
import '../services/settings_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/detail_page_scaffold.dart';

/// Real, persisted settings — previously every toggle here was local State
/// that reset the moment you left the screen, and "Dark mode"/"Auto-accept
/// nearby" didn't do anything at all (no dark theme, no proximity-matching
/// feature exists in the app). Those two are gone rather than kept as inert
/// decoration; Push Notifications and Sound Alerts are real and enforced by
/// NotificationService/background_service.dart.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifications = true;
  bool _soundAlerts = true;
  bool _loaded = false;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      SettingsService.pushNotificationsEnabled(),
      SettingsService.soundAlertsEnabled(),
      PackageInfo.fromPlatform(),
    ]);
    if (!mounted) return;
    final packageInfo = results[2] as PackageInfo;
    setState(() {
      _pushNotifications = results[0] as bool;
      _soundAlerts = results[1] as bool;
      _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final deviceId = AppState.instance.deviceId;

    return DetailPageScaffold(
      title: 'Settings',
      children: [
        if (!_loaded)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Push notifications', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Orders, payouts, and bonuses', style: TextStyle(fontSize: 11)),
                  value: _pushNotifications,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) {
                    setState(() => _pushNotifications = v);
                    SettingsService.setPushNotificationsEnabled(v);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Sound alerts', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Ringtone and vibration for new orders', style: TextStyle(fontSize: 11)),
                  value: _soundAlerts,
                  activeThumbColor: AppColors.primary,
                  onChanged: _pushNotifications
                      ? (v) {
                          setState(() => _soundAlerts = v);
                          SettingsService.setSoundAlertsEnabled(v);
                        }
                      : null,
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Navigation app', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Google Maps', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('App version', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                _appVersion.isNotEmpty ? 'Rider Connect v$_appVersion' : '—',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text('Device ID: ${deviceId ?? '—'}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}
