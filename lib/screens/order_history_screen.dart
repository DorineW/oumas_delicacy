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
    
    // Seed demo data after the first frame so we don't mutate provider during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<OrderProvider>(context, listen: false);
      provider.seedDemo(customerId: widget.customerId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _canOrderBeCancelled(Order order) {
    if (order.status == OrderStatus.cancelled || 
        order.status == OrderStatus.delivered) {
      return false;
    }

    final timeSinceOrder = DateTime.now().difference(order.date).inMinutes;
    return timeSinceOrder < 5; // 5-minute cancellation window
  }

  void _reorderItems(Order order, BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    cartProvider.clear();

    for (final item in order.items) {
      cartProvider.addItem(CartItem(
        id: item.id,
        mealTitle: item.title,
        price: item.price,
        quantity: item.quantity,
        mealImage: '',
      ));
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${order.items.length} items added to cart'),
        backgroundColor: AppColors.success,
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

  Widget _buildOrderCard(BuildContext context, Order order) {
    final canCancel = _canOrderBeCancelled(order);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      child: InkWell(
        onTap: () => _showOrderDetailsDialog(order),
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
                _formatDate(order.date),
                style: TextStyle(
                  color: AppColors.darkText.withOpacity(0.6),
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
              Text(
                'Ksh ${order.totalAmount}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (canCancel)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _cancelOrder(context, order),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                        child: const Text('Cancel Order'),
                      ),
                    ),
                  if (canCancel) const SizedBox(width: 8),
                  if (order.status == OrderStatus.delivered)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _reorderItems(order, context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Reorder'),
                      ),
                    ),
                  if (order.status == OrderStatus.delivered && 
                      order.items.any((item) => item.rating == null)) ...[
                    if (canCancel) const SizedBox(width: 8),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => _showRatingDialog(order),
                        icon: const Icon(Icons.star, size: 16),
                        label: const Text('Rate'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.amber,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _cancelOrder(BuildContext context, Order order) async {
    final provider = Provider.of<OrderProvider>(context, listen: false);
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order?'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Order'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      provider.updateStatus(order.id, OrderStatus.cancelled);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order #${order.id} has been cancelled'),
          backgroundColor: AppColors.success,
        ),
      );
    }
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

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.assigned: // ADDED
        return Colors.purple;
      case OrderStatus.pickedUp: // ADDED
        return Colors.teal;
      case OrderStatus.onRoute: // ADDED
        return Colors.indigo;
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

  // UPDATED: Show ratings in order details
  void _showOrderDetailsDialog(Order order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Order ${order.id}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Customer', order.customerName),
              _buildDetailRow('Date', _formatDate(order.date)),
              _buildDetailRow('Status', _getStatusText(order.status)),
              _buildDetailRow('Delivery Type', order.deliveryType.toString().split('.').last),
              const Divider(),
              const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...order.items.map((item) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${item.quantity}x ${item.title}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text('Ksh ${item.price * item.quantity}'),
                      ],
                    ),
                    if (item.rating != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          ...List.generate(5, (index) => Icon(
                            index < item.rating! ? Icons.star : Icons.star_border,
                            size: 14,
                            color: Colors.amber,
                          )),
                          const SizedBox(width: 4),
                          Text(
                            '(${item.rating})',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.darkText.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (item.review != null && item.review!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.review!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.darkText.withOpacity(0.7),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              )),
              const Divider(),
              _buildDetailRow('Total', 'Ksh ${order.totalAmount}', isBold: true),
              if (order.deliveryType == DeliveryType.delivery) ...[
                const Divider(),
                if (order.deliveryAddress != null)
                  _buildDetailRow('Address', order.deliveryAddress!),
                if (order.deliveryPhone != null)
                  _buildDetailRow('Phone', order.deliveryPhone!),
              ],
            ],
          ),
        ),
        actions: [
          if (order.status == OrderStatus.delivered && 
              order.items.any((item) => item.rating == null))
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showRatingDialog(order);
              },
              child: const Text('Rate Items'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ADDED: Rating dialog
  void _showRatingDialog(Order order) {
    showDialog(
      context: context,
      builder: (context) => _RatingDialog(order: order),
    );
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
            Tab(text: 'All Orders'),
            Tab(text: 'Active'),
            Tab(text: 'Past Orders'),
          ],
        ),
      ),
      backgroundColor: AppColors.background,
      body: Column(
        children: [
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
              'No Orders Found',
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
      itemBuilder: (context, index) {
        final order = orders[index];
        return _buildOrderCard(context, order);
      },
    );
  }
}

class _RatingDialog extends StatefulWidget {
  final Order order;

  const _RatingDialog({required this.order});

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  final Map<String, int> _ratings = {};
  final Map<String, TextEditingController> _commentControllers = {};

  @override
  void initState() {
    super.initState();
    // Initialize ratings and controllers for each item
    for (var item in widget.order.items) {
      _ratings[item.id] = item.rating ?? 0;
      _commentControllers[item.id] = TextEditingController(text: item.review ?? '');
    }
  }

  @override
  void dispose() {
    for (var controller in _commentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.star, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Rate Your Order',
                style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
      titlePadding: EdgeInsets.zero,
      contentPadding: const EdgeInsets.all(20),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Order #${widget.order.id}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Rate each item separately
              ...widget.order.items.map((item) => _buildItemRating(item)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: AppColors.darkText.withOpacity(0.6)),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: () => _submitRatings(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 6),
                Text('Submit Ratings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemRating(OrderItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.restaurant, size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Star rating
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Wrap(
              spacing: 6,
              children: List.generate(5, (index) {
                final isSelected = index < (_ratings[item.id] ?? 0);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _ratings[item.id] = index + 1;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? Colors.amber.withOpacity(0.2) 
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      isSelected ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 28,
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),
          // Comment field
          TextField(
            controller: _commentControllers[item.id],
            decoration: InputDecoration(
              hintText: 'Share your thoughts... (optional)',
              hintStyle: TextStyle(fontSize: 12, color: AppColors.darkText.withOpacity(0.4)),
              prefixIcon: Icon(Icons.comment, size: 18, color: AppColors.primary.withOpacity(0.6)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.lightGray.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.lightGray.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
              filled: true,
              fillColor: AppColors.background,
            ),
            maxLines: 3,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _submitRatings(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context, listen: false);
    
    // Update each item's rating and review
    for (var item in widget.order.items) {
      final rating = _ratings[item.id] ?? 0;
      final review = _commentControllers[item.id]?.text.trim() ?? '';
      
      if (rating > 0) {
        provider.rateOrderItem(widget.order.id, item.id, rating, review);
      }
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Thank you for your feedback!',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Your ratings help us improve',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
