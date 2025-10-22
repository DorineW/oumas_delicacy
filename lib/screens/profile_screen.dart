//lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import '../constants/colors.dart';
import 'order_history_screen.dart';
import 'edit_profile_screen.dart';
import 'payment_methods_screen.dart';
import 'notifications_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Logout"),
          content: const Text("Are you sure you want to logout?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                // Implement logout logic here
                Navigator.of(context).pop();
              },
              child: const Text(
                "Logout",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {},
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text("Profile"),
          backgroundColor: AppColors.primary,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.white),
          titleTextStyle: const TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold),
          automaticallyImplyLeading: false,
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  children: [
                    SizedBox(height: isLandscape ? 20 : 30),
                    CircleAvatar(radius: isLandscape ? 40 : 50, backgroundImage: const AssetImage('assets/images/profile.jpg')),
                    SizedBox(height: isLandscape ? 12 : 16),
                    Text("Dorin N.", style: TextStyle(fontSize: isLandscape ? 20 : 22, fontWeight: FontWeight.bold)),
                    Text("dorin@example.com", style: TextStyle(fontSize: isLandscape ? 14 : 16, color: Colors.grey)),
                    SizedBox(height: isLandscape ? 20 : 30),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 100),
                      child: Column(
                        children: [
                          _ProfileOption(icon: Icons.edit, title: "Edit Profile", onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfileScreen())); }),
                          _ProfileOption(icon: Icons.history, title: "Order History", onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const OrderHistoryScreen())); }),
                          _ProfileOption(icon: Icons.payment, title: "Payment Methods", onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const PaymentMethodsScreen())); }),
                          _ProfileOption(icon: Icons.notifications, title: "Notifications", onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen())); }),
                          _ProfileOption(icon: Icons.logout, title: "Logout", isDestructive: true, onTap: () => _showLogoutDialog(context)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProfileOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isDestructive;
  final VoidCallback? onTap;

  const _ProfileOption({
    required this.icon,
    required this.title,
    this.isDestructive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : AppColors.primary),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          color: isDestructive ? Colors.red : AppColors.darkText,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}