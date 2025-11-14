import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';

class NotificationProvider extends ChangeNotifier {
  final List<AppNotification> _notifications = [];
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _error;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  List<AppNotification> notificationsForUser(String userId) {
    return _notifications.where((n) => n.userId == userId).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  
  int unreadCountForUser(String userId) {
    return _notifications.where((n) => n.userId == userId && !n.isRead).length;
  }

  /// Initialize by loading notifications from database for a specific user
  Future<void> loadNotificationsForUser(String userId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('📥 Loading notifications for user: $userId');

      // Load recent notifications (last 30 days) with timeout
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_auth_id', userId)
          .gte('created_at', thirtyDaysAgo.toIso8601String())
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 10));

      _notifications.clear();
      
      for (final row in response) {
        try {
          _notifications.add(AppNotification.fromJson(row));
        } catch (e) {
          debugPrint('⚠️ Error parsing notification: $e');
        }
      }

      debugPrint('✅ Loaded ${_notifications.length} notifications');
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      debugPrint('❌ Error loading notifications: $e');
      notifyListeners();
    }
  }

  /// Add a new notification to database and local list
  Future<void> addNotification(AppNotification notification) async {
    try {
      debugPrint('📤 Adding notification to database: ${notification.title}');

      // Insert into database
      await _supabase.from('notifications').insert(notification.toJson());

      // Add to local list
      _notifications.add(notification);
      notifyListeners();

      debugPrint('✅ Notification added: ${notification.title} for user ${notification.userId}');
    } catch (e) {
      debugPrint('❌ Error adding notification: $e');
      rethrow;
    }
  }

  /// Mark a single notification as read (update database and local list)
  Future<void> markAsRead(String notificationId) async {
    try {
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index == -1) return;

      // Update database
      await _supabase
          .from('notifications')
          .update({
            'seen': true,
          })
          .eq('id', notificationId);

      // Update local list
      _notifications[index] = _notifications[index].copyWith(
        isRead: true,
      );
      
      notifyListeners();
      debugPrint('✅ Notification marked as read: $notificationId');
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
      rethrow;
    }
  }

  /// Mark all notifications as read for a user (update database and local list)
  Future<void> markAllAsReadForUser(String userId) async {
    try {
      // Update database
      await _supabase
          .from('notifications')
          .update({
            'seen': true,
          })
          .eq('user_auth_id', userId)
          .eq('seen', false);

      // Update local list
      bool changed = false;
      for (int i = 0; i < _notifications.length; i++) {
        if (_notifications[i].userId == userId && !_notifications[i].isRead) {
          _notifications[i] = _notifications[i].copyWith(
            isRead: true,
          );
          changed = true;
        }
      }
      
      if (changed) {
        notifyListeners();
        debugPrint('✅ All notifications marked as read for user: $userId');
      }
    } catch (e) {
      debugPrint('❌ Error marking all notifications as read: $e');
      rethrow;
    }
  }

  /// Clear notifications for a user from local list (database remains intact)
  void clearNotificationsForUser(String userId) {
    _notifications.removeWhere((n) => n.userId == userId);
    notifyListeners();
  }

  /// Generate a unique notification ID using UUID
  String generateNotificationId() {
    // Generate a timestamp-based unique ID
    // Note: In production, the database should use gen_random_uuid()
    // or you can use the uuid package: uuid.v4()
    return 'notif_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }
}
