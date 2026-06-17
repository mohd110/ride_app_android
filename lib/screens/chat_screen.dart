import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ChatScreen extends StatefulWidget {
  final String contactName;

  const ChatScreen({Key? key, required this.contactName}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [
    {'text': 'Hi! I\'m on my way to pickup.', 'sent': true, 'time': '2:14 PM'},
    {'text': 'Great, order is ready at the counter.', 'sent': false, 'time': '2:15 PM'},
    {'text': 'Thanks! ETA 8 minutes.', 'sent': true, 'time': '2:16 PM'},
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    if (_controller.text.trim().isEmpty) return;
    setState(() {
      _messages.add({'text': _controller.text.trim(), 'sent': true, 'time': 'Now'});
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.contactName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final m = _messages[i];
                final sent = m['sent'] as bool;
                return Align(
                  alignment: sent ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: sent ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: sent ? null : Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      m['text'] as String,
                      style: TextStyle(color: sent ? Colors.white : AppColors.textPrimary, fontSize: 13),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            color: AppColors.surface,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _send,
                  icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
