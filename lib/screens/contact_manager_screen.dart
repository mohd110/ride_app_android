import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/detail_page_scaffold.dart';
import 'chat_screen.dart';
import 'call_screen.dart';

class ContactManagerScreen extends StatelessWidget {
  const ContactManagerScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DetailPageScaffold(
      title: 'Contact Hub Manager',
      children: [
        const Text(
          'New to the fleet? Reach out to your local hub for onboarding and shift scheduling.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 16),
        ...MockData.hubManagers.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m['name']!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    Text(m['role']!, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(m['hours']!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => CallScreen(contactName: m['name']!, phone: m['phone']!)),
                            ),
                            icon: const Icon(Icons.phone_rounded, size: 16),
                            label: const Text('Call'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ChatScreen(contactName: m['name']!)),
                            ),
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                            label: const Text('Message'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }
}
