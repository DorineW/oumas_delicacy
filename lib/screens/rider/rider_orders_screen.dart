import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/order.dart'; // CHANGED: Use Order model instead of DeliveryOrder
import '../../providers/order_provider.dart'; // CHANGED: Use OrderProvider instead of RiderProvider
import '../../services/auth_service.dart';

class RiderOrdersScreen extends StatefulWidget {
  const RiderOrdersScreen({super.key});

  @override
  State<RiderOrdersScreen> createState() => _RiderOrdersScreenState();
}

class _RiderOrdersScreenState extends State<RiderOrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

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

  // CHANGED: Update to work with Order model
  List<Order> _getFilteredOrders(List<Order> orders) {
    if (_searchQuery.isEmpty) return orders;
    
    return orders.where((order) {
      return order.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          order.customerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (order.deliveryAddress?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          order.items.any((item) => item.title.toLowerCase().contains(_searchQuery.toLowerCase()));
    }).toList();
  }

  // CHANGED: Use OrderProvider
  Widget _buildStatsHeader(OrderProvider provider, String riderId) {
    final orders = provider.ordersForRider(riderId);
    final assignedCount = orders.where((o) => o.status == OrderStatus.assigned).length;
    final pickedUpCount = orders.where((o) => o.status == OrderStatus.pickedUp).length;
    final onRouteCount = orders.where((o) => o.status == OrderStatus.onRoute).length;
    final todayOrders = orders.where((o) {
      final now = DateTime.now();
      return o.date.year == now.year && o.date.month == now.month && o.date.day == now.day;
    }).length;

    // FIXED: Make responsive and prevent overflow
    return Container(
      padding: const EdgeInsets.all(12), // Reduced padding
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        border: Border(
          bottom: BorderSide(color: AppColors.primary.withOpacity(0.1)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem('Total', orders.length.toString(), Icons.receipt, AppColors.primary),
            const SizedBox(width: 8), // Reduced spacing
            _buildStatItem('Assigned', assignedCount.toString(), Icons.assignment, Colors.orange),
            const SizedBox(width: 8),
            _buildStatItem('Active', (pickedUpCount + onRouteCount).toString(), Icons.directions_bike, Colors.blue),
            const SizedBox(width: 8),
            _buildStatItem('Today', todayOrders.toString(), Icons.today, Colors.purple),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      constraints: const BoxConstraints(minWidth: 70), // ADDED: Minimum width
      child: Column(
        mainAxisSize: MainAxisSize.min, // ADDED: Minimize size
        children: [
          Container(
            padding: const EdgeInsets.all(6), // Reduced padding
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color), // Reduced icon size
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14, // Reduced font size
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10, // Reduced font size
              color: AppColors.darkText.withOpacity(0.6),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList(List<Order> orders) {
    final filteredOrders = _getFilteredOrders(orders);
    
    if (filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.list_alt,
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
            const SizedBox(height: 8),
            Text(
              _searchQuery.isEmpty 
                ? 'No orders in this category'
                : 'Try adjusting your search',
              style: TextStyle(
                color: AppColors.darkText.withOpacity(0.4),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: filteredOrders.length,
      itemBuilder: (context, index) {
        final order = filteredOrders[index];
        return _RiderOrderCard(order: order);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // CHANGED: Use OrderProvider
    final provider = Provider.of<OrderProvider>(context);
    final auth = Provider.of<AuthService>(context, listen: false);
    final riderId = auth.currentUser?.id ?? 'rider_1';
    
    // FIXED: Use correct methods for filtering
    final allOrders = provider.ordersForRider(riderId);
    final activeOrders = provider.activeOrdersForRider(riderId);
    final completedOrders = provider.completedOrdersForRider(riderId);
    final todayOrders = allOrders.where((o) {
      final now = DateTime.now();
      return o.date.year == now.year && o.date.month == now.month && o.date.day == now.day;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Orders'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => setState(() {}),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.white.withOpacity(0.7),
          indicatorColor: AppColors.white,
          isScrollable: true,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
            Tab(text: 'Today'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildStatsHeader(provider, riderId),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search orders...',
                hintStyle: const TextStyle(fontSize: 14),
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                isDense: true,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOrderList(allOrders),
                _buildOrderList(activeOrders),
                _buildOrderList(completedOrders),
                _buildOrderList(todayOrders),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// CHANGED: Use Order model
class _RiderOrderCard extends StatelessWidget {
  final Order order;

  const _RiderOrderCard({required this.order});

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
      case OrderStatus.confirmed:
      case OrderStatus.inProcess:
        return Colors.orange;
      case OrderStatus.assigned:
        return Colors.orange;
      case OrderStatus.pickedUp:
        return Colors.blue;
      case OrderStatus.onRoute:
        return Colors.purple;
      case OrderStatus.delivered:
        return AppColors.success;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.inProcess:
        return 'In Process';
      case OrderStatus.assigned:
        return 'Assigned';
      case OrderStatus.pickedUp:
        return 'Picked Up';
      case OrderStatus.onRoute:
        return 'On Route';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
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

  void _openOrderDetails(BuildContext context, Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RiderOrderDetailsSheet(order: order),
    );
  }

  @override
  Widget build(BuildContext context) {
    // CHANGED: Use OrderProvider
    final provider = Provider.of<OrderProvider>(context, listen: false);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _openOrderDetails(context, order),
        borderRadius: BorderRadius.circular(12),
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
                _formatDate(order.date),
                style: TextStyle(
                  color: AppColors.darkText.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              if (order.deliveryAddress != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: AppColors.darkText.withOpacity(0.6),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        order.deliveryAddress!,
                        style: TextStyle(
                          color: AppColors.darkText.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
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
                  if (order.status == OrderStatus.assigned)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _updateOrderStatus(context, order, OrderStatus.pickedUp, provider),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Mark Picked Up'),
                      ),
                    ),
                  if (order.status == OrderStatus.pickedUp)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _updateOrderStatus(context, order, OrderStatus.onRoute, provider),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Start Delivery'),
                      ),
                    ),
                  if (order.status == OrderStatus.onRoute)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _updateOrderStatus(context, order, OrderStatus.delivered, provider),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Mark Delivered'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // CHANGED: Use OrderProvider
  void _updateOrderStatus(BuildContext context, Order order, OrderStatus newStatus, OrderProvider provider) {
    provider.updateStatus(order.id, newStatus);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Order #${order.id} status updated to ${_getStatusText(newStatus)}'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  // ...existing methods (Color _getStatusColor, String _getStatusText, String _formatDate, void _openOrderDetails)...
}

// CHANGED: Use Order model
class _RiderOrderDetailsSheet extends StatelessWidget {
  final Order order;

  const _RiderOrderDetailsSheet({required this.order});

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
      case OrderStatus.confirmed:
      case OrderStatus.inProcess:
        return Colors.orange;
      case OrderStatus.assigned:
        return Colors.orange;
      case OrderStatus.pickedUp:
        return Colors.blue;
      case OrderStatus.onRoute:
        return Colors.purple;
      case OrderStatus.delivered:
        return AppColors.success;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.inProcess:
        return 'In Process';
      case OrderStatus.assigned:
        return 'Assigned';
      case OrderStatus.pickedUp:
        return 'Picked Up';
      case OrderStatus.onRoute:
        return 'On Route';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
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

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.darkText.withOpacity(0.7),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.darkText,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // CHANGED: Use OrderProvider
    final provider = Provider.of<OrderProvider>(context, listen: false);

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${order.id}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
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
            const SizedBox(height: 16),
            Text(
              'Customer: ${order.customerName}',
              style: TextStyle(
                color: AppColors.darkText.withOpacity(0.8),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            if (order.deliveryAddress != null)
              Text(
                'Address: ${order.deliveryAddress}',
                style: TextStyle(
                  color: AppColors.darkText.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            const SizedBox(height: 8),
            _buildDetailRow('Order Time', _formatDate(order.date)),
            _buildDetailRow('Items', '${order.items.length}'),
            _buildDetailRow('Total Amount', 'KES ${order.totalAmount}'),
            const SizedBox(height: 16),
            Text(
              'Items Details',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            ...order.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${item.title} x${item.quantity}',
                        style: TextStyle(
                          color: AppColors.darkText.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      'KES ${item.price * item.quantity}',
                      style: TextStyle(
                        color: AppColors.darkText.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: () {
                    // TODO: Implement chat feature
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Chat with Customer'),
                ),
                ElevatedButton(
                  onPressed: () => _updateOrderStatus(context, order, OrderStatus.delivered, provider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Mark as Delivered'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // CHANGED: Use OrderProvider
  void _updateOrderStatus(BuildContext context, Order order, OrderStatus newStatus, OrderProvider provider) {
    provider.updateStatus(order.id, newStatus);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Order #${order.id} status updated to ${_getStatusText(newStatus)}'),
        backgroundColor: AppColors.success,
      ),
    );
  }
}
