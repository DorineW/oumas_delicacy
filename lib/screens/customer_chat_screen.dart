// lib/screens/customer_chat_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/chat_service.dart';
import '../constants/colors.dart';

class CustomerChatScreen extends StatefulWidget {
  final String? chatId; // optional: auto-create if null
  const CustomerChatScreen({super.key, this.chatId});

  @override
  State<CustomerChatScreen> createState() => _CustomerChatScreenState();
}

class _CustomerChatScreenState extends State<CustomerChatScreen> {
  Stream<List<Map<String, dynamic>>>? _messagesStream;
  String? _uid;
  String? _roomId;
  bool _initializing = true;
  String? _initError;
  final List<Map<String, dynamic>> _optimistic = []; // temp messages

  @override
  void initState() {
    super.initState();
    _uid = Supabase.instance.client.auth.currentUser?.id;
    _initRoom();
  }

  Future<void> _initRoom() async {
    try {
      final existing = widget.chatId;
      final roomId = existing ?? await ChatService.instance.getOrCreateCustomerRoom();
      _roomId = roomId;
      _messagesStream = ChatService.instance.streamCustomerRoom(roomId);
      await ChatService.instance.markRoomRead(roomId);
    } catch (e) {
      _initError = e.toString();
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Support Chat'),
        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.white),
        titleTextStyle: const TextStyle(
          color: AppColors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessagesArea()),
          _MessageInput(roomIdProvider: () => _roomId),
        ],
      ),
    );
  }

  Widget _buildMessagesArea() {
    if (_initializing) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_initError != null) {
      return Center(child: Text('Error: $_initError'));
    }
    if (_messagesStream == null || _roomId == null) {
      return const Center(child: Text('Unable to load chat'));
    }
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _messagesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final messages = snapshot.data ?? const [];
        final all = [...messages, ..._optimistic];
        if (all.isEmpty) {
          return const Center(child: Text('No messages yet'));
        }
        final sorted = [...all]
          ..sort((a, b) => DateTime.parse(b['created_at'] as String)
              .compareTo(DateTime.parse(a['created_at'] as String)));
        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.all(16),
          itemCount: sorted.length,
          itemBuilder: (context, index) {
            final m = sorted[index];
            final isMe = m['sender_id'] == _uid;
            final createdAt = DateTime.tryParse(m['created_at'] as String? ?? '');
            return _ChatBubble(
              message: (m['content'] ?? '') as String,
              time: _formatTs(createdAt),
              isMe: isMe,
            );
          },
        );
      },
    );
  }

  String _formatTs(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    
    // Format time in 12-hour format with AM/PM
    final hour12 = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour12:${dt.minute.toString().padLeft(2, '0')} $amPm';
    
    if (now.difference(dt).inDays >= 1) {
      return '${dt.month}/${dt.day} $timeStr';
    }
    return timeStr;
  }
}

class _ChatBubble extends StatelessWidget {
  final String message;
  final String time;
  final bool isMe;

  const _ChatBubble({
    required this.message,
    required this.time,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : AppColors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft:
                isMe ? const Radius.circular(12) : const Radius.circular(4),
            bottomRight:
                isMe ? const Radius.circular(4) : const Radius.circular(12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(
                color: isMe ? AppColors.white : AppColors.darkText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                fontSize: 10,
                color: isMe
                    ? AppColors.white.withOpacity(0.7)
                    : AppColors.darkText.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageInput extends StatefulWidget {
  final String? Function() roomIdProvider; // returns current room id or null
  const _MessageInput({required this.roomIdProvider});

  @override
  State<_MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<_MessageInput> {
  final TextEditingController _controller = TextEditingController();
  bool _sending = false;

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    final roomId = widget.roomIdProvider();
    if (roomId == null) return; // still initializing
    setState(() => _sending = true);
    try {
      // optimistic add
      final now = DateTime.now().toIso8601String();
      final parentState = context.findAncestorStateOfType<_CustomerChatScreenState>();
      parentState?._optimistic.add({
        'id': 'optimistic_${now}_${text.hashCode}',
        'room_id': roomId,
        'sender_id': ChatService.instance.userId,
        'content': text,
        'created_at': now,
      });
      ChatService.instance.sendMessage(roomId: roomId, content: text).catchError((e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Send failed: $e')),
        );
      });
      _controller.clear();
      await ChatService.instance.markRoomRead(roomId);
      // NOTE: Removed problematic optimistic flush - the Supabase stream will
      // automatically update with the real message, preventing duplicates/disappearances
    } catch (_) {
      // swallow errors for now
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.background, width: 1)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(AppColors.white),
                        ),
                      )
                    : const Icon(Icons.send, color: AppColors.white),
                onPressed: _sending ? null : _send,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
