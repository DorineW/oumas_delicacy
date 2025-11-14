//lib/models/notification_model.dart
//the notification model representing app notifications
class AppNotification {
  final String id;
  final String userId; // Maps to user_auth_id in database
  final String title; // Extracted from payload
  final String message; // Extracted from payload
  final String type; // Direct text field: 'order_update', 'promotion', 'delivery', 'system'
  final DateTime timestamp;
  final bool isRead; // Maps to 'seen' in database
  final Map<String, dynamic>? payload; // JSONB data (order_id, etc.)

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.payload,
  });

  // Factory constructor to create from database row
  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final payloadData = json['payload'] as Map<String, dynamic>? ?? {};
    
    return AppNotification(
      id: json['id'] as String,
      userId: json['user_auth_id'] as String,
      title: payloadData['title'] as String? ?? 'Notification',
      message: payloadData['message'] as String? ?? '',
      type: json['type'] as String? ?? 'system',
      timestamp: DateTime.parse(json['created_at'] as String),
      isRead: json['seen'] as bool? ?? false,
      payload: payloadData,
    );
  }

  // Convert to JSON for database insertion
  Map<String, dynamic> toJson() {
    return {
      'user_auth_id': userId,
      'type': type,
      'payload': {
        'title': title,
        'message': message,
        ...?payload,
      },
      'seen': isRead,
      'created_at': timestamp.toIso8601String(),
    };
  }

  AppNotification copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    String? type,
    DateTime? timestamp,
    bool? isRead,
    Map<String, dynamic>? payload,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      payload: payload ?? this.payload,
    );
  }
  
  // Helper to get order_id from payload
  String? get orderId => payload?['order_id'] as String?;
}
