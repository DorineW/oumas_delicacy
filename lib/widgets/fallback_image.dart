// lib/screens/admin/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import '../../constants/colors.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  final List<String> _pages = [
    "Orders",
    "Menu",
    "Users",
    "Reports",
  ];

  Widget _fallbackImage({
    required double size,
  }) {
    return Image.asset(
      "assets/images/app_icon.jpg",
      height: size,
      width: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          "assets/images/default.jpg",
          height: size,
          width: size,
          fit: BoxFit.cover,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_pages[_selectedIndex]),
        backgroundColor: AppColors.primary,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: _fallbackImage(size: 32),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showAboutDialog(
                context: context,
                applicationName: "Admin Dashboard",
                applicationVersion: "1.0.0",
                applicationIcon: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: _fallbackImage(size: 48),
                ),
                children: const [
                  Text(
                    "This is the admin dashboard for managing orders, menu, users, and reports.",
                  ),
                ],
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: AppColors.primary,
              ),
              child: Column(
                children: [
                  ClipOval(
                    child: _fallbackImage(size: 80),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Admin Panel",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            ...List.generate(_pages.length, (index) {
              return ListTile(
                leading: Icon(
                  index == 0
                      ? Icons.shopping_cart
                      : index == 1
                          ? Icons.restaurant_menu
                          : index == 2
                              ? Icons.people
                              : Icons.bar_chart,
                ),
                title: Text(_pages[index]),
                selected: _selectedIndex == index,
                onTap: () {
                  setState(() {
                    _selectedIndex = index;
                  });
                  Navigator.pop(context); // close drawer
                },
              );
            }),
          ],
        ),
      ),
      body: Center(
        child: Text(
          "Welcome to ${_pages[_selectedIndex]} page",
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
