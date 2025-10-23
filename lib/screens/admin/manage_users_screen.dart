// lib/screens/admin/manage_users_screen.dart
import 'package:flutter/material.dart';
import '../../constants/colors.dart';

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
      'phone': '+254712345678',
      'role': 'Customer',
      'joined': '2023-10-15',
      'lastActive': '2024-01-15',
      'orders': 5,
      'totalSpent': 12500.00,
      'status': 'active',
      'avatar': '',
    },
    {
      'id': '2',
      'name': 'Jane Smith',
      'email': 'jane@example.com',
      'phone': '+254723456789',
      'role': 'Customer',
      'joined': '2023-09-22',
      'lastActive': '2024-01-14',
      'orders': 12,
      'totalSpent': 28400.00,
      'status': 'active',
      'avatar': '',
    },
    {
      'id': '3',
      'name': 'Admin User',
      'email': 'admin@example.com',
      'phone': '+254734567890',
      'role': 'Admin',
      'joined': '2023-01-10',
      'lastActive': '2024-01-15',
      'orders': 0,
      'totalSpent': 0.00,
      'status': 'active',
      'avatar': '',
    },
    {
      'id': '4',
      'name': 'Mike Johnson',
      'email': 'mike@example.com',
      'phone': '+254745678901',
      'role': 'Customer',
      'joined': '2023-11-05',
      'lastActive': '2024-01-10',
      'orders': 2,
      'totalSpent': 4500.00,
      'status': 'inactive',
      'avatar': '',
    },
    {
      'id': '5',
      'name': 'Sarah Wilson',
      'email': 'sarah@example.com',
      'phone': '+254756789012',
      'role': 'VIP Customer',
      'joined': '2023-08-15',
      'lastActive': '2024-01-15',
      'orders': 25,
      'totalSpent': 62500.00,
      'status': 'active',
      'avatar': '',
    },
  ];

  String _searchQuery = '';
  String _selectedFilter = 'all';
  bool _sortAscending = true;

  List<Map<String, dynamic>> get _filteredUsers {
    List<Map<String, dynamic>> filtered = _users.where((user) {
      final matchesSearch = user['name'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
          user['email'].toLowerCase().contains(_searchQuery.toLowerCase());
      
      final matchesFilter = _selectedFilter == 'all' || 
          user['role'].toLowerCase().contains(_selectedFilter.toLowerCase()) ||
          (_selectedFilter == 'inactive' && user['status'] == 'inactive');
      
      return matchesSearch && matchesFilter;
    }).toList();

    filtered.sort((a, b) {
      if (_sortAscending) {
        return a['name'].compareTo(b['name']);
      } else {
        return b['name'].compareTo(a['name']);
      }
    });

    return filtered;
  }

  void _showUserDetails(BuildContext context, Map<String, dynamic> user, int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        user['name'][0],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user['name'],
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            user['email'],
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getRoleColor(user['role']).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _getRoleColor(user['role'])),
                            ),
                            child: Text(
                              user['role'],
                              style: TextStyle(
                                color: _getRoleColor(user['role']),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _buildStatItem('Orders', '${user['orders']}'),
                    _buildStatItem('Total Spent', 'Ksh ${user['totalSpent'].toStringAsFixed(0)}'),
                    _buildStatItem('Status', user['status']),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildDetailRow(Icons.phone, 'Phone', user['phone']),
                    _buildDetailRow(Icons.calendar_today, 'Joined', user['joined']),
                    _buildDetailRow(Icons.access_time, 'Last Active', user['lastActive']),
                    if (user['role'] == 'Customer') ...[
                      const SizedBox(height: 16),
                      _buildDetailRow(Icons.star, 'Customer Tier', _getCustomerTier(user['totalSpent'])),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    if (user['role'] == 'Customer') ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.upgrade, size: 18),
                          label: const Text('Make Admin'),
                          onPressed: () {
                            _promoteToAdmin(index);
                            Navigator.pop(context);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.message, size: 18),
                        label: const Text('Send Message'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          _sendMessage(user);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Text(value, style: const TextStyle(color: AppColors.darkText)),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'vip customer':
        return Colors.amber[700]!;
      default:
        return AppColors.primary;
    }
  }

  String _getCustomerTier(double totalSpent) {
    if (totalSpent > 50000) return 'VIP';
    if (totalSpent > 20000) return 'Gold';
    if (totalSpent > 5000) return 'Silver';
    return 'Bronze';
  }

  void _promoteToAdmin(int index) {
    setState(() {
      _users[index]['role'] = 'Admin';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_users[index]['name']} promoted to Admin'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _sendMessage(Map<String, dynamic> user) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Message sent to ${user['name']}')),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Filter Users'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFilterOption('All Users', 'all'),
              _buildFilterOption('Admins', 'admin'),
              _buildFilterOption('Customers', 'customer'),
              _buildFilterOption('VIP Customers', 'vip'),
              _buildFilterOption('Inactive', 'inactive'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedFilter = 'all';
                });
                Navigator.pop(context);
              },
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterOption(String title, String value) {
    return ListTile(
      leading: Radio(
        value: value,
        groupValue: _selectedFilter,
        onChanged: (newValue) {
          setState(() {
            _selectedFilter = newValue.toString();
          });
          Navigator.pop(context);
        },
      ),
      title: Text(title),
      onTap: () {
        setState(() {
          _selectedFilter = value;
        });
        Navigator.pop(context);
      },
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      child: InkWell(
        onTap: () => _showUserDetails(context, user, index),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary,
                child: Text(
                  user['name'][0],
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          user['name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (user['status'] == 'inactive')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Inactive',
                              style: TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user['email'],
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getRoleColor(user['role']).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            user['role'],
                            style: TextStyle(
                              color: _getRoleColor(user['role']),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${user['orders']} orders',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () => _showUserActions(context, user, index),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUserActions(BuildContext context, Map<String, dynamic> user, int index) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.visibility),
                title: const Text('View Details'),
                onTap: () {
                  Navigator.pop(context);
                  _showUserDetails(context, user, index);
                },
              ),
              ListTile(
                leading: const Icon(Icons.message),
                title: const Text('Send Message'),
                onTap: () {
                  Navigator.pop(context);
                  _sendMessage(user);
                },
              ),
              if (user['role'] == 'Customer')
                ListTile(
                  leading: const Icon(Icons.upgrade),
                  title: const Text('Make Admin'),
                  onTap: () {
                    Navigator.pop(context);
                    _promoteToAdmin(index);
                  },
                ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.block, color: Colors.red[400]),
                title: const Text('Deactivate User', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _toggleUserStatus(index);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _toggleUserStatus(int index) {
    setState(() {
      _users[index]['status'] = _users[index]['status'] == 'active' ? 'inactive' : 'active';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Manage Users"),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter Users',
          ),
          IconButton(
            icon: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
            onPressed: () {
              setState(() {
                _sortAscending = !_sortAscending;
              });
            },
            tooltip: 'Sort',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.white,
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search users by name or email...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: AppColors.cardBackground,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      '${_filteredUsers.length} users found',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    if (_selectedFilter != 'all')
                      Chip(
                        label: Text(
                          _selectedFilter.toUpperCase(),
                          style: const TextStyle(fontSize: 12),
                        ),
                        onDeleted: () {
                          setState(() {
                            _selectedFilter = 'all';
                          });
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _filteredUsers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No users found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your search or filter',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      final actualIndex = _users.indexWhere((u) => u['id'] == user['id']);
                      return _buildUserCard(user, actualIndex);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}