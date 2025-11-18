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

  /// Stream all chat rooms for admin view with customer names
  /// 
  /// NOTE: Improved implementation with caching to reduce N+1 queries.
  /// For production: Consider creating a Supabase database view:
  /// CREATE VIEW chat_rooms_with_names AS
  ///   SELECT cr.*, u.name as customer_name, u.email as customer_email
  ///   FROM chat_rooms cr
  ///   LEFT JOIN users u ON cr.customer_id = u.auth_id;
  Stream<List<Map<String, dynamic>>> streamAdminRooms() {
    final Map<String, String> _customerNameCache = {};
    
    return _client
        .from('chat_rooms')
        .stream(primaryKey: ['id'])
        .order('last_message_at', ascending: false)
        .asyncMap((rows) async {
          // Fetch customer names for each room with caching
          final enriched = <Map<String, dynamic>>[];
          
          // Batch fetch all unique customer IDs not in cache
          final uncachedIds = rows
              .map((row) => row['customer_id'] as String?)
              .where((id) => id != null && !_customerNameCache.containsKey(id))
              .toSet();
          
          if (uncachedIds.isNotEmpty) {
            try {
              final users = await _client
                  .from('users')
                  .select('auth_id, name, email')
                  .inFilter('auth_id', uncachedIds.toList());
              
              for (final user in users) {
                final authId = user['auth_id'] as String?;
                if (authId != null) {
                  String? userName = (user['name'] as String?)?.trim();
                  if (userName == null || userName.isEmpty) {
                    userName = user['email'] as String?;
                  }
                  _customerNameCache[authId] = userName ?? 'Customer';
                }
              }
            } catch (_) {
              // If batch fetch fails, continue with cache
            }
          }
          
          // Enrich rows with cached names
          for (final row in rows) {
            final customerId = row['customer_id'] as String?;
            final customerName = customerId != null 
                ? (_customerNameCache[customerId] ?? 'Customer')
                : 'Customer';
            enriched.add({...row, 'customer_name': customerName});
          }
          
          return enriched;
        });
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
