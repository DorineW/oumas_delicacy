import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/delivery_order.dart';
import '../../providers/rider_provider.dart';

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

  Widget _buildOrderList(List<DeliveryOrder> orders) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.list_alt,
              size: 60,
              color: AppColors.darkText.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No Orders Found',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.darkText.withOpacity(0.5),
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
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      order.id,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                        fontSize: 16,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                  order.customerName,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  order.deliveryAddress,
                  style: TextStyle(
                    color: AppColors.darkText.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${order.items.length} items',
                      style: TextStyle(
                        color: AppColors.darkText.withOpacity(0.6),
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Ksh ${order.amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Ordered: ${_formatTime(order.orderTime)}',
                  style: TextStyle(
                    color: AppColors.darkText.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.assigned:
        return Colors.orange;
      case OrderStatus.pickedUp:
        return Colors.blue;
      case OrderStatus.onRoute:
        return Colors.purple;
      case OrderStatus.delivered:
        return AppColors.success;
    }
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.assigned:
        return 'Assigned';
      case OrderStatus.pickedUp:
        return 'Picked Up';
      case OrderStatus.onRoute:
        return 'On Route';
      case OrderStatus.delivered:
        return 'Delivered';
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RiderProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Orders'),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: AppColors.white),
        titleTextStyle: const TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.white.withOpacity(0.7),
          indicatorColor: AppColors.white,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
            Tab(text: 'Today'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrderList(provider.orders),
          _buildOrderList(provider.activeOrders),
          _buildOrderList(provider.completedOrders),
          _buildOrderList(provider.todayOrders),
        ],
      ),
    );
  }
}
