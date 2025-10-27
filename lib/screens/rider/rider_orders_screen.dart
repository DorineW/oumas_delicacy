// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/order.dart';
import '../../providers/order_provider.dart';
import '../../services/auth_service.dart';

class RiderOrdersScreen extends StatefulWidget {
  const RiderOrdersScreen({super.key});

  @override
  State<RiderOrdersScreen> createState() => _RiderOrdersScreenState();
}

class _RiderOrdersScreenState extends State<RiderOrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.darkText.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderList(List<Order> orders) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.delivery_dining,
              size: 80,
              color: AppColors.darkText.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No Orders',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Assigned orders will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.darkText.withOpacity(0.4),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text('Order #${order.id}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.customerName),
                Text('Ksh ${order.totalAmount}'),
              ],
            ),
            trailing: order.status == OrderStatus.outForDelivery // UPDATED: Use outForDelivery
                ? IconButton(
                    icon: const Icon(Icons.check_circle, color: AppColors.success),
                    onPressed: () {
                      Provider.of<OrderProvider>(context, listen: false)
                          .updateStatus(order.id, OrderStatus.delivered);
                    },
                  )
                : Icon(
                    Icons.check_circle,
                    color: order.status == OrderStatus.delivered
                        ? AppColors.success
                        : Colors.grey,
                  ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrderProvider>();
    final auth = context.watch<AuthService>();
    final riderId = auth.currentUser?.id ?? '';

    // Get orders for this rider
    final allOrders = provider.orders.where((o) => o.riderId == riderId).toList();
    final activeOrders = allOrders.where((o) => o.status == OrderStatus.outForDelivery).toList(); // UPDATED
    final completedOrders = allOrders.where((o) => o.status == OrderStatus.delivered).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: Column(
        children: [
          // Stats header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              border: Border(
                bottom: BorderSide(color: AppColors.primary.withOpacity(0.1)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Total', allOrders.length.toString(), Icons.receipt, AppColors.primary),
                _buildStatItem('Active', activeOrders.length.toString(), Icons.pending_actions, Colors.orange),
                _buildStatItem('Completed', completedOrders.length.toString(), Icons.check_circle, AppColors.success),
              ],
            ),
          ),
          
          Expanded(
            child: allOrders.isEmpty 
                ? _buildOrderList(allOrders)
                : DefaultTabController(
                    length: 3,
                    child: Column(
                      children: [
                        TabBar(
                          labelColor: AppColors.primary,
                          unselectedLabelColor: AppColors.darkText.withOpacity(0.6),
                          indicatorColor: AppColors.primary,
                          tabs: const [
                            Tab(text: 'All'),
                            Tab(text: 'Active'),
                            Tab(text: 'Completed'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildOrderList(allOrders),
                              _buildOrderList(activeOrders),
                              _buildOrderList(completedOrders),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
