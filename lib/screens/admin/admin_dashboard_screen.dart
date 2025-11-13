// lib/screens/admin/admin_dashboard_screen.dart
// ignore_for_file: deprecated_member_use, unused_import

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/colors.dart';
import '../../services/auth_service.dart';
import '../../models/order.dart';
import '../../providers/order_provider.dart';
import '../../providers/favorites_provider.dart'; // ADDED
import '../../providers/cart_provider.dart'; // ADDED
import 'manage_orders_screen.dart';
import 'manage_users_screen.dart';
import 'reports_screen.dart';
import 'inventory_screen.dart';
import 'admin_menu_management_screen.dart';
import 'admin_chat_list_screen.dart';
import '../../providers/menu_provider.dart';
import '../../services/chat_service.dart';

/// Models
class ChartPoint {
  final String label;
  final double value;
  const ChartPoint(this.label, this.value);
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _showChart = false;
  String _selectedTimeFilter = '6H';
  double _todayDeliveredRevenue = 0.0; // Store revenue from database view

  @override
  void initState() {
    super.initState();
    // Load revenue data (orders already loaded at login)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTodayRevenue(); // Load revenue from view
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Load today's delivered revenue from database view
  Future<void> _loadTodayRevenue() async {
    try {
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      final response = await Supabase.instance.client
          .from('daily_revenue_breakdown')
          .select('daily_revenue, completed_count')
          .eq('order_day', todayStr)
          .maybeSingle();
      
      if (response != null && mounted) {
        setState(() {
          _todayDeliveredRevenue = (response['daily_revenue'] as num?)?.toDouble() ?? 0.0;
        });
        debugPrint('✅ Loaded today\'s revenue from view: $_todayDeliveredRevenue');
      }
    } catch (e) {
      debugPrint('❌ Failed to load today\'s revenue: $e');
    }
  }

  void _markOrderHandled(String orderId, OrderProvider provider) {
    provider.updateStatus(orderId, OrderStatus.confirmed);
  }

  List<Order> _getPendingOrders(OrderProvider provider) {
    return provider.orders.where((o) => o.status == OrderStatus.confirmed).toList();
  }

  void _openOrdersModal(BuildContext context, OrderProvider provider) {
    final pendingOrders = _getPendingOrders(provider);
    
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
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'New Orders (${provider.orders.where((o) => o.status == OrderStatus.confirmed).length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (pendingOrders.isNotEmpty)
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
              // Content
              Expanded(
                child: pendingOrders.isEmpty
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
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: pendingOrders.length,
                        itemBuilder: (_, index) {
                          final order = pendingOrders[index];
                          return _NotificationOrderCard(
                            order: order,
                            onMarkHandled: () => _markOrderHandled(order.id, provider),
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

  List<ChartPoint> get _filteredChartData {
    final provider = Provider.of<OrderProvider>(context, listen: false);
    final deliveredOrders = provider.orders.where((o) => o.status == OrderStatus.delivered).toList();
    
    switch (_selectedTimeFilter) {
      case '12H':
        return _generateChartData(deliveredOrders, 12, (date) {
          final hour = date.hour;
          if (hour % 2 == 0) return '${hour.toString().padLeft(2, '0')}:00';
          return null;
        });
      case '1D':
        return _generateChartData(deliveredOrders, 7, (date) {
          const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
          return days[date.weekday - 1];
        });
      case '1W':
        return _generateChartData(deliveredOrders, 4, (date) {
          final weekNumber = ((date.day - 1) ~/ 7) + 1;
          return 'W$weekNumber';
        });
      case '1M':
        return _generateChartData(deliveredOrders, 6, (date) {
          const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
          return months[date.month - 1];
        });
      case '6H':
      default:
        return _generateChartData(deliveredOrders, 6, (date) {
          final hour = date.hour;
          final period = hour < 12 ? 'AM' : 'PM';
          final displayHour = hour % 12 == 0 ? 12 : hour % 12;
          return '$displayHour $period';
        });
    }
  }

  List<ChartPoint> _generateChartData(
    List<Order> deliveredOrders,
    int dataPoints,
    String? Function(DateTime) labelGenerator,
  ) {
    final now = DateTime.now();
    final Map<String, double> dataMap = {};
    
    for (int i = dataPoints - 1; i >= 0; i--) {
      DateTime timePoint;
      switch (_selectedTimeFilter) {
        case '12H':
          timePoint = now.subtract(Duration(hours: i * 2));
          break;
        case '1D':
          timePoint = now.subtract(Duration(days: i));
          break;
        case '1W':
          timePoint = now.subtract(Duration(days: i * 7));
          break;
        case '1M':
          timePoint = DateTime(now.year, now.month - i, 1);
          break;
        case '6H':
        default:
          timePoint = now.subtract(Duration(hours: i));
      }
      
      final label = labelGenerator(timePoint);
      if (label != null) {
        dataMap[label] = 0;
      }
    }

    for (final order in deliveredOrders) {
      final label = labelGenerator(order.date);
      if (label != null && dataMap.containsKey(label)) {
        dataMap[label] = (dataMap[label] ?? 0) + order.totalAmount.toDouble();
      }
    }

    return dataMap.entries.map((e) => ChartPoint(e.key, e.value)).toList();
  }

  Widget _buildChartHeader() {
    final data = _filteredChartData;
    final totalRevenue = data.fold<double>(0, (sum, point) => sum + point.value);
    final peakHour = data.isNotEmpty
        ? data.reduce((a, b) => a.value > b.value ? a : b)
        : const ChartPoint('N/A', 0);

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
        children: <Widget>[
          _buildMiniStat('DELIVERED', 'Ksh ${totalRevenue.toStringAsFixed(0)}'),
          Container(
            width: 1,
            height: 30,
            color: AppColors.darkText.withOpacity(0.2),
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          _buildMiniStat('PEAK TIME', peakHour.label),
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
            style: const TextStyle(
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
          if (selected) {
            setState(() {
              _selectedTimeFilter = label;
            });
          }
        },
      ),
    );
  }

  Widget _buildDayChart() {
    final data = _filteredChartData;
    final hasData = data.any((point) => point.value > 0);
    final maxY = data.isEmpty ? 1000.0 : max(1000.0, (data.map((e) => e.value).reduce(max)) * 1.3);
    const minY = 0.0;
    final horizontalInterval = max(1.0, maxY / 4);

    return Container(
      height: 240,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Stack(
        children: [
          LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: horizontalInterval,
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
                      if (idx < 0 || idx >= data.length) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          data[idx].label,
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
                    interval: horizontalInterval,
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
              maxX: data.isEmpty ? 5 : data.length.toDouble() - 1,
              minY: minY,
              maxY: maxY,
              lineBarsData: hasData
                ? [
                    LineChartBarData(
                      spots: data.asMap().entries.map((entry) {
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
                      dotData: const FlDotData(show: true),
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
                  ]
                : [],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (touchedSpot) => AppColors.primary.withOpacity(0.9),
                  tooltipPadding: const EdgeInsets.all(8),
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((touchedSpot) {
                      if (touchedSpot.x.toInt() >= data.length) return null;
                      final value = touchedSpot.y;
                      final label = data[touchedSpot.x.toInt()].label;
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
                enabled: hasData,
              ),
            ),
          ),
          if (!hasData)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.darkText.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.analytics_outlined,
                      size: 48,
                      color: AppColors.primary.withOpacity(0.3),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No Data Available',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'No delivered orders for $_selectedTimeFilter',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.darkText.withOpacity(0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChartSection() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
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
              const Text(
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
                    const Icon(Icons.trending_up, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      _selectedTimeFilter,
                      style: const TextStyle(
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
                _buildTimeChip('6H', _selectedTimeFilter == '6H'),
                _buildTimeChip('12H', _selectedTimeFilter == '12H'),
                _buildTimeChip('1D', _selectedTimeFilter == '1D'),
                _buildTimeChip('1W', _selectedTimeFilter == '1W'),
                _buildTimeChip('1M', _selectedTimeFilter == '1M'),
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

    // Use revenue from database view (more accurate than in-memory calculation)
    final todayRevenue = _todayDeliveredRevenue;

    final pendingOrders = provider.orders.where((o) => o.status == OrderStatus.confirmed).length;
    final deliveredToday = todayOrders.where((o) => o.status == OrderStatus.delivered).length;

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
                _buildStatRow('Delivered Revenue', 'Ksh ${todayRevenue.toStringAsFixed(0)}'),
                _buildStatRow('Delivered Today', '$deliveredToday'),
                _buildStatRow('Confirmed', '$pendingOrders'),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _showChart = !_showChart;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _showChart ? Icons.visibility_off : Icons.bar_chart,
                color: AppColors.white,
                size: 24,
              ),
            ),
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
    final provider = Provider.of<OrderProvider>(context);
    
    final recentOrders = provider.orders.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final displayOrders = recentOrders.take(5).toList();

    if (displayOrders.isEmpty) {
      return Card(
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.history,
                  size: 48,
                  color: AppColors.darkText.withOpacity(0.3),
                ),
                const SizedBox(height: 12),
                Text(
                  'No Recent Activity',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.darkText.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: displayOrders.map((order) {
            final timeDiff = DateTime.now().difference(order.date);
            final timeAgo = _formatTimeAgo(timeDiff);
            
            return ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getActivityColor(order.status).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getActivityIcon(order.status),
                  size: 20,
                  color: _getActivityColor(order.status),
                ),
              ),
              title: Text(
                _getActivityTitle(order),
                style: const TextStyle(fontSize: 14),
              ),
              subtitle: Text(
                '${order.customerName} • ${order.items.length} items',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Text(
                timeAgo,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.darkText.withOpacity(0.6),
                ),
              ),
              contentPadding: EdgeInsets.zero,
            );
          }).toList(),
        ),
      ),
    );
  }

  String _formatTimeAgo(Duration diff) {
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Color _getActivityColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.preparing:
        return Colors.purple;
      case OrderStatus.outForDelivery:
        return Colors.indigo;
      case OrderStatus.delivered:
        return AppColors.success;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }

  IconData _getActivityIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.confirmed:
        return Icons.check_circle;
      case OrderStatus.preparing:
        return Icons.restaurant;
      case OrderStatus.outForDelivery:
        return Icons.delivery_dining;
      case OrderStatus.delivered:
        return Icons.done_all;
      case OrderStatus.cancelled:
        return Icons.cancel;
    }
  }

  String _getActivityTitle(Order order) {
    switch (order.status) {
      case OrderStatus.confirmed:
        return 'Order confirmed';
      case OrderStatus.preparing:
        return 'Order in preparation';
      case OrderStatus.outForDelivery:
        return 'Out for delivery';
      case OrderStatus.delivered:
        return 'Order delivered';
      case OrderStatus.cancelled:
        return 'Order cancelled';
    }
  }

  Widget _buildBody() {
    final provider = Provider.of<OrderProvider>(context);
    final menuProvider = Provider.of<MenuProvider>(context);
    
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildStatsCard(provider),
          
          if (_showChart) _buildChartSection(),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
            child: Row(
              children: [
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppColors.primary),
                  onPressed: () {
                    setState(() {});
                  },
                ),
              ],
            ),
          ),

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
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
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
    final pendingOrders = _getPendingOrders(orderProvider);

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
                  tooltip: 'Pending Orders',
                  color: AppColors.white,
                  onPressed: () => _openOrdersModal(context, orderProvider),
                ),
                if (pendingOrders.isNotEmpty)
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
                          '${pendingOrders.length}',
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
              // Clear all provider data
              final favoritesProvider = Provider.of<FavoritesProvider>(context, listen: false);
              final cartProvider = Provider.of<CartProvider>(context, listen: false);
              favoritesProvider.clearFavorites();
              cartProvider.clearCart();
              
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
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        'AD',
                        style: TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
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
                    _supportChatsDrawerItem(context),
                    _drawerItem(Icons.bar_chart, 'Reports',
                        () => _openDrawerTo(context, const ReportsScreen())),
                    _drawerItem(Icons.inventory, 'Inventory',
                        () => _openDrawerTo(context, const InventoryScreen())),
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

  Widget _supportChatsDrawerItem(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ChatService.instance.streamAdminRooms(),
      builder: (context, snapshot) {
        final rooms = snapshot.data ?? const [];
        int unreadTotal = 0;
        for (final r in rooms) {
          final v = r['unread_admin'];
          if (v is int) unreadTotal += v;
          else if (v is num) unreadTotal += v.toInt();
        }
        return ListTile(
          leading: const Icon(Icons.support_agent, color: AppColors.primary),
          title: const Text('Support Chats'),
          trailing: unreadTotal > 0
              ? Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                  child: Center(
                    child: Text(
                      unreadTotal > 99 ? '99+' : '$unreadTotal',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
              : null,
          onTap: () => _openDrawerTo(context, const AdminChatListScreen()),
        );
      },
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
                  style: const TextStyle(
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
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.preparing:
        return Colors.purple;
      case OrderStatus.outForDelivery:
        return Colors.indigo;
      case OrderStatus.delivered:
        return AppColors.success;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.outForDelivery:
        return 'Out for Delivery';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
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
                      side: const BorderSide(color: AppColors.success),
                    ),
                    child: const Text('Acknowledge'),
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