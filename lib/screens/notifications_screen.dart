import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../providers/notification_provider.dart';
import '../services/auth_service.dart'; // FIXED: Changed from providers to services
import '../models/notification_model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _hasLoadedOnce = false;

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'order_update':
        return Icons.receipt_long;
      case 'delivery':
        return Icons.local_shipping;
      case 'promotion':
        return Icons.local_offer;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'order_update':
        return AppColors.primary;
      case 'delivery':
        return Colors.blue;
      case 'promotion':
        return Colors.purple;
      default:
        return AppColors.darkText;
    }
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';

    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final userId = auth.currentUser?.id ?? 'guest';

    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        // Load notifications only once when first entering the screen
        if (!_hasLoadedOnce && !provider.isLoading) {
          _hasLoadedOnce = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            provider.loadNotificationsForUser(userId);
          });
        }

        final notifications = provider.notificationsForUser(userId);
        final unreadCount = provider.unreadCountForUser(userId);

        return PopScope(
          canPop: true,
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: const Text('Notifications'),
              backgroundColor: AppColors.primary,
              elevation: 0,
              automaticallyImplyLeading: true,
              titleTextStyle: const TextStyle(
                color: AppColors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              iconTheme: const IconThemeData(color: AppColors.white),
              actions: [
                if (unreadCount > 0)
                  TextButton(
                    onPressed: () => provider.markAllAsReadForUser(userId),
                    child: const Text(
                      'Mark all read',
                      style: TextStyle(color: AppColors.white),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: () => provider.loadNotificationsForUser(userId),
                ),
              ],
            ),
            body: provider.isLoading && notifications.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppColors.primary),
                        SizedBox(height: 16),
                        Text('Loading notifications...'),
                      ],
                    ),
                  )
                : provider.error != null && notifications.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 80,
                                color: AppColors.darkText.withOpacity(0.3),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Failed to Load Notifications',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.darkText,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                provider.error ?? 'Unknown error',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.darkText.withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () => provider.loadNotificationsForUser(userId),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : notifications.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.notifications_off,
                                  size: 80,
                                  color: AppColors.darkText.withOpacity(0.3),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No Notifications',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.darkText.withOpacity(0.5),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'You\'ll receive notifications about your orders here',
                                  style: TextStyle(
                                    color: AppColors.darkText.withOpacity(0.4),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: notifications.length,
                            itemBuilder: (context, index) {
                              final notification = notifications[index];
                              return _NotificationCard(
                                notification: notification,
                                icon: _getNotificationIcon(notification.type),
                                iconColor: _getNotificationColor(notification.type),
                                time: _formatTime(notification.timestamp),
                                onTap: () {
                                  if (!notification.isRead) {
                                    provider.markAsRead(notification.id);
                                  }
                                },
                              );
                            },
                          ),
          ),
        );
      },
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final IconData icon;
  final Color iconColor;
  final String time;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.icon,
    required this.iconColor,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notification.isRead ? AppColors.white : AppColors.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: notification.isRead ? null : Border.all(color: AppColors.primary.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkText,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification.message,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.darkText.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.darkText.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}