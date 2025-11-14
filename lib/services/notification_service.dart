// lib/services/notification_service.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing user notification preferences (enable/disable)
/// This is separate from NotificationProvider which handles the notification list
class NotificationService with ChangeNotifier {
  bool _notificationsEnabled = true;
  bool _isInitialized = false;

  bool get notificationsEnabled => _notificationsEnabled;
  bool get isInitialized => _isInitialized;

  /// Initialize notification preferences from persistent storage
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Load the stored value, defaulting to true if not found
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
      _isInitialized = true;
      notifyListeners();
      debugPrint('✅ NotificationService initialized: enabled=$_notificationsEnabled');
    } catch (e) {
      debugPrint('❌ Error initializing NotificationService: $e');
      _isInitialized = true; // Mark as initialized even on error to prevent blocking
      notifyListeners();
    }
  }

  /// Toggle notification preference and persist to storage
  Future<void> toggleNotifications(bool value) async {
    try {
      _notificationsEnabled = value;
      
      // Persist to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notificationsEnabled', value);
      
      notifyListeners();
      debugPrint('✅ Notifications ${value ? 'enabled' : 'disabled'}');
    } catch (e) {
      debugPrint('❌ Error toggling notifications: $e');
      // Revert on error
      _notificationsEnabled = !value;
      notifyListeners();
      rethrow;
    }
  }
}