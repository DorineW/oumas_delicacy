// lib/screens/admin/manage_users_screen.dart
import 'package:flutter/material.dart';
import '../../constants/colors.dart'; // Fixed import path

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final List<Map<String, dynamic>> _users = [
    {
      'id': '1',
      'name': 'John Doe',
      'email': 'john@example.com',
      'role': 'Customer',
      'joined': '2023-10-15',
      'orders': 5,
    },
    {
      'id': '2',
      'name': 'Jane Smith',
      'email': 'jane@example.com',
      'role': 'Customer',
      'joined': '2023-09-22',
      'orders': 12,
    },
    {
      'id': '3',
      'name': 'Admin User',
      'email': 'admin@example.com',
      'role': 'Admin',
      'joined': '2023-01-10',
      'orders': 0,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Manage Users"),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: AppColors.cardBackground,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: AppColors.cardBackground,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary,
                      child: Text(
                        user['name'][0],
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      user['name'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user['email'],
                          style: TextStyle(color: AppColors.darkText),
                        ),
                        Text(
                          'Joined: ${user['joined']} • Orders: ${user['orders']}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: user['role'] == 'Admin' ? AppColors.primary : Colors.grey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        user['role'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    onTap: () {
                      _showUserDetails(context, user, index);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showUserDetails(BuildContext context, Map<String, dynamic> user, int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("User Details - ${user['name']}"),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Name: ${user['name']}"),
                Text("Email: ${user['email']}"),
                Text("Role: ${user['role']}"),
                Text("Joined: ${user['joined']}"),
                Text("Total Orders: ${user['orders']}"),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Close"),
            ),
            if (user['role'] == 'Customer')
              ElevatedButton(
                onPressed: () {
                  // Promote to admin logic here
                  setState(() {
                    _users[index]['role'] = 'Admin';
                  });
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                ),
                child: const Text("Make Admin"),
              ),
          ],
        );
      },
    );
  }
}