import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  bool _notificationsEnabled = true;
  bool _lowStockAlerts = true;
  bool _newOrderAlerts = true;
  String _selectedLanguage = 'English';
  String _selectedTheme = 'Light';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Settings'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionHeader('Notifications'),
          _buildSwitchSetting(
            title: 'Enable Notifications',
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() {
                _notificationsEnabled = value;
              });
              Provider.of<NotificationService>(context, listen: false)
                  .toggleNotifications(value);
            },
          ),
          _buildSwitchSetting(
            title: 'Low Stock Alerts',
            value: _lowStockAlerts,
            onChanged: (value) => setState(() => _lowStockAlerts = value),
          ),
          _buildSwitchSetting(
            title: 'New Order Alerts',
            value: _newOrderAlerts,
            onChanged: (value) => setState(() => _newOrderAlerts = value),
          ),
          
          const SizedBox(height: 24),
          _buildSectionHeader('Appearance'),
          _buildDropdownSetting(
            title: 'Language',
            value: _selectedLanguage,
            items: const ['English', 'Spanish', 'French', 'German'],
            onChanged: (value) => setState(() => _selectedLanguage = value!),
          ),
          _buildDropdownSetting(
            title: 'Theme',
            value: _selectedTheme,
            items: const ['Light', 'Dark', 'System Default'],
            onChanged: (value) => setState(() => _selectedTheme = value!),
          ),
          
          const SizedBox(height: 24),
          _buildSectionHeader('Account'),
          _buildButtonSetting(
            title: 'Change Password',
            icon: Icons.lock,
            onTap: () => _showChangePasswordDialog(context),
          ),
          _buildButtonSetting(
            title: 'Manage Administrators',
            icon: Icons.admin_panel_settings,
            onTap: () {},
          ),
          
          const SizedBox(height: 24),
          _buildSectionHeader('Data'),
          _buildButtonSetting(
            title: 'Export Data',
            icon: Icons.file_download,
            onTap: () {},
          ),
          _buildButtonSetting(
            title: 'Backup & Restore',
            icon: Icons.backup,
            onTap: () {},
          ),
          
          const SizedBox(height: 24),
          _buildSectionHeader('About'),
          _buildInfoSetting('App Version', '1.0.0'),
          _buildInfoSetting('Last Updated', 'October 15, 2023'),
          
          const SizedBox(height: 32),
          Center(
            child: ElevatedButton(
              onPressed: () {
                Provider.of<AuthService>(context, listen: false).logout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildSwitchSetting({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      title: Text(title),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
    );
  }

  Widget _buildDropdownSetting({
    required String title,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return ListTile(
      title: Text(title),
      trailing: DropdownButton<String>(
        value: value,
        items: items.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildButtonSetting({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildInfoSetting(String title, String value) {
    return ListTile(
      title: Text(title),
      trailing: Text(value, style: const TextStyle(color: Colors.grey)),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Change Password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: oldPasswordController,
                  decoration: const InputDecoration(labelText: 'Current Password'),
                  obscureText: true,
                ),
                TextField(
                  controller: newPasswordController,
                  decoration: const InputDecoration(labelText: 'New Password'),
                  obscureText: true,
                ),
                TextField(
                  controller: confirmPasswordController,
                  decoration: const InputDecoration(labelText: 'Confirm New Password'),
                  obscureText: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Here you would typically validate and change the password
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password updated successfully')),
                );
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }
}