//lib/screens/profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/colors.dart';
import '../utils/responsive_helper.dart';
import 'edit_profile_screen.dart';
import 'payment_methods_screen.dart';
import 'notifications_screen.dart';
import '../providers/notification_provider.dart';
import '../providers/favorites_provider.dart'; // ADDED
import '../providers/cart_provider.dart'; // ADDED
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../screens/customer_chat_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = 'Guest User';
  String _userEmail = 'guest@example.com';
  File? _profileImage;
  String? _chatRoomId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadProfile();
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

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final auth = Provider.of<AuthService>(context, listen: false);
    
    if (mounted) {
      setState(() {
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

  Future<void> _navigateToEditProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
    );
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
              onPressed: () async {
                Navigator.of(context).pop();
                
                // Clear all provider data before logout
                final favoritesProvider = Provider.of<FavoritesProvider>(context, listen: false);
                final cartProvider = Provider.of<CartProvider>(context, listen: false);
                
                favoritesProvider.clearFavorites();
                cartProvider.clearCart();
                
                // Logout from auth service
                await Provider.of<AuthService>(context, listen: false).logout();
                
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
                      _userName,
                      style: TextStyle(
                        fontSize: isLandscape ? 20 : 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // User email
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
                          // Support Chat option with unread badge
                          _ProfileOption(
                            icon: Icons.chat_bubble_outline,
                            title: "Support Chat",
                            trailing: _chatRoomId == null
                                ? const Icon(Icons.arrow_forward_ios, size: 16)
                                : StreamBuilder<Map<String, dynamic>?>(
                                    stream: ChatService.instance.streamSingleRoom(_chatRoomId!),
                                    builder: (context, snapshot) {
                                      final unread = (snapshot.data?['unread_customer'] ?? 0) as int;
                                      return Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (unread > 0)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.red,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                unread > 99 ? '99+' : '$unread',
                                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.arrow_forward_ios, size: 16),
                                        ],
                                      );
                                    },
                                  ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => _chatRoomId == null
                                      ? const CustomerChatScreen()
                                      : CustomerChatScreen(chatId: _chatRoomId),
                                ),
                              );
                            },
                          ),
                          _ProfileOption(
                            icon: Icons.edit,
                            title: "Edit Profile",
                            onTap: _navigateToEditProfile,
                          ),
                          _ProfileOption(
                            icon: Icons.receipt_long,
                            title: "Order History",
                            onTap: () {
                              Navigator.pushNamed(context, '/order-history');
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