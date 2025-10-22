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
import '../../providers/menu_provider.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final List<Order> _incomingOrders = [];
  Timer? _fakeOrderTimer;
  int _fakeOrderCounter = 1;
  final Random _random = Random();

  // Example sales data for chart
  final List<ChartPoint> _dayChartData = const [
    ChartPoint('6 AM', 4500),
    ChartPoint('9 AM', 8200),
    ChartPoint('12 PM', 15600),
    ChartPoint('3 PM', 9800),
    ChartPoint('6 PM', 12300),
    ChartPoint('9 PM', 7500),
  ];

  @override
  void initState() {
    super.initState();
    _fakeOrderTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _addFakeOrder();
    });
  }

  @override
  void dispose() {
    _fakeOrderTimer?.cancel();
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

  void _openOrdersModal(BuildContext context, OrderProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
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

  void _openDrawerTo(BuildContext context, Widget destination) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => destination));
  }

  // Replace _buildDayChart() method with this enhanced line chart
  Widget _buildDayChart() {
    final maxY = (_dayChartData.map((e) => e.value).reduce(max)) * 1.3;
    final minY = 0.0;

    return Container(
      height: 240,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: AppColors.darkText.withOpacity(0.1),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= _dayChartData.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _dayChartData[idx].label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.darkText.withOpacity(0.6),
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: maxY / 4,
                reservedSize: 42,
                getTitlesWidget: (value, meta) {
                  final amount = value >= 1000 
                    ? 'K${(value / 1000).toStringAsFixed(0)}'
                    : value.toInt().toString();
                  return Text(
                    amount,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.darkText.withOpacity(0.6),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(
              color: AppColors.darkText.withOpacity(0.2),
              width: 1,
            ),
          ),
          minX: 0,
          maxX: _dayChartData.length.toDouble() - 1,
          minY: minY,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: _dayChartData.asMap().entries.map((entry) {
                return FlSpot(entry.key.toDouble(), entry.value.value);
              }).toList(),
              isCurved: true,
              curveSmoothness: 0.3,
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.8),
                  AppColors.primary.withOpacity(0.4),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(
                show: true,
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.3),
                    AppColors.primary.withOpacity(0.05),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              // FIXED: Use getTooltipColor instead of tooltipBgColor
              getTooltipColor: (touchedSpot) => AppColors.primary.withOpacity(0.9),
              tooltipPadding: const EdgeInsets.all(8),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((touchedSpot) {
                  final value = touchedSpot.y;
                  final label = _dayChartData[touchedSpot.x.toInt()].label;
                  return LineTooltipItem(
                    '$label\n',
                    const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    children: [
                      TextSpan(
                        text: 'Ksh ${value.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: AppColors.white.withOpacity(0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  );
                }).toList();
              },
            ),
            handleBuiltInTouches: true,
          ),
        ),
      ),
    );
  }

  // Add mini stats header for chart
  Widget _buildChartHeader() {
    final totalRevenue = _dayChartData.fold<double>(0, (sum, point) => sum + point.value);
    final peakHour = _dayChartData.reduce((a, b) => a.value > b.value ? a : b);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.05),
            AppColors.primary.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildMiniStat('TOTAL', 'Ksh ${totalRevenue.toStringAsFixed(0)}'),
          Container(
            width: 1,
            height: 30,
            color: AppColors.darkText.withOpacity(0.2),
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          _buildMiniStat('PEAK', peakHour.label),
          Container(
            width: 1,
            height: 30,
            color: AppColors.darkText.withOpacity(0.2),
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          _buildMiniStat('HIGHEST', 'Ksh ${peakHour.value.toStringAsFixed(0)}'),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText.withOpacity(0.5),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeChip(String label, bool isActive) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isActive ? AppColors.white : AppColors.darkText.withOpacity(0.7),
          ),
        ),
        selected: isActive,
        backgroundColor: AppColors.white,
        selectedColor: AppColors.primary,
        checkmarkColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isActive ? AppColors.primary : AppColors.darkText.withOpacity(0.2),
          ),
        ),
        onSelected: (bool selected) {
          // Handle time filter change
        },
      ),
    );
  }

  Widget _buildChartSection() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkText.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Revenue Analytics",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.trending_up, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      "Today",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildChartHeader(),
          const SizedBox(height: 8),
          _buildDayChart(),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTimeChip('6H', true),
                _buildTimeChip('12H', false),
                _buildTimeChip('1D', false),
                _buildTimeChip('1W', false),
                _buildTimeChip('1M', false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(OrderProvider provider) {
    final now = DateTime.now();
    final todayOrders = provider.orders.where((o) =>
      o.date.year == now.year && o.date.month == now.month && o.date.day == now.day).toList();

    final todayRevenue = todayOrders
        .where((o) => o.status == OrderStatus.delivered)
        .fold<double>(0, (sum, o) => sum + o.totalAmount);

    final pendingOrders = provider.orders.where((o) => o.status == OrderStatus.pending).length;

    final menuProvider = Provider.of<MenuProvider>(context, listen: false);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Today's Summary",
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                _buildStatRow('Total Orders', '${todayOrders.length}'),
                _buildStatRow('Revenue', 'Ksh ${todayRevenue.toStringAsFixed(0)}'),
                _buildStatRow('Pending', '$pendingOrders'),
                _buildStatRow('Menu Items', '${menuProvider.menuItems.length}'),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bar_chart, color: AppColors.white, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: AppColors.white.withOpacity(0.9), fontSize: 13),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    final recentActivities = [
      _ActivityItem('New order received', 'ORD-1001', Icons.shopping_cart, Colors.green),
      _ActivityItem('Inventory low', 'Ugali Flour', Icons.warning, Colors.orange),
      _ActivityItem('Payment processed', 'Ksh 2,300', Icons.payment, Colors.blue),
      _ActivityItem('New user registered', 'Customer', Icons.person_add, Colors.purple),
    ];

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: recentActivities.map((activity) => 
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: activity.color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(activity.icon, size: 20, color: activity.color),
              ),
              title: Text(activity.title, style: const TextStyle(fontSize: 14)),
              subtitle: Text(activity.subtitle, style: const TextStyle(fontSize: 12)),
              trailing: Text(
                '2 min ago',
                style: TextStyle(fontSize: 12, color: AppColors.darkText.withOpacity(0.6)),
              ),
              contentPadding: EdgeInsets.zero,
            )
          ).toList(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final provider = Provider.of<OrderProvider>(context);
    final menuProvider = Provider.of<MenuProvider>(context);
    
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildStatsCard(provider),
          
          // New enhanced chart section
          _buildChartSection(),

          // Quick Actions Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
            child: Row(
              children: [
                Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.refresh, color: AppColors.primary),
                  onPressed: () {
                    setState(() {});
                  },
                ),
              ],
            ),
          ),

          // Dashboard cards (simplified grid)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.1,
              ),
              children: [
                _AdminCard(
                  title: "Orders",
                  icon: Icons.shopping_cart,
                  count: provider.orders.length,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ManageOrdersScreen()),
                  ),
                ),
                _AdminCard(
                  title: "Menu",
                  icon: Icons.menu_book,
                  count: menuProvider.menuItems.length,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminMenuManagementScreen()),
                  ),
                ),
                _AdminCard(
                  title: "Reports", 
                  icon: Icons.bar_chart,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReportsScreen()),
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

          // Recent Activity Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 12),
                _buildRecentActivity(),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Ouma's Delicacy - Admin"),
        backgroundColor: AppColors.primary,
        elevation: 4,
        iconTheme: const IconThemeData(color: AppColors.white),
        titleTextStyle: const TextStyle(
          color: AppColors.white, 
          fontSize: 18, 
          fontWeight: FontWeight.bold
        ),
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
                          style: const TextStyle(
                            color: Colors.white, 
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
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
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primary,
                      child: const Text(
                        'AD',
                        style: TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
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
                    _drawerItem(Icons.dashboard, 'Dashboard', () => Navigator.of(context).pop()),
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
                    const Divider(),
                    _drawerItem(Icons.help, 'Help & Support', () {}),
                    _drawerItem(Icons.info, 'About', () {}),
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
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      onTap: onTap,
    );
  }
}

class _AdminCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final int? count;

  const _AdminCard({
    required this.title,
    required this.icon,
    required this.onTap,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: AppColors.cardBackground,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 24, color: AppColors.primary),
                  ),
                  if (count != null)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 14,
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
      elevation: 3,
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

class _ActivityItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  _ActivityItem(this.title, this.subtitle, this.icon, this.color);
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
