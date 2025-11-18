// lib/screens/admin/admin_chat_list_screen.dart
import 'dart:async';
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
  final _refreshController = StreamController<void>.broadcast();
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    _roomsStream = ChatService.instance.streamAdminRooms();
  }

  @override
  void dispose() {
    _refreshController.close();
    super.dispose();
  }

  void _forceRefresh() {
    if (mounted) {
      setState(() {
        _refreshKey++;
      });
    }
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

              // Total unread messages across all rooms for admin
              final totalUnread = unreadRooms.fold<int>(
                0,
                (sum, r) => sum + ((r['unread_admin'] as num?)?.toInt() ?? 0),
              );

              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chat_bubble),
                    tooltip: 'Mark all as read',
                    onPressed: () async {
                      for (final r in unreadRooms) {
                        final id = r['id'];
                        if (id is String) {
                          try {
                            await ChatService.instance.markRoomRead(id);
                          } catch (_) {}
                        }
                      }
                    },
                  ),
                  Positioned(
                    right: 8,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Center(
                        child: Text(
                          totalUnread > 99 ? '99+' : totalUnread.toString(),
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        key: ValueKey(_refreshKey),
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
                final roomId = chat['id'] as String?;
                if (roomId == null) return const SizedBox.shrink(); // Skip invalid rooms
                
                final unreadAdmin = (chat['unread_admin'] as num?)?.toInt() ?? 0;
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
                    if (!mounted) return;
                    
                    // Navigate to chat
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CustomerChatScreen(chatId: roomId),
                      ),
                    );
                    
                    // After returning, mark as read and force refresh
                    if (!mounted) return;
                    try {
                      await ChatService.instance.markRoomRead(roomId);
                      // Small delay to let database update propagate
                      await Future.delayed(const Duration(milliseconds: 300));
                      _forceRefresh();
                    } catch (_) {}
                  },
                );
              }),
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
    
    // Convert UTC to Kenyan local time (EAT, UTC+3)
    final kenyanTime = time.toUtc().add(const Duration(hours: 3));
    final now = DateTime.now().toUtc().add(const Duration(hours: 3));
    final diff = now.difference(kenyanTime);
    
    // Show actual time for messages less than 5 minutes old (instead of 'now')
    if (diff.inMinutes < 5) {
      final hour12 = kenyanTime.hour == 0 ? 12 : (kenyanTime.hour > 12 ? kenyanTime.hour - 12 : kenyanTime.hour);
      final amPm = kenyanTime.hour >= 12 ? 'PM' : 'AM';
      return '$hour12:${kenyanTime.minute.toString().padLeft(2, '0')} $amPm';
    }
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${kenyanTime.day}/${kenyanTime.month}';
  }
}
