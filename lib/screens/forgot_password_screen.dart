import 'package:flutter/material.dart';
import '../config/supabase_client.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/detail_page_scaffold.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _sent = false;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _loading = true);
    try {
      await supabase.auth.resetPasswordForEmail(email);
      setState(() => _sent = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send reset link. Check the email address.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DetailPageScaffold(
      title: 'Forgot Password',
      children: [
        const Text(
          'Enter your rider email. We will send a password reset link.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 20),
        if (!_sent) ...[
          const Text('Email', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'rider@demo.com'),
          ),
        ] else
          AppCard(
            child: Row(
              children: const [
                Icon(Icons.mark_email_read_rounded, color: AppColors.success, size: 32),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Reset link sent! Check your inbox and spam folder.',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
      ],
      bottomAction: ElevatedButton(
        onPressed: _loading
            ? null
            : () {
                if (_sent) {
                  Navigator.of(context).pop();
                } else {
                  _sendReset();
                }
              },
        child: _loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(_sent ? 'Back to Login' : 'Send Reset Link'),
      ),
    );
  }
}
