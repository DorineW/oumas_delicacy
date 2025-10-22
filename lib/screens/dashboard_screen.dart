import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../providers/order_provider.dart';
import '../models/order.dart';
import 'order_history_screen.dart';
import '../utils/responsive_helper.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrderProvider>();
    final orders = provider.orders;

    final int orderCount = orders.length;
    final int favCount = 0;
    final int reviewCount = 0;

    final completedOrders = orders.where((o) => o.status == OrderStatus.delivered).length;
    final totalSpent = orders
        .where((o) => o.status == OrderStatus.delivered)
        .fold<double>(0, (sum, o) => sum + o.totalAmount);
    
    final isLandscape = ResponsiveHelper.isLandscape(context);
    
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        // Let parent HomeScreen handle navigation
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text("Dashboard"),
          backgroundColor: AppColors.primary,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.white),
          titleTextStyle: const TextStyle(
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, isLandscape ? 12 : 16, 16, 100),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 100,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome Card
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(isLandscape ? 16 : 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primary,
                              AppColors.primary.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Welcome back!",
                              style: TextStyle(
                                fontSize: isLandscape ? 20 : 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.white,
                              ),
                            ),
                            SizedBox(height: isLandscape ? 4 : 8),
                            Text(
                              "You have $orderCount orders",
                              style: TextStyle(
                                fontSize: isLandscape ? 12 : 14,
                                color: AppColors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isLandscape ? 16 : 24),

                      // Stats Cards
                      if (isLandscape)
                        IntrinsicHeight(
                          child: Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  title: 'Orders',
                                  count: orderCount.toString(),
                                  icon: Icons.shopping_bag,
                                  color: AppColors.primary,
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const OrderHistoryScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _StatCard(
                                  title: 'Favorites',
                                  count: favCount.toString(),
                                  icon: Icons.favorite,
                                  color: Colors.red,
                                  onTap: () => HapticFeedback.lightImpact(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _StatCard(
                                  title: 'Completed',
                                  count: completedOrders.toString(),
                                  icon: Icons.check_circle,
                                  color: AppColors.success,
                                  onTap: () => HapticFeedback.lightImpact(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _StatCard(
                                  title: 'Reviews',
                                  count: reviewCount.toString(),
                                  icon: Icons.star,
                                  color: Colors.amber,
                                  onTap: () => HapticFeedback.lightImpact(),
                                ),
                              ),
                            ],
                          ),
                        )
                      else Column(
                          children: [
                            IntrinsicHeight(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _StatCard(
                                      title: 'Orders',
                                      count: orderCount.toString(),
                                      icon: Icons.shopping_bag,
                                      color: AppColors.primary,
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => const OrderHistoryScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _StatCard(
                                      title: 'Favorites',
                                      count: favCount.toString(),
                                      icon: Icons.favorite,
                                      color: Colors.red,
                                      onTap: () => HapticFeedback.lightImpact(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            IntrinsicHeight(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _StatCard(
                                      title: 'Completed',
                                      count: completedOrders.toString(),
                                      icon: Icons.check_circle,
                                      color: AppColors.success,
                                      onTap: () => HapticFeedback.lightImpact(),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _StatCard(
                                      title: 'Reviews',
                                      count: reviewCount.toString(),
                                      icon: Icons.star,
                                      color: Colors.amber,
                                      onTap: () => HapticFeedback.lightImpact(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      SizedBox(height: isLandscape ? 16 : 24),

                      // Recent Orders Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Orders',
                            style: TextStyle(
                              fontSize: isLandscape ? 16 : 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkText,
                            ),
                          ),
                          if (orders.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const OrderHistoryScreen(),
                                  ),
                                );
                              },
                              child: const Text('View All'),
                            ),
                        ],
                      ),
                      SizedBox(height: isLandscape ? 8 : 12),

                      // Recent Orders List
                      orders.isEmpty
                          ? _EmptyState()
                          : Column(
                              children: orders
                                  .take(3)
                                  .map((order) => _RecentOrderCard(order: order))
                                  .toList(),
                            ),

                      SizedBox(height: isLandscape ? 16 : 24),

                      // Total Spent Card
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(isLandscape ? 16 : 20),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.account_balance_wallet, color: AppColors.primary, size: isLandscape ? 24 : 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Spent',
                                    style: TextStyle(
                                      fontSize: isLandscape ? 12 : 14,
                                      color: AppColors.darkText.withOpacity(0.6),
                                    ),
                                  ),
                                  SizedBox(height: isLandscape ? 2 : 4),
                                  Text(
                                    'Ksh ${totalSpent.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: isLandscape ? 20 : 24,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
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
      ),
    );
  }
}

// Stat Card Widget - UPDATED
class _StatCard extends StatelessWidget {
  final String title;
  final String count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StatCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              count,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.clip,
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.darkText.withOpacity(0.6),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Recent Order Card
class _RecentOrderCard extends StatelessWidget {
  final Order order;

  const _RecentOrderCard({required this.order});

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
    return status.toString().split('.').last.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14), // Reduced from 16
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Order #${order.id}',
                  style: const TextStyle(
                    fontSize: 15, // Reduced from 16
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), // Reduced horizontal
                decoration: BoxDecoration(
                  color: _getStatusColor(order.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _getStatusColor(order.status)),
                ),
                child: Text(
                  _getStatusText(order.status),
                  style: TextStyle(
                    fontSize: 10, // Reduced from 11
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(order.status),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${order.items.length} ${order.items.length == 1 ? 'item' : 'items'}',
            style: TextStyle(
              fontSize: 13, // Reduced from 14
              color: AppColors.darkText.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'KES ${order.totalAmount}',
                  style: const TextStyle(
                    fontSize: 16, // Reduced from 18
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatDate(order.date),
                style: TextStyle(
                  fontSize: 11, // Reduced from 12
                  color: AppColors.darkText.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }
}

// Empty State Widget
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 80,
            color: AppColors.darkText.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No Orders Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start ordering to see your history here',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.darkText.withOpacity(0.4),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}