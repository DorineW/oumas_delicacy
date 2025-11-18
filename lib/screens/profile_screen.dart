//lib/screens/profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'; // ADDED for navigation handling
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/colors.dart';
import '../utils/responsive_helper.dart';
import 'edit_profile_screen.dart';
import 'notifications_screen.dart';
import '../providers/notification_provider.dart';
import '../providers/favorites_provider.dart'; // ADDED
import '../providers/cart_provider.dart'; // ADDED
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../screens/customer_chat_screen.dart';
import '../screens/customer_address_management_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  File? _profileImage;
  String? _chatRoomId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadImagePath(); // CLEANUP: Only load local file path
        _initChatRoom();
      }
    });
  }

  Future<void> _initChatRoom() async {
    try {
      final id = await ChatService.instance.getOrCreateCustomerRoom();
      if (mounted) {
        setState(() => _chatRoomId = id);
      }
    } catch (_) {
      // ignore badge errors for now
    }
  }

  // CLEANUP: Simplified to only load the profile image path
  Future<void> _loadImagePath() async {
    final prefs = await SharedPreferences.getInstance();
    
    final profilePath = prefs.getString('profileImagePath');
    File? loadedImage;

    if (profilePath != null && profilePath.isNotEmpty) {
      final f = File(profilePath);
      if (f.existsSync()) {
        loadedImage = f;
      }
    }

    if (mounted) {
      setState(() {
        _profileImage = loadedImage;
      });
      debugPrint('📱 Profile image path loaded.');
    }
  }

  Future<void> _navigateToEditProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
    );
    // After returning from EditProfileScreen, force a reload of the image path.
    await _loadImagePath();
    // Since name/email are watched via Provider in build(), no manual update needed here.
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Logout"),
          content: const Text("Are you sure you want to logout? This will clear your local cart and favorites."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                
                // Clear all provider data before logout
                final favoritesProvider = context.read<FavoritesProvider>();
                final cartProvider = context.read<CartProvider>();
                
                favoritesProvider.clearFavorites();
                cartProvider.clearCart();
                
                // Logout from auth service
                await context.read<AuthService>().logout();
                
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                }
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
    final auth = context.watch<AuthService>(); // FIXED: Use context.watch to react to auth changes
    
    // FIXED: Use direct values from the watched provider
    final userName = auth.currentUser?.name ?? 'Guest User';
    final userEmail = auth.currentUser?.email ?? 'guest@example.com';
    final userId = auth.currentUser?.id ?? 'guest';

    // This ensures that if auth.currentUser is null, we redirect to login
    if (auth.currentUser == null) {
      // Delay navigation back to login if user is logged out while on this screen
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          debugPrint('🔴 User signed out, redirecting to login.');
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        }
      });
    }
    
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
                    // Profile picture
                    CircleAvatar(
                      radius: isLandscape ? 40 : 50,
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      backgroundImage: _profileImage != null
                          ? FileImage(_profileImage!) as ImageProvider
                          : null,
                      child: _profileImage == null
                          ? Icon(
                              Icons.person,
                              size: isLandscape ? 40 : 50,
                              color: AppColors.primary,
                            )
                          : null,
                    ),
                    SizedBox(height: isLandscape ? 12 : 16),
                    // User name
                    Text(
                      userName, // FIXED: Use local variable from provider
                      style: TextStyle(
                        fontSize: isLandscape ? 20 : 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // User email
                    Text(
                      userEmail, // FIXED: Use local variable from provider
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
                          // Edit Profile
                          _ProfileOption(
                            icon: Icons.edit,
                            title: "Edit Profile",
                            onTap: _navigateToEditProfile,
                          ),
                          // Order History
                          _ProfileOption(
                            icon: Icons.receipt_long,
                            title: "Order History",
                            onTap: () {
                              Navigator.pushNamed(context, '/order-history');
                            },
                          ),
                          // My Addresses
                          _ProfileOption(
                            icon: Icons.location_on,
                            title: "My Addresses",
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const CustomerAddressManagementScreen(),
                                ),
                              );
                            },
                          ),
                          // Notifications
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
                          // IMPROVED: Help & Support option with better styling
                          _ProfileOption(
                            icon: Icons.help_outline,
                            title: "Help & Support",
                            trailing: _chatRoomId == null
                                ? null
                                : StreamBuilder<Map<String, dynamic>?>(
                                    stream: ChatService.instance.streamSingleRoom(_chatRoomId!),
                                    builder: (context, snapshot) {
                                      final unread = (snapshot.data?['unread_customer'] ?? 0) as int;
                                      if (unread > 0) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            unread > 99 ? '99+' : '$unread',
                                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CustomerChatScreen(chatId: _chatRoomId),
                                ),
                              );
                            },
                          ),
                          // Logout
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Icon(icon, color: isDestructive ? Colors.red : AppColors.primary),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          color: isDestructive ? Colors.red : AppColors.darkText,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null) trailing!,
          if (trailing != null) const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        ],
      ),
      onTap: onTap,
    );
  }
}