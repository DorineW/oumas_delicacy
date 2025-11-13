import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../screens/customer_chat_screen.dart';

class CustomerSupportBadgeButton extends StatefulWidget {
  final String label;
  const CustomerSupportBadgeButton({super.key, this.label = 'Support'});

  @override
  State<CustomerSupportBadgeButton> createState() => _CustomerSupportBadgeButtonState();
}

class _CustomerSupportBadgeButtonState extends State<CustomerSupportBadgeButton> {
  String? _roomId;
  Stream<Map<String, dynamic>?>? _roomStream;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final roomId = await ChatService.instance.getOrCreateCustomerRoom();
      _roomId = roomId;
      _roomStream = ChatService.instance.streamSingleRoom(roomId);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        width: 48,
        height: 48,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_error != null) {
      return IconButton(
        icon: const Icon(Icons.error_outline, color: Colors.red),
        onPressed: () {},
      );
    }
    if (_roomStream == null) {
      return const SizedBox();
    }
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _roomStream,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final unread = (data?['unread_customer'] ?? 0) as int;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            ElevatedButton(
              onPressed: _roomId == null
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CustomerChatScreen(chatId: _roomId),
                        ),
                      );
                    },
              child: Text(widget.label),
            ),
            if (unread > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    unread.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
