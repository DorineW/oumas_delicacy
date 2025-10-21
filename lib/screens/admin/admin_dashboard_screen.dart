// lib/screens/admin/admin_dashboard_screen.dart
// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../constants/colors.dart';
import '../../services/auth_service.dart';
import '../../models/order.dart';
import '../../providers/order_provider.dart';
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

  final List<Order> _incomingOrders = [];
  Timer? _fakeOrderTimer;
  int _fakeOrderCounter = 1;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

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
          customerId: 'cust_$_fakeOrderCounter',
          customerName: 'Customer $_fakeOrderCounter',
          date: now,
          items: chosen.map((e) => OrderItem(
            id: 'item_${_random.nextInt(100)}',
            title: e.name,
            quantity: 1 + _random.nextInt(3),
            price: e.price.toInt(),
          )).toList(),
          totalAmount: amount.toInt(),
          status: OrderStatus.pending,
          deliveryType: _random.nextBool() ? DeliveryType.delivery : DeliveryType.pickup,
        ),
      );
      _fakeOrderCounter++;
    });
  }

  void _markOrderHandled(int index, OrderProvider provider) {
    final order = _incomingOrders[index];
    provider.updateStatus(order.id, OrderStatus.confirmed);
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

  void _openOrdersModal(BuildContext context, OrderProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Incoming Orders (${_incomingOrders.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_incomingOrders.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ManageOrdersScreen()),
                          );
                        },
                        child: const Text('View All'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _incomingOrders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_off,
                              size: 60,
                              color: AppColors.darkText.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No New Orders',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.darkText.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _incomingOrders.length,
                        itemBuilder: (_, index) {
                          final order = _incomingOrders[index];
                          return _NotificationOrderCard(
                            order: order,
                            onMarkHandled: () => _markOrderHandled(index, provider),
                            onViewOrder: () {
                              Navigator.of(context).pop();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ManageOrdersScreen(
                                    highlightOrderId: order.id,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
            ],
          ),
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
    final orderProvider = Provider.of<OrderProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Ouma's Delicacy - Admin Panel"),
        backgroundColor: AppColors.primary,
        elevation: 4,
        iconTheme: const IconThemeData(color: AppColors.white),
        actionsIconTheme: const IconThemeData(color: AppColors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications),
                  tooltip: 'Incoming Orders',
                  color: AppColors.white,
                  onPressed: () => _openOrdersModal(context, orderProvider),
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
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            color: AppColors.white,
            onPressed: () async {
              if (!mounted) return;
              await Provider.of<AuthService>(context, listen: false).logout();
              if (!mounted) return;
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/login',
                (route) => false,
              );
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
              // prevent overflow by allowing the title to wrap and ellipsize
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 14, // slightly smaller to fit better
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationOrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onMarkHandled;
  final VoidCallback onViewOrder;

  const _NotificationOrderCard({
    required this.order,
    required this.onMarkHandled,
    required this.onViewOrder,
  });

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.inProcess:
        return Colors.purple;
      case OrderStatus.delivered:
        return AppColors.success;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }

  String _getStatusText(OrderStatus status) {
    return status.toString().split('.').last;
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${order.id}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getStatusColor(order.status)),
                  ),
                  child: Text(
                    _getStatusText(order.status),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(order.status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Customer: ${order.customerName}',
              style: TextStyle(
                color: AppColors.darkText.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${order.deliveryType.toString().split('.').last} • ${_formatTime(order.date)}',
              style: TextStyle(
                color: AppColors.darkText.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              order.items.map((item) => '${item.title} x${item.quantity}').join(', '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.darkText.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'KES ${order.totalAmount}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  '${order.items.length} ${order.items.length == 1 ? 'item' : 'items'}',
                  style: TextStyle(
                    color: AppColors.darkText.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onMarkHandled,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.success,
                      side: BorderSide(color: AppColors.success),
                    ),
                    child: const Text('Confirm Order'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onViewOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('View Details'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Models
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