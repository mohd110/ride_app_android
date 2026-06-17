import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/detail_page_scaffold.dart';
import 'chat_screen.dart';
import 'call_screen.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('24/7 Live Support', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    Text('Avg. response: under 3 min', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
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
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CallScreen(contactName: 'Fleet Support', phone: '+1 (800) 555-0199')),
                ),
                icon: const Icon(Icons.phone_rounded, size: 18),
                label: const Text('Call Now'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChatScreen(contactName: 'Fleet Support')),
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
                onTap: () => _showTopic(context, topic.title, topic.description),
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
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Email support', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              SizedBox(height: 4),
              Text('support@fleetconnect.com', style: TextStyle(color: AppColors.primary, fontSize: 13)),
              SizedBox(height: 8),
              Text('Include your Rider ID #4921 for faster help.', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  void _showTopic(BuildContext context, String title, String description) {
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
                Navigator.push(ctx, MaterialPageRoute(builder: (_) => const ChatScreen(contactName: 'Fleet Support')));
              },
              child: const Text('Chat with an agent'),
            ),
          ],
        ),
      ),
    );
  }
}
