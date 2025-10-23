import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';

class NotificationProvider extends ChangeNotifier {
  final List<AppNotification> _notifications = [];

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  
  List<AppNotification> notificationsForUser(String userId) {
    return _notifications.where((n) => n.userId == userId).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  
  int unreadCountForUser(String userId) {
    return _notifications.where((n) => n.userId == userId && !n.isRead).length;
  }

  void addNotification(AppNotification notification) {
    _notifications.add(notification);
    notifyListeners();
    debugPrint('✅ Notification added: ${notification.title} for user ${notification.userId}');
  }

  void markAsRead(String notificationId) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      notifyListeners();
    }
  }

  void markAllAsReadForUser(String userId) {
    bool changed = false;
    for (int i = 0; i < _notifications.length; i++) {
      if (_notifications[i].userId == userId && !_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void clearNotificationsForUser(String userId) {
    _notifications.removeWhere((n) => n.userId == userId);
    notifyListeners();
  }

  String generateNotificationId() {
    return 'NOTIF-${DateTime.now().millisecondsSinceEpoch}';
  }
}
