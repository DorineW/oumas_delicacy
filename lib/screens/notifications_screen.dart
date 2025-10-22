import 'package:flutter/material.dart';
import '../constants/colors.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Notifications'),
          backgroundColor: AppColors.primary,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.white),
          titleTextStyle: const TextStyle(
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Mark all as read
              },
              child: const Text(
                'Mark all read',
                style: TextStyle(color: AppColors.white),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _NotificationCard(
              icon: Icons.check_circle,
              iconColor: AppColors.success,
              title: 'Order Delivered',
              message: 'Your order #1234 has been delivered successfully',
              time: '2 hours ago',
              isRead: false,
            ),
            const SizedBox(height: 12),
            _NotificationCard(
              icon: Icons.local_shipping,
              iconColor: Colors.blue,
              title: 'Order Shipped',
              message: 'Your order #1233 is on the way',
              time: '5 hours ago',
              isRead: false,
            ),
            const SizedBox(height: 12),
            _NotificationCard(
              icon: Icons.confirmation_number,
              iconColor: Colors.orange,
              title: 'Order Confirmed',
              message: 'Your order #1232 has been confirmed',
              time: 'Yesterday',
              isRead: true,
            ),
            const SizedBox(height: 12),
            _NotificationCard(
              icon: Icons.local_offer,
              iconColor: Colors.purple,
              title: 'Special Offer',
              message: 'Get 20% off on your next order!',
              time: '2 days ago',
              isRead: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String time;
  final bool isRead;

  const _NotificationCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.time,
    required this.isRead,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isRead ? AppColors.white : AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: isRead ? null : Border.all(color: AppColors.primary.withOpacity(0.2)),
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
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkText,
                        ),
                      ),
                    ),
                    if (!isRead)
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
                  message,
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
    );
  }
}