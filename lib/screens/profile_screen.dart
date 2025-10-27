//lib/screens/profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/colors.dart';
import '../utils/responsive_helper.dart'; // ADDED
import 'order_history_screen.dart';
import 'edit_profile_screen.dart';
import 'payment_methods_screen.dart';
import 'notifications_screen.dart';
import '../providers/notification_provider.dart';
import '../services/auth_service.dart'; // ADDED

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = 'Dorin N.';
  String _userEmail = 'dorin@example.com';
  File? _profileImage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ADDED: Load saved profile data
  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final auth = Provider.of<AuthService>(context, listen: false);
    
    setState(() {
      // Load from auth service first, fallback to prefs
      _userName = auth.currentUser?.name ?? prefs.getString('name') ?? 'Guest';
      _userEmail = auth.currentUser?.email ?? prefs.getString('email') ?? 'guest@example.com';
      
      final profilePath = prefs.getString('profileImagePath');
      if (profilePath != null && profilePath.isNotEmpty) {
        final f = File(profilePath);
        if (f.existsSync()) {
          _profileImage = f;
        } else {
          _profileImage = null; // UPDATED: Clear invalid image path
        }
      } else {
        _profileImage = null; // UPDATED: No profile image for new users
      }
    });
    
    debugPrint('📱 Profile loaded: $_userName ($_userEmail)');
  }

  // ADDED: Refresh profile when returning from edit screen
  Future<void> _navigateToEditProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
    );
    // Reload profile after returning
    _loadProfile();
    
    // ADDED: Reload auth service with updated profile
    final auth = Provider.of<AuthService>(context, listen: false);
    await auth.loadUserProfile();
  }

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
    final isLandscape = ResponsiveHelper.isLandscape(context);
    final auth = Provider.of<AuthService>(context, listen: false); // ADDED
    final userId = auth.currentUser?.id ?? 'guest'; // ADDED
    
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
                    // UPDATED: Show saved profile image or default placeholder
                    CircleAvatar(
                      radius: isLandscape ? 40 : 50,
                      backgroundColor: AppColors.primary.withOpacity(0.1), // ADDED: Background color
                      backgroundImage: _profileImage != null
                          ? FileImage(_profileImage!) as ImageProvider
                          : null, // UPDATED: Remove default asset image
                      child: _profileImage == null
                          ? Icon(
                              Icons.person,
                              size: isLandscape ? 40 : 50,
                              color: AppColors.primary,
                            )
                          : null, // UPDATED: Show icon for new users
                    ),
                    SizedBox(height: isLandscape ? 12 : 16),
                    // UPDATED: Show saved name
                    Text(
                      _userName,
                      style: TextStyle(
                        fontSize: isLandscape ? 20 : 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // UPDATED: Show saved email
                    Text(
                      _userEmail,
                      style: TextStyle(
                        fontSize: isLandscape ? 14 : 16,
                        color: Colors.grey,
                      ),
                    ),
                    SizedBox(height: isLandscape ? 20 : 30),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 100),
                      child: Column(
                        children: [
                          // UPDATED: Use new navigation method
                          _ProfileOption(
                            icon: Icons.edit,
                            title: "Edit Profile",
                            onTap: _navigateToEditProfile,
                          ),
                          _ProfileOption(
                            icon: Icons.history,
                            title: "Order History",
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const OrderHistoryScreen()),
                              );
                            },
                          ),
                          _ProfileOption(
                            icon: Icons.payment,
                            title: "Payment Methods",
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const PaymentMethodsScreen()),
                              );
                            },
                          ),
                          // UPDATED: Notifications with badge
                          Consumer<NotificationProvider>(
                            builder: (context, notifProvider, child) {
                              final unreadCount = notifProvider.unreadCountForUser(userId);
                              
                              return _ProfileOption(
                                icon: Icons.notifications,
                                title: "Notifications",
                                trailing: unreadCount > 0
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          unreadCount > 99 ? '99+' : '$unreadCount',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    : null,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                                  );
                                },
                              );
                            },
                          ),
                          _ProfileOption(
                            icon: Icons.logout,
                            title: "Logout",
                            isDestructive: true,
                            onTap: () => _showLogoutDialog(context),
                          ),
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
    ); // FIXED: Added missing closing parenthesis
  }
}

class _ProfileOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isDestructive;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _ProfileOption({
    required this.icon,
    required this.title,
    this.isDestructive = false,
    this.onTap,
    this.trailing,
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
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}