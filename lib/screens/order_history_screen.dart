// lib/screens/order_history_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../models/order.dart';
import '../models/cart_item.dart';
import '../providers/order_provider.dart';
import '../providers/cart_provider.dart';

class OrderHistoryScreen extends StatefulWidget {
  // optional: pass the current customerId to show only their orders
  final String? customerId;

  const OrderHistoryScreen({super.key, this.customerId});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Orders already loaded at login, no need to reload here
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _reorderItems(Order order) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    cartProvider.clear();

    for (final item in order.items) {
      cartProvider.addItem(CartItem(
        id: item.id,
        menuItemId: item.menuItemId ?? item.id, // Use menuItemId or fallback to item.id
        mealTitle: item.title,
        price: item.price,
        quantity: item.quantity,
        mealImage: '',
      ));
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text('${order.items.length} items added to cart'),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );

    Navigator.popUntil(context, (route) => route.isFirst);
  }

  Widget _buildOrderStats(OrderProvider provider) {
    final orders = widget.customerId != null 
        ? provider.ordersForCustomer(widget.customerId!)
        : provider.orders;
    final totalOrders = orders.length;
    final completedOrders = orders.where((o) => o.status == OrderStatus.delivered).length;
    final totalSpent = orders.fold<double>(0, (sum, order) => sum + order.totalAmount.toDouble());

    return Container(
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
          _buildStatItem('Total Orders', totalOrders.toString(), Icons.receipt),
          _buildStatItem('Completed', completedOrders.toString(), Icons.check_circle),
          _buildStatItem('Total Spent', 'Ksh ${totalSpent.toStringAsFixed(0)}', Icons.attach_money),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
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

  // SIMPLIFIED: Order card with only essential information
  Widget _buildOrderCard(Order order) {
    final deliveryFee = order.deliveryType == DeliveryType.delivery ? 100 : 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor(order.status),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getStatusIcon(order.status),
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _getStatusText(order.status),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            // Order date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Order Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _formatDate(order.date),
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.darkText.withOpacity(0.6),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Items with quantities and subtotals
            ...order.items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${item.quantity}x ${item.title}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  Text(
                    'KES ${item.price * item.quantity}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )),
            
            const Divider(height: 24),
            
            // Delivery fee (if applicable)
            if (order.deliveryType == DeliveryType.delivery) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Delivery Fee',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.darkText.withOpacity(0.7),
                    ),
                  ),
                  Text(
                    'KES $deliveryFee',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.darkText.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            
            // Grand total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'KES ${order.totalAmount}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            
            // Delivery address (if delivery)
            if (order.deliveryType == DeliveryType.delivery && order.deliveryAddress != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.deliveryAddress?['address']?.toString() ?? 
                        'Pickup', // FIXED: Extract address from Map
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // UPDATED: Action buttons (Reorder only for delivered orders)
            if (order.status == OrderStatus.delivered) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _reorderItems(order),
                  icon: const Icon(Icons.replay, size: 18),
                  label: const Text('Reorder'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final orderDay = DateTime(date.year, date.month, date.day);

    if (orderDay == today) {
      return 'Today at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (orderDay == today.subtract(const Duration(days: 1))) {
      return 'Yesterday at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  IconData _getStatusIcon(OrderStatus status) {
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

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.preparing: // UPDATED
        return Colors.purple;
      case OrderStatus.outForDelivery: // ADDED
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
      case OrderStatus.preparing: // UPDATED
        return 'Preparing';
      case OrderStatus.outForDelivery: // ADDED
        return 'Out for Delivery';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);
    
    final orders = widget.customerId != null 
        ? provider.ordersForCustomer(widget.customerId!)
        : provider.orders;
    final activeOrders = orders.where((o) => 
        o.status != OrderStatus.delivered && o.status != OrderStatus.cancelled).toList();
    final pastOrders = orders.where((o) => 
        o.status == OrderStatus.delivered || o.status == OrderStatus.cancelled).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Order History"),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.white.withOpacity(0.7),
          indicatorColor: AppColors.white,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Active'),
            Tab(text: 'Past'),
          ],
        ),
      ),
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ADDED: Error/Offline Banner
          if (provider.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: provider.error!.contains('cached') || provider.error!.contains('Limited')
                    ? Colors.orange.shade50
                    : Colors.red.shade50,
                border: Border(
                  bottom: BorderSide(
                    color: provider.error!.contains('cached') || provider.error!.contains('Limited')
                        ? Colors.orange.shade300
                        : Colors.red.shade300,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    provider.error!.contains('cached') || provider.error!.contains('Limited')
                        ? Icons.wifi_off
                        : Icons.error_outline,
                    color: provider.error!.contains('cached') || provider.error!.contains('Limited')
                        ? Colors.orange.shade700
                        : Colors.red.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      provider.error!,
                      style: TextStyle(
                        color: provider.error!.contains('cached') || provider.error!.contains('Limited')
                            ? Colors.orange.shade900
                            : Colors.red.shade900,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          _buildOrderStats(provider),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOrderList(orders),
                _buildOrderList(activeOrders),
                _buildOrderList(pastOrders),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList(List<Order> orders) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
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
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) => _buildOrderCard(orders[index]), // FIXED: Removed extra 'context'
    );
  }
}
