import 'package:flutter/material.dart';
import '../services/order_service.dart';
import '../services/phone_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/detail_page_scaffold.dart';
import 'chat_screen.dart';

/// Reached pre-login from the "New to the fleet?" link, so it can't rely on
/// AppState/an active session — it reads the public company_info singleton
/// row directly via OrderService.fetchCompanyInfo().
class ContactManagerScreen extends StatefulWidget {
  const ContactManagerScreen({Key? key}) : super(key: key);

  @override
  State<ContactManagerScreen> createState() => _ContactManagerScreenState();
}

class _ContactManagerScreenState extends State<ContactManagerScreen> {
  Map<String, dynamic>? _info;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final info = await OrderService().fetchCompanyInfo();
    if (!mounted) return;
    setState(() {
      _info = info;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DetailPageScaffold(
      title: 'Contact Hub Manager',
      children: [
        const Text(
          'New to the fleet? Reach out to us for onboarding and shift scheduling.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else
          _buildContact(context),
      ],
    );
  }

  Widget _buildContact(BuildContext context) {
    final companyName = (_info?['company_name'] as String?)?.trim();
    final name = companyName?.isNotEmpty == true ? companyName! : 'Support';
    final phone = _info?['support_phone'] as String?;
    final email = _info?['support_email'] as String?;
    final hours = _info?['working_hours'] as String?;

    if (phone?.isNotEmpty != true && email?.isNotEmpty != true) {
      return AppCard(
        dashed: true,
        child: Column(
          children: const [
            Icon(Icons.support_agent_rounded, color: AppColors.textMuted, size: 36),
            SizedBox(height: 12),
            Text(
              'Contact info unavailable',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 6),
            Text(
              'This hasn\'t been set up on the backend yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
            ),
          ],
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          if (email?.isNotEmpty == true) Text(email!, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          if (hours?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(hours!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: phone?.isNotEmpty == true ? () => PhoneService.call(context, phone!) : null,
                  icon: const Icon(Icons.phone_rounded, size: 16),
                  label: const Text('Call'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ChatScreen(contactName: name)),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: const Text('Message'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
