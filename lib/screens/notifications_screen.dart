import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import '../constants/colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _orderUpdates = true;
  bool _promotions = false;
  bool _priceDrops = true;
  bool _newArrivals = true;
  bool _specialOffers = false;
  bool _appUpdates = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Notifications"),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Notification Settings",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Customize how you receive notifications",
                style: TextStyle(
                  color: AppColors.lightGray,
                ),
              ),
              const SizedBox(height: 24),
              Card(
                color: AppColors.cardBackground,
                child: Column(
                  children: [
                    SwitchListTile(
                      value: _orderUpdates,
                      title: const Text(
                        'Order Updates',
                        style: TextStyle(color: AppColors.darkText),
                      ),
                      subtitle: const Text(
                        'Get notified about your order status',
                        style: TextStyle(color: AppColors.darkText),
                      ),
                      activeTrackColor: AppColors.primary.withOpacity(0.5),
                      activeThumbColor: AppColors.primary,
                      onChanged: (value) {
                        setState(() {
                          _orderUpdates = value;
                        });
                      },
                    ),
                    const Divider(height: 1, color: AppColors.lightGray),
                    SwitchListTile(
                      value: _promotions,
                      title: const Text(
                        'Promotions & Discounts',
                        style: TextStyle(color: AppColors.darkText),
                      ),
                      subtitle: const Text(
                        'Receive special offers and promotions',
                        style: TextStyle(color: AppColors.darkText),
                      ),
                      activeTrackColor: AppColors.primary.withOpacity(0.5),
                      activeThumbColor: AppColors.primary,
                      onChanged: (value) {
                        setState(() {
                          _promotions = value;
                        });
                      },
                    ),
                    const Divider(height: 1, color: AppColors.lightGray),
                    SwitchListTile(
                      value: _priceDrops,
                      title: const Text(
                        'Price Drops',
                        style: TextStyle(color: AppColors.darkText),
                      ),
                      subtitle: const Text(
                        'Get notified when items you like go on sale',
                        style: TextStyle(color: AppColors.darkText),
                      ),
                      activeTrackColor: AppColors.primary.withOpacity(0.5),
                      activeThumbColor: AppColors.primary,
                      onChanged: (value) {
                        setState(() {
                          _priceDrops = value;
                        });
                      },
                    ),
                    const Divider(height: 1, color: AppColors.lightGray),
                    SwitchListTile(
                      value: _newArrivals,
                      title: const Text(
                        'New Arrivals',
                        style: TextStyle(color: AppColors.darkText),
                      ),
                      subtitle: const Text(
                        'Be the first to know about new menu items',
                        style: TextStyle(color: AppColors.darkText),
                      ),
                      // ignore: deprecated_member_use
                      activeTrackColor: AppColors.primary.withOpacity(0.5),
                      activeThumbColor: AppColors.primary,
                      onChanged: (value) {
                        setState(() {
                          _newArrivals = value;
                        });
                      },
                    ),
                    const Divider(height: 1, color: AppColors.lightGray),
                    SwitchListTile(
                      value: _specialOffers,
                      title: const Text(
                        'Special Offers',
                        style: TextStyle(color: AppColors.darkText),
                      ),
                      subtitle: const Text(
                        'Exclusive offers for loyal customers',
                        style: TextStyle(color: AppColors.darkText),
                      ),
                      // ignore: deprecated_member_use
                      activeTrackColor: AppColors.primary.withOpacity(0.5),
                      activeThumbColor: AppColors.primary,
                      onChanged: (value) {
                        setState(() {
                          _specialOffers = value;
                        });
                      },
                    ),
                    const Divider(height: 1, color: AppColors.lightGray),
                    SwitchListTile(
                      value: _appUpdates,
                      title: const Text(
                        'App Updates',
                        style: TextStyle(color: AppColors.darkText),
                      ),
                      subtitle: const Text(
                        'Important updates about the app',
                        style: TextStyle(color: AppColors.darkText),
                      ),
                      // ignore: deprecated_member_use
                      activeTrackColor: AppColors.primary.withOpacity(0.5),
                      activeThumbColor: AppColors.primary,
                      onChanged: (value) {
                        setState(() {
                          _appUpdates = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // Save notification preferences
                  _saveNotificationSettings();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Notification settings saved"),
                      backgroundColor: AppColors.success,
                    ),
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Save Settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveNotificationSettings() {
    // Use debugPrint instead of print for production code
    if (kDebugMode) {
      debugPrint("""
    Notification Settings Saved:
    Order Updates: $_orderUpdates
    Promotions: $_promotions
    Price Drops: $_priceDrops
    New Arrivals: $_newArrivals
    Special Offers: $_specialOffers
    App Updates: $_appUpdates
    """);
    }
    
    // Here you would typically save the notification preferences to your backend
    // For example:
    // await saveToDatabase({
    //   'orderUpdates': _orderUpdates,
    //   'promotions': _promotions,
    //   // ... etc
    // });
  }
}