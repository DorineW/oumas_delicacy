// lib/screens/admin/manage_users_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/colors.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUsers();
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = _users;
      } else {
        _filteredUsers = _users.where((user) {
          final email = (user['email'] as String? ?? '').toLowerCase();
          final name = (user['name'] as String? ?? '').toLowerCase();
          final phone = (user['phone'] as String? ?? '').toLowerCase();
          return email.contains(query) || name.contains(query) || phone.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('users')
          .select('auth_id, email, name, phone, role, created_at')
          .order('created_at', ascending: false);

      setState(() {
        _users = List<Map<String, dynamic>>.from(data);
        _filteredUsers = _users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load users: $e')),
        );
      }
    }
  }

  // Create rider record in riders table
  Future<void> _createRiderRecord(String authId, String name) async {
    try {
      debugPrint('📝 Creating rider record for auth_id: $authId');
      
      // Check if rider already exists
      final existing = await Supabase.instance.client
          .from('riders')
          .select('id')
          .eq('auth_id', authId)
          .maybeSingle();
      
      if (existing != null) {
        debugPrint('✅ Rider record already exists');
        return;
      }
      
      // Create new rider record
      await Supabase.instance.client
          .from('riders')
          .insert({
            'auth_id': authId,
            'name': name,
            'is_available': true,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
      
      debugPrint('✅ Rider record created successfully');
    } catch (e) {
      debugPrint('❌ Error creating rider record: $e');
      rethrow;
    }
  }

  // Remove rider record from riders table
  Future<void> _removeRiderRecord(String authId) async {
    try {
      debugPrint('🗑️ Removing rider record for auth_id: $authId');
      
      await Supabase.instance.client
          .from('riders')
          .delete()
          .eq('auth_id', authId);
      
      debugPrint('✅ Rider record removed successfully');
    } catch (e) {
      debugPrint('❌ Error removing rider record: $e');
      rethrow;
    }
  }

  // ADDED: Update user role
  Future<void> _updateUserRole(String authId, String email, String name, String currentRole, String newRole) async {
    try {
      debugPrint('🔄 Updating user role:');
      debugPrint('   Auth ID: $authId');
      debugPrint('   Current Role: $currentRole');
      debugPrint('   New Role: $newRole');
      
      // Call database function that updates both public.users and auth.users
      debugPrint('📝 Calling admin_update_user_role function...');
      final result = await Supabase.instance.client.rpc(
        'admin_update_user_role',
        params: {
          'target_user_id': authId,
          'new_role': newRole,
        },
      );
      
      debugPrint('✅ Role updated successfully: $result');
      
      // Handle rider table operations
      if (newRole == 'rider' && currentRole != 'rider') {
        // Changing TO rider - create rider record
        await _createRiderRecord(authId, name);
      } else if (currentRole == 'rider' && newRole != 'rider') {
        // Changing FROM rider - remove rider record
        await _removeRiderRecord(authId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Updated $email to $newRole')),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }

      // Refresh the list
      await _loadUsers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update role: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ADDED: Show role change dialog
  Future<void> _showRoleDialog(String authId, String email, String name, String currentRole) async {
    String? selectedRole = currentRole;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.admin_panel_settings, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('Change User Role', style: TextStyle(fontSize: 16))),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('User: $email', style: TextStyle(fontSize: 14, color: AppColors.darkText.withOpacity(0.7))),
                const SizedBox(height: 16),
                const Text('Select Role:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                
                // Customer role
                _buildRoleOption('customer', 'Customer', Icons.person, selectedRole, setDialogState, (role) {
                  setDialogState(() => selectedRole = role);
                }),
                
                // Rider role
                _buildRoleOption('rider', 'Rider', Icons.delivery_dining, selectedRole, setDialogState, (role) {
                  setDialogState(() => selectedRole = role);
                }),
                
                // Admin role
                _buildRoleOption('admin', 'Admin', Icons.admin_panel_settings, selectedRole, setDialogState, (role) {
                  setDialogState(() => selectedRole = role);
                }),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedRole == currentRole
                    ? null
                    : () => Navigator.pop(context, selectedRole),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Update Role'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null && result != currentRole) {
      await _updateUserRole(authId, email, name, currentRole, result);
    }
  }

  Widget _buildRoleOption(
    String value,
    String label,
    IconData icon,
    String? selectedRole,
    StateSetter setDialogState,
    ValueChanged<String> onChanged,
  ) {
    final isSelected = selectedRole == value;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.lightGray.withOpacity(0.3),
        ),
      ),
      child: RadioListTile<String>(
        title: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? AppColors.primary : AppColors.darkText),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppColors.primary : AppColors.darkText,
              ),
            ),
          ],
        ),
        value: value,
        groupValue: selectedRole,
        activeColor: AppColors.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        onChanged: (val) => onChanged(val!),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.purple;
      case 'rider':
        return Colors.blue;
      case 'customer':
      default:
        return AppColors.success;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'rider':
        return Icons.delivery_dining;
      case 'customer':
      default:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Separate users by role
    final customers = _filteredUsers.where((u) => (u['role'] ?? 'customer') == 'customer').toList();
    final riders = _filteredUsers.where((u) => (u['role'] ?? 'customer') == 'rider').toList();
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Manage Users'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by email, name or phone...',
                    prefixIcon: const Icon(Icons.search, color: Colors.white70),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white70),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    hintStyle: const TextStyle(color: Colors.white70),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              // Tabs
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                tabs: [
                  Tab(text: 'Customers (${customers.length})'),
                  Tab(text: 'Riders (${riders.length})'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUserList(customers, 'customer'),
                _buildUserList(riders, 'rider'),
              ],
            ),
    );
  }

  Widget _buildUserList(List<Map<String, dynamic>> users, String filterRole) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              filterRole == 'rider' ? Icons.delivery_dining : Icons.people_outline,
              size: 80,
              color: AppColors.darkText.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No ${filterRole}s found',
              style: TextStyle(fontSize: 16, color: AppColors.darkText.withOpacity(0.5)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final role = user['role'] as String? ?? 'customer';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _getRoleColor(role).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(_getRoleIcon(role), color: _getRoleColor(role), size: 24),
            ),
            title: Text(
              user['name'] ?? 'No Name',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(user['email'] ?? '', style: const TextStyle(fontSize: 13)),
                if (user['phone'] != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    user['phone'],
                    style: TextStyle(fontSize: 12, color: AppColors.darkText.withOpacity(0.6)),
                  ),
                ],
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // ADDED: Role badge (clickable)
                InkWell(
                  onTap: () => _showRoleDialog(
                    user['auth_id'],
                    user['email'],
                    user['name'] ?? 'Unknown',
                    role,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getRoleColor(role),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getRoleIcon(role), color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          role.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit, color: Colors.white, size: 12),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}