import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../services/order_service.dart';
import '../services/phone_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/detail_page_scaffold.dart';
import 'chat_screen.dart';

/// Contact details (phone/email/company name) come from the `company_info`
/// singleton row via OrderService.fetchCompanyInfo(); supportTopics stays
/// static since it's generic help-category copy, not per-company data.
class SupportScreen extends StatefulWidget {
  const SupportScreen({Key? key}) : super(key: key);

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
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
    final companyName = (_info?['company_name'] as String?)?.trim();
    final contactName = companyName?.isNotEmpty == true ? companyName! : 'Support';
    final supportPhone = _info?['support_phone'] as String?;
    final supportEmail = _info?['support_email'] as String?;

    return DetailPageScaffold(
      title: 'Support & Help',
      children: [
        AppCard(
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.headset_mic_rounded, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$contactName Support', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const Text('Reach out any time', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _loading
                    ? null
                    : () {
                        if (supportPhone?.isNotEmpty == true) {
                          PhoneService.call(context, supportPhone!);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Support phone number is not available.')),
                          );
                        }
                      },
                icon: const Icon(Icons.phone_rounded, size: 18),
                label: const Text('Call Now'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ChatScreen(contactName: contactName)),
                ),
                icon: const Icon(Icons.chat_rounded, size: 18),
                label: const Text('Live Chat'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text('Browse topics', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 10),
        ...MockData.supportTopics.map((topic) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => _showTopic(context, topic.title, topic.description, contactName),
                borderRadius: BorderRadius.circular(16),
                child: AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(topic.icon, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(topic.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            Text(topic.description, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 18),
                    ],
                  ),
                ),
              ),
            )),
        if (supportEmail?.isNotEmpty == true) ...[
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Email support', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 4),
                Text(supportEmail!, style: const TextStyle(color: AppColors.primary, fontSize: 13)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _showTopic(BuildContext context, String title, String description, String contactName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text(description, style: const TextStyle(color: AppColors.textSecondary, height: 1.4)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(ctx, MaterialPageRoute(builder: (_) => ChatScreen(contactName: contactName)));
              },
              child: const Text('Chat with an agent'),
            ),
          ],
        ),
      ),
    );
  }
}
