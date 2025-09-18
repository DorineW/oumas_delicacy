// lib/screens/admin/admin_dashboard_screen.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../constants/colors.dart';
import '../../services/auth_service.dart';
import 'manage_orders_screen.dart';
import 'manage_users_screen.dart';
import 'reports_screen.dart';
import 'inventory_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_menu_management_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _showChart = true;
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  // Fake incoming orders
  final List<Order> _incomingOrders = [];
  Timer? _fakeOrderTimer;
  int _fakeOrderCounter = 1;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    // Add a fake order every 15 seconds
    _fakeOrderTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _addFakeOrder();
    });

    _scrollController.addListener(() {
      final atBottom =
          _scrollController.offset >= _scrollController.position.maxScrollExtent - 50;
      setState(() {
        _showScrollToTop = atBottom;
      });
    });
  }

  @override
  void dispose() {
    _fakeOrderTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _addFakeOrder() {
    final count = 1 + _random.nextInt(3);
    final chosen = List.generate(count, (_) => menuItems[_random.nextInt(menuItems.length)]);

    final amount = chosen.fold<double>(0, (s, it) => s + it.price);
    final now = DateTime.now();

    setState(() {
      _incomingOrders.insert(
        0,
        Order(
          id: 'ORD-${1000 + _fakeOrderCounter}',
          customer: 'Customer $_fakeOrderCounter',
          amount: amount,
          time: now,
          items: chosen.map((e) => e.name).toList(),
        ),
      );
      _fakeOrderCounter++;
    });
  }

  void _markOrderHandled(int index) {
    setState(() {
      _incomingOrders.removeAt(index);
    });
  }

  // Example sales data
  final List<ChartPoint> _dayChartData = const [
    ChartPoint('6 AM', 4500),
    ChartPoint('9 AM', 8200),
    ChartPoint('12 PM', 15600),
    ChartPoint('3 PM', 9800),
    ChartPoint('6 PM', 12300),
    ChartPoint('9 PM', 7500),
  ];

  Widget _buildDayChart() {
    final maxY = (_dayChartData.map((e) => e.value).reduce(max)) * 1.2;

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY <= 0 ? 10 : maxY,
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 52,
                interval: maxY / 4,
                getTitlesWidget: (value, _) {
                  final txt = value >= 1000
                      ? 'K ${(value / 1000).toStringAsFixed(0)}'
                      : value.toStringAsFixed(0);
                  return Text(
                    txt,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.darkText.withOpacity(0.8),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= _dayChartData.length) return const SizedBox();
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      _dayChartData[idx].label,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.darkText.withOpacity(0.85),
                      ),
                    ),
                  );
                },
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, _) {
                final label = _dayChartData[group.x.toInt()].label;
                final value = rod.toY;
                return BarTooltipItem(
                  '$label\n',
                  TextStyle(
                    color: AppColors.darkText,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  children: [
                    TextSpan(
                      text: 'Ksh ${value.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: AppColors.darkText.withOpacity(0.9),
                        fontSize: 11,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          gridData: FlGridData(show: true),
          borderData: FlBorderData(show: false),
          barGroups: _dayChartData.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.value,
                  width: 18,
                  borderRadius: BorderRadius.circular(8),
                  color: AppColors.primary,
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  void _openOrdersModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          minChildSize: 0.25,
          initialChildSize: 0.6,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 6,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Text(
                    'Incoming Orders (${_incomingOrders.length})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _incomingOrders.isEmpty
                        ? Center(
                            child: Text(
                              'No incoming orders',
                              style: TextStyle(color: AppColors.darkText),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: _incomingOrders.length,
                            itemBuilder: (_, index) {
                              final order = _incomingOrders[index];
                              return Card(
                                color: AppColors.background,
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.primary,
                                    child: Text(
                                      order.customer[0],
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  title: Text(
                                    order.id,
                                    style: TextStyle(
                                      color: AppColors.darkText,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${order.items.join(', ')}\n${order.time.hour.toString().padLeft(2, '0')}:${order.time.minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      color: AppColors.darkText.withOpacity(0.8),
                                    ),
                                  ),
                                  isThreeLine: true,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.check_circle, size: 20),
                                        color: AppColors.success,
                                        tooltip: 'Mark handled',
                                        onPressed: () {
                                          _markOrderHandled(index);
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.visibility, size: 20),
                                        tooltip: 'View',
                                        color: AppColors.darkText,
                                        onPressed: () {
                                          final selectedOrder = _incomingOrders[index];
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => ManageOrdersScreen(
                                                highlightOrderId: selectedOrder.id,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _openDrawerTo(BuildContext context, Widget destination) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => destination));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Ouma's Delicacy - Admin Panel"),
        backgroundColor: AppColors.primary,
        elevation: 4,
        iconTheme: const IconThemeData(color: AppColors.white),
        actionsIconTheme: const IconThemeData(color: AppColors.white),
        actions: [
          // Notifications
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications),
                  tooltip: 'Incoming Orders',
                  color: AppColors.white,
                  onPressed: _openOrdersModal,
                ),
                if (_incomingOrders.isNotEmpty)
                  Positioned(
                    right: 6,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                      child: Center(
                        child: Text(
                          '${_incomingOrders.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Logout
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            color: AppColors.white,
            onPressed: () {
              Provider.of<AuthService>(context, listen: false).logout();
            },
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: _showScrollToTop ? _scrollToTop : _scrollToBottom,
        child: Icon(
          _showScrollToTop ? Icons.arrow_upward : Icons.arrow_downward,
          color: AppColors.white,
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Container(
          color: AppColors.cardBackground,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DrawerHeader(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        'AD',
                        style: TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Admin',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                      ),
                    ),
                    Text(
                      'Ouma\'s Delicacy',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.darkText.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    _drawerItem(Icons.shopping_cart, 'Manage Orders',
                        () => _openDrawerTo(context, const ManageOrdersScreen())),
                    _drawerItem(Icons.menu_book, 'Menu Management',
                        () => _openDrawerTo(context, const AdminMenuManagementScreen())),
                    _drawerItem(Icons.people, 'Manage Users',
                        () => _openDrawerTo(context, const ManageUsersScreen())),
                    _drawerItem(Icons.bar_chart, 'Reports',
                        () => _openDrawerTo(context, const ReportsScreen())),
                    _drawerItem(Icons.inventory, 'Inventory',
                        () => _openDrawerTo(context, const InventoryScreen())),
                    _drawerItem(Icons.settings, 'Settings',
                        () => _openDrawerTo(context, const AdminSettingsScreen())),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: onTap,
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        children: [
          // Header + Chart
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              border: Border(
                bottom: BorderSide(color: AppColors.primary.withOpacity(0.2)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Welcome, Admin",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Manage your restaurant efficiently",
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.darkText.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _showChart ? Icons.expand_less : Icons.expand_more,
                        color: AppColors.darkText,
                      ),
                      tooltip:
                          _showChart ? 'Collapse daily chart' : 'Show daily chart',
                      onPressed: () => setState(() => _showChart = !_showChart),
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  firstChild: Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ReportsScreen()),
                        );
                      },
                      child: Card(
                        color: AppColors.cardBackground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Today's Sales (Hourly) (Tap for details)",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.darkText,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildDayChart(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  secondChild: const SizedBox.shrink(),
                  crossFadeState: _showChart
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  duration: const Duration(milliseconds: 300),
                ),
              ],
            ),
          ),

          // Dashboard cards
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.2,
              ),
              children: [
                _AdminCard(
                  title: "Manage Orders",
                  icon: Icons.shopping_cart,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ManageOrdersScreen()),
                  ),
                ),
                _AdminCard(
                  title: "Menu Management",
                  icon: Icons.menu_book,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdminMenuManagementScreen()),
                  ),
                ),
                _AdminCard(
                  title: "Manage Users",
                  icon: Icons.people,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ManageUsersScreen()),
                  ),
                ),
                _AdminCard(
                  title: "Sales Reports",
                  icon: Icons.bar_chart,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReportsScreen()),
                  ),
                ),
                _AdminCard(
                  title: "Inventory",
                  icon: Icons.inventory,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const InventoryScreen()),
                  ),
                ),
                _AdminCard(
                  title: "Settings",
                  icon: Icons.settings,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminSettingsScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _AdminCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppColors.cardBackground,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 30, color: AppColors.primary),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Models
class Order {
  final String id;
  final String customer;
  final double amount;
  final DateTime time;
  final List<String> items;

  Order({
    required this.id,
    required this.customer,
    required this.amount,
    required this.time,
    required this.items,
  });
}

class ChartPoint {
  final String label;
  final double value;
  const ChartPoint(this.label, this.value);
}

class MenuItem {
  final String name;
  final double price;
  const MenuItem(this.name, this.price);
}

final List<MenuItem> menuItems = [
  MenuItem('UGALI NYAMA CHOMA', 210),
  MenuItem('UGALI LIVER', 220),
  MenuItem('PILAU LIVER', 230),
  MenuItem('UGALI SAMAKI', 300),
  MenuItem('RICE LIVER', 220),
  MenuItem('CHAPATI PLAIN', 20),
  MenuItem('MATOKE BEEF', 230),
  MenuItem('SAMOSA', 20),
  MenuItem('SODA 500ml', 70),
];
final List<MenuItem> drinkItems = [
  MenuItem('SODA 500ml', 70),
  MenuItem('WATER 500ml', 50),
  MenuItem('JUICE 300ml', 100),
];