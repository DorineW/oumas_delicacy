import 'package:flutter/material.dart';
import '../screens/customer_chat_screen.dart';

class CustomerSupportButton extends StatelessWidget {
  final String label;
  const CustomerSupportButton({super.key, this.label = 'Chat with Support'});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.chat_bubble_outline),
      label: Text(label),
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const CustomerChatScreen(), // auto-room creation
          ),
        );
      },
    );
  }
}
