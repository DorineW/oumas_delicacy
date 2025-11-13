import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  final SupabaseClient _client = Supabase.instance.client;

  SupabaseClient get client => _client;

  String? get userId => _client.auth.currentUser?.id;

  Future<String> getOrCreateCustomerRoom() async {
    final uid = userId;
    if (uid == null) throw Exception('No authenticated user');
    final existing = await _client
        .from('chat_rooms')
        .select('id')
        .eq('customer_id', uid)
        .limit(1)
        .maybeSingle();
    if (existing != null) return existing['id'] as String;
    final inserted = await _client.from('chat_rooms').insert({
      'customer_id': uid,
      // unread counts default null / 0 handled DB side
    }).select('id').single();
    return inserted['id'] as String;
  }

  Stream<List<Map<String, dynamic>>> streamAdminRooms() {
    return _client
        .from('chat_rooms')
        .stream(primaryKey: ['id'])
        .order('last_message_at', ascending: false)
        .map((rows) => rows);
  }

  Stream<Map<String, dynamic>?> streamSingleRoom(String roomId) {
    return _client
        .from('chat_rooms')
        .stream(primaryKey: ['id'])
        .eq('id', roomId)
        .map((rows) => rows.isNotEmpty ? rows.first : null);
  }

  Stream<List<Map<String, dynamic>>> streamCustomerRoom(String roomId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at')
        .map((rows) => rows);
  }

  Future<void> sendMessage({required String roomId, required String content}) async {
    final uid = userId;
    if (uid == null) throw Exception('Not authenticated');
    await _client.from('messages').insert({
      'room_id': roomId,
      'sender_id': uid,
      'content': content,
    });
  }

  Future<void> markRoomRead(String roomId) async {
    await _client.rpc('mark_room_read', params: {'p_room_id': roomId});
  }
}
