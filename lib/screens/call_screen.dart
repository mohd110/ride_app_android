import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';

class CallScreen extends StatelessWidget {
  final String contactName;
  final String phone;

  const CallScreen({Key? key, required this.contactName, required this.phone}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
            const Spacer(),
            const CircleAvatar(
              radius: 48,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.person_rounded, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 20),
            Text(contactName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(phone, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 8),
            const Text('Calling...', style: TextStyle(color: Colors.white54, fontSize: 13)),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _callBtn(Icons.mic_off_rounded, 'Mute'),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                      child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 32),
                    ),
                  ),
                  _callBtn(Icons.volume_up_rounded, 'Speaker'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _callBtn(IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}
