import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/detail_page_scaffold.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Map<String, bool> _toggles = {
    'Push notifications': true,
    'Dark mode': false,
    'Auto-accept nearby': false,
    'Sound alerts': true,
  };

  @override
  Widget build(BuildContext context) {
    return DetailPageScaffold(
      title: 'Settings',
      children: [
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: MockData.settingsOptions.map((opt) {
              final title = opt['title'] as String;
              final enabled = opt['enabled'];
              return Column(
                children: [
                  ListTile(
                    title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text(opt['subtitle'] as String, style: const TextStyle(fontSize: 11)),
                    trailing: enabled is bool
                        ? Switch(
                            value: _toggles[title] ?? false,
                            activeColor: AppColors.primary,
                            onChanged: (v) => setState(() => _toggles[title] = v),
                          )
                        : const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                    onTap: enabled == null
                        ? () => ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Navigation app: Google Maps (default)')),
                            )
                        : null,
                  ),
                  if (title != 'Sound alerts') const Divider(height: 1),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('App version', style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 4),
              Text('Rider Connect v4.2.1-stable', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              SizedBox(height: 8),
              Text('Device ID: 88-X9-RDR', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}
