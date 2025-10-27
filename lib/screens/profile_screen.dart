//lib/screens/profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/colors.dart';
import '../utils/responsive_helper.dart';
import 'order_history_screen.dart';
import 'edit_profile_screen.dart';
import 'payment_methods_screen.dart';
import 'notifications_screen.dart';
import '../providers/notification_provider.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = 'Guest User';
  String _userEmail = 'guest@example.com';
  File? _profileImage;

  @override
  void initState() {
    super.initState();
    // ADDED: Load profile data when screen is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadProfile();
      }
    });
  }

  // UPDATED: Load saved profile data from SharedPreferences and AuthService
  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final auth = Provider.of<AuthService>(context, listen: false);
    
    if (mounted) {
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
            _profileImage = null;
          }
        } else {
          _profileImage = null;
        }
      });
      
      debugPrint('📱 Profile loaded: $_userName ($_userEmail)');
    }
  }

  // UPDATED: Refresh profile when returning from edit screen
  Future<void> _navigateToEditProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
    );
    // Reload profile after returning
    await _loadProfile();
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
                Navigator.of(context).pop();
                // Perform logout
                Provider.of<AuthService>(context, listen: false).logout();
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
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
    final auth = context.watch<AuthService>();
    final userId = auth.currentUser?.id ?? 'guest';
    
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {},
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text("Profile"),
          backgroundColor: AppColors.primary,
          elevation: 4,
          iconTheme: const IconThemeData(color: AppColors.white),
          titleTextStyle: const TextStyle(
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, isLandscape ? 20 : 30, 16, 100),
                    child: Column(
                      children: [
                        // Profile Header with gradient background
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.primary,
                                AppColors.primary.withOpacity(0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: isLandscape ? 80 : 100,
                                    height: isLandscape ? 80 : 100,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.white.withOpacity(0.3),
                                          Colors.white.withOpacity(0.1),
                                        ],
                                      ),
                                    ),
                                  ),
                                  CircleAvatar(
                                    radius: isLandscape ? 35 : 45,
                                    backgroundColor: Colors.white,
                                    child: CircleAvatar(
                                      radius: isLandscape ? 32 : 42,
                                      backgroundColor: AppColors.primary.withOpacity(0.1),
                                      backgroundImage: _profileImage != null
                                          ? FileImage(_profileImage!) as ImageProvider
                                          : null,
                                      child: _profileImage == null
                                          ? Icon(
                                              Icons.person,
                                              size: isLandscape ? 35 : 45,
                                              color: AppColors.primary,
                                            )
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _userName,
                                style: TextStyle(
                                  fontSize: isLandscape ? 20 : 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _userEmail,
                                style: TextStyle(
                                  fontSize: isLandscape ? 13 : 14,
                                  color: AppColors.white.withOpacity(0.9),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  auth.currentUser?.role.toUpperCase() ?? 'GUEST',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: isLandscape ? 20 : 30),

                        // Profile Options
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
                ),
              );
            },
          ),
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