import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../customer_chat_screen.dart';
import '../../services/chat_service.dart';

class AdminChatListScreen extends StatefulWidget {
  const AdminChatListScreen({super.key});

  @override
  State<AdminChatListScreen> createState() => _AdminChatListScreenState();
}

class _AdminChatListScreenState extends State<AdminChatListScreen> {
  late final Stream<List<Map<String, dynamic>>> _roomsStream;

  @override
  void initState() {
    super.initState();
    _roomsStream = ChatService.instance.streamAdminRooms();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Chats (Admin)'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        actions: [
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _roomsStream,
            builder: (context, snapshot) {
              final rooms = snapshot.data ?? const [];
              final unreadRooms = rooms.where((r) => (r['unread_admin'] ?? 0) > 0).toList();
              if (unreadRooms.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.mark_email_read),
                tooltip: 'Mark all as read',
                onPressed: () async {
                  for (final r in unreadRooms) {
                    final id = r['id'];
                    if (id is String) {
                      try { await ChatService.instance.markRoomRead(id); } catch (_) {}
                    }
                  }
                },
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _roomsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final rooms = snapshot.data ?? const [];
          if (rooms.isEmpty) {
            return const Center(
              child: Text('No chats yet'),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(8.0),
            children: [
              _buildSectionHeader('Active Chats'),
              ...rooms.map((chat) {
                final roomId = chat['id'] as String;
                final unreadAdmin = (chat['unread_admin'] ?? 0) as int;
                final lastMessageAtStr = chat['last_message_at'] as String?;
                final lastMessageContent = (chat['last_message_content'] ?? '') as String;
                  final customerName = (chat['customer_name'] as String?) ?? 'Customer';
                final lastTime = lastMessageAtStr == null
                    ? ''
                    : _relativeTime(DateTime.tryParse(lastMessageAtStr));
                final preview = lastMessageContent.isEmpty ? 'Open chat' : lastMessageContent;
                return _buildChatListTile(
                  title: customerName,
                  subtitle: preview,
                  unreadCount: unreadAdmin,
                  lastTime: lastTime,
                  onTap: () async {
                    try { await ChatService.instance.markRoomRead(roomId); } catch (_) {}
                    if (!mounted) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CustomerChatScreen(chatId: roomId),
                      ),
                    );
                  },
                );
              }).toList(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 12.0, left: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildChatListTile({
    required String title,
    required String subtitle,
    required int unreadCount,
    required String lastTime,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: const Icon(Icons.person, color: AppColors.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.grey),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              lastTime,
              style: TextStyle(
                fontSize: 12,
                color: unreadCount > 0 ? AppColors.primary : Colors.grey,
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                child: Center(
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  String _relativeTime(DateTime? time) {
    if (time == null) return '';
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}
