// lib/screens/admin/manage_orders_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/order.dart';
import '../../providers/order_provider.dart';

class ManageOrdersScreen extends StatefulWidget {
  final String? highlightOrderId;

  const ManageOrdersScreen({super.key, this.highlightOrderId});

  @override
  State<ManageOrdersScreen> createState() => _ManageOrdersScreenState();
}

class _ManageOrdersScreenState extends State<ManageOrdersScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;
  String _searchQuery = '';
  OrderSort _currentSort = OrderSort.newestFirst;
  Timer? _autoRefreshTimer;

  Set<OrderStatus> _selectedStatuses = {
    OrderStatus.pending,
    OrderStatus.confirmed,
    OrderStatus.inProcess,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToHighlightedOrder();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToHighlightedOrder() {
    if (widget.highlightOrderId != null) {
      final provider = context.read<OrderProvider>();
      final index = provider.orders.indexWhere((o) => o.id == widget.highlightOrderId);
      if (index != -1) {
        _scrollController.animateTo(
          index * 200.0,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  List<Order> _getFilteredOrders(List<Order> orders) {
    var filtered = orders.where((order) {
      final matchesSearch = _searchQuery.isEmpty ||
          order.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          order.customerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          order.items.any((item) => item.title.toLowerCase().contains(_searchQuery.toLowerCase()));

      final matchesStatus = _selectedStatuses.contains(order.status);

      return matchesSearch && matchesStatus;
    }).toList();

    filtered.sort((a, b) {
      switch (_currentSort) {
        case OrderSort.newestFirst:
          return b.date.compareTo(a.date);
        case OrderSort.oldestFirst:
          return a.date.compareTo(b.date);
        case OrderSort.highestAmount:
          return b.totalAmount.compareTo(a.totalAmount);
        case OrderSort.lowestAmount:
          return a.totalAmount.compareTo(b.totalAmount);
      }
    });

    return filtered;
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Filter Orders'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Order Status:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: OrderStatus.values.map((status) {
                      final isSelected = _selectedStatuses.contains(status);
                      return FilterChip(
                        label: Text(
                          _getStatusText(status),
                          style: TextStyle(
                            color: isSelected ? Colors.white : _getStatusColor(status),
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          setDialogState(() {
                            if (selected) {
                              _selectedStatuses.add(status);
                            } else {
                              _selectedStatuses.remove(status);
                            }
                          });
                        },
                        backgroundColor: isSelected ? _getStatusColor(status) : null,
                        selectedColor: _getStatusColor(status),
                        checkmarkColor: Colors.white,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Sort By:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButton<OrderSort>(
                    value: _currentSort,
                    isExpanded: true,
                    items: OrderSort.values.map((sort) {
                      return DropdownMenuItem(
                        value: sort,
                        child: Text(_getSortText(sort)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          _currentSort = value;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setDialogState(() {
                    _selectedStatuses = Set.from(OrderStatus.values);
                  });
                },
                child: const Text('Select All'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {});
                  Navigator.of(context).pop();
                },
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsHeader(OrderProvider provider) {
    final orders = provider.orders;
    final pendingCount = orders.where((o) => o.status == OrderStatus.pending).length;
    final todayCount = orders.where((o) => _isToday(o.date)).length;
    // FIXED: Only count delivered orders for revenue
    final totalRevenue = orders.where((o) => o.status == OrderStatus.delivered)
        .fold<double>(0, (sum, order) => sum + order.totalAmount.toDouble());

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
          _buildStatItem('Total', orders.length.toString(), Icons.receipt, AppColors.primary),
          _buildStatItem('Pending', pendingCount.toString(), Icons.pending_actions, Colors.orange),
          _buildStatItem('Today', todayCount.toString(), Icons.today, Colors.blue),
          // FIXED: Changed label from 'Revenue' to 'Delivered'
          _buildStatItem('Delivered', 'Ksh ${totalRevenue.toStringAsFixed(0)}', Icons.check_circle, AppColors.success),
        ],
      ),
    );
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

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderProvider>(
      builder: (context, provider, child) {
        final filteredOrders = _getFilteredOrders(provider.orders);
        
        final allOrders = filteredOrders;
        final activeOrders = filteredOrders.where((o) => 
            o.status != OrderStatus.delivered && o.status != OrderStatus.cancelled).toList();
        final pendingOrders = filteredOrders.where((o) => o.status == OrderStatus.pending).toList();
        final completedOrders = filteredOrders.where((o) => 
            o.status == OrderStatus.delivered || o.status == OrderStatus.cancelled).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Manage Orders'),
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                tooltip: 'Filter & Sort',
                onPressed: () => _showFilterDialog(context),
              ),
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
              tabs: const [
                Tab(text: 'All Orders'),
                Tab(text: 'Active'),
                Tab(text: 'Pending'),
                Tab(text: 'Completed'),
              ],
            ),
          ),
          body: Column(
            children: [
              _buildStatsHeader(provider),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search orders, customers, items...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
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
                    _buildOrderList(pendingOrders),
                    _buildOrderList(completedOrders),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters or search',
              style: TextStyle(
                color: AppColors.darkText.withOpacity(0.4),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final highlighted = widget.highlightOrderId != null &&
            widget.highlightOrderId == order.id;
        return AdminOrderCard(order: order, highlighted: highlighted);
      },
    );
  }
}

class AdminOrderCard extends StatefulWidget {
  final Order order;
  final bool highlighted;
  const AdminOrderCard({super.key, required this.order, this.highlighted = false});

  @override
  State<AdminOrderCard> createState() => _AdminOrderCardState();
}

class _AdminOrderCardState extends State<AdminOrderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.3), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.3, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.highlighted) {
      _controller.repeat(reverse: true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _controller.stop();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: FadeTransition(
        opacity: _opacity,
        child: Card(
          elevation: widget.highlighted ? 4 : 2,
          shape: RoundedRectangleBorder(
            side: widget.highlighted
                ? BorderSide(color: AppColors.accent, width: 2)
                : BorderSide.none,
            borderRadius: BorderRadius.circular(8),
          ),
          child: InkWell(
            onTap: () => _showOrderDetailsDialog(context),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _getStatusColor(widget.order.status),
                        radius: 20,
                        child: Text(
                          widget.order.customerName[0],
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // UPDATED: Show Order ID first, then customer name below
                            Text(
                              widget.order.id,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            // UPDATED: Customer name with icon
                            Row(
                              children: [
                                Icon(
                                  Icons.person,
                                  size: 12,
                                  color: AppColors.darkText.withOpacity(0.6),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    widget.order.customerName,
                                    style: TextStyle(
                                      color: AppColors.darkText.withOpacity(0.7),
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(widget.order.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _getStatusColor(widget.order.status)),
                        ),
                        child: Text(
                          _getStatusText(widget.order.status),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(widget.order.status),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // UPDATED: Items list with better styling
                  Row(
                    children: [
                      Icon(
                        Icons.restaurant_menu,
                        size: 12,
                        color: AppColors.darkText.withOpacity(0.5),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.order.items.map((e) => '${e.title} x${e.quantity}').join(', '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.darkText.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // UPDATED: Show delivery type with icon
                      Row(
                        children: [
                          Icon(
                            widget.order.deliveryType == DeliveryType.delivery 
                                ? Icons.delivery_dining 
                                : Icons.shopping_bag,
                            size: 12,
                            color: AppColors.darkText.withOpacity(0.5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.order.deliveryType.toString().split('.').last} • ${widget.order.date.hour.toString().padLeft(2, '0')}:${widget.order.date.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.darkText.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Ksh ${widget.order.totalAmount}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showOrderDetailsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Order ${widget.order.id}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Customer', widget.order.customerName),
              _buildDetailRow('Date', '${widget.order.date.day}/${widget.order.date.month}/${widget.order.date.year} ${widget.order.date.hour}:${widget.order.date.minute}'),
              _buildDetailRow('Status', _getStatusText(widget.order.status)),
              _buildDetailRow('Delivery Type', widget.order.deliveryType.toString().split('.').last),
              const Divider(),
              const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...widget.order.items.map((item) => 
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('${item.title} x${item.quantity} - Ksh ${item.price}'),
                ),
              ),
              const Divider(),
              _buildDetailRow('Total', 'Ksh ${widget.order.totalAmount}', isBold: true),
              if (widget.order.deliveryType == DeliveryType.delivery) ...[
                const Divider(),
                if (widget.order.deliveryAddress != null)
                  _buildDetailRow('Address', widget.order.deliveryAddress!),
                if (widget.order.deliveryPhone != null)
                  _buildDetailRow('Phone', widget.order.deliveryPhone!),
                if (widget.order.riderId != null)
                  _buildDetailRow('Rider', widget.order.riderName ?? 'Unknown'),
              ],
            ],
          ),
        ),
        actions: [
          // FIXED: Show Confirm button for pending orders
          if (widget.order.status == OrderStatus.pending)
            TextButton(
              onPressed: () {
                Provider.of<OrderProvider>(context, listen: false)
                    .updateStatus(widget.order.id, OrderStatus.confirmed);
                Navigator.pop(context);
              },
              child: const Text('Confirm'),
            ),
          
          // FIXED: Show Assign Rider for confirmed delivery orders
          if (widget.order.status == OrderStatus.confirmed && 
              widget.order.deliveryType == DeliveryType.delivery)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _assignRiderDialog(context, widget.order);
              },
              child: const Text('Assign Rider'),
            ),
          
          // FIXED: Show Mark Delivered for pickup orders that are confirmed
          if (widget.order.status == OrderStatus.confirmed &&
              widget.order.deliveryType == DeliveryType.pickup)
            TextButton(
              onPressed: () {
                Provider.of<OrderProvider>(context, listen: false)
                    .updateStatus(widget.order.id, OrderStatus.delivered);
                Navigator.pop(context);
              },
              child: const Text('Mark Delivered'),
            ),
          
          // Show Mark Delivered for delivery orders in progress
          if (widget.order.status == OrderStatus.assigned ||
              widget.order.status == OrderStatus.pickedUp ||
              widget.order.status == OrderStatus.onRoute)
            TextButton(
              onPressed: () {
                Provider.of<OrderProvider>(context, listen: false)
                    .updateStatus(widget.order.id, OrderStatus.delivered);
                Navigator.pop(context);
              },
              child: const Text('Mark Delivered'),
            ),
          
          // FIXED: Show Cancel for any order that's not already cancelled or delivered
          if (widget.order.status != OrderStatus.cancelled &&
              widget.order.status != OrderStatus.delivered)
            TextButton(
              onPressed: () {
                Provider.of<OrderProvider>(context, listen: false)
                    .updateStatus(widget.order.id, OrderStatus.cancelled);
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Cancel'),
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

  // ADDED: Show assign rider dialog
  Future<void> _assignRiderDialog(BuildContext context, Order order) async {
    final riders = [
      {'id': 'rider_1', 'name': 'John Rider'},
      {'id': 'rider_2', 'name': 'Mary Delivery'},
      {'id': 'rider_3', 'name': 'Bob Transport'},
    ];

    final selected = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign Rider'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...riders.map((rider) => ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delivery_dining, color: AppColors.primary),
              ),
              title: Text(rider['name']!),
              subtitle: const Text('External rider'),
              onTap: () => Navigator.pop(context, rider),
            )),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.admin_panel_settings, color: Colors.orange),
              ),
              title: const Text('In-House Delivery'),
              subtitle: const Text('Admin will handle delivery'),
              onTap: () => Navigator.pop(context, {'id': 'admin', 'name': 'In-House'}),
            ),
          ],
        ),
      ),
    );

    if (selected != null && mounted) {
      final provider = Provider.of<OrderProvider>(context, listen: false);
      
      // FIXED: Properly assign rider and update status
      provider.assignToRider(order.id, selected['id']!, selected['name']!);
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  selected['id'] == 'admin'
                      ? 'Order assigned to In-House delivery'
                      : 'Order assigned to ${selected['name']}',
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      
      // ADDED: If in-house delivery, show admin delivery dialog
      if (selected['id'] == 'admin') {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _showAdminDeliveryDialog(context, order);
          }
        });
      }
    }
  }

  // ADDED: Admin delivery management dialog
  Future<void> _showAdminDeliveryDialog(BuildContext context, Order order) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.admin_panel_settings, color: Colors.orange, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'In-House Delivery',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Order', order.id),
            _buildDetailRow('Customer', order.customerName),
            if (order.deliveryAddress != null)
              _buildDetailRow('Address', order.deliveryAddress!),
            if (order.deliveryPhone != null)
              _buildDetailRow('Phone', order.deliveryPhone!),
            _buildDetailRow('Total', 'Ksh ${order.totalAmount}'),
            const Divider(),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Delivery Actions',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Update order status as you progress with the delivery:',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.darkText.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (order.status == OrderStatus.assigned)
            ElevatedButton.icon(
              onPressed: () {
                Provider.of<OrderProvider>(context, listen: false)
                    .updateStatus(order.id, OrderStatus.pickedUp);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✓ Order marked as picked up'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              icon: const Icon(Icons.shopping_bag_outlined, size: 18),
              label: const Text('Pick Up'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
            ),
          if (order.status == OrderStatus.pickedUp)
            ElevatedButton.icon(
              onPressed: () {
                Provider.of<OrderProvider>(context, listen: false)
                    .updateStatus(order.id, OrderStatus.onRoute);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✓ Order marked as on route'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              icon: const Icon(Icons.local_shipping_outlined, size: 18),
              label: const Text('On Route'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
            ),
          if (order.status == OrderStatus.onRoute || order.status == OrderStatus.pickedUp)
            ElevatedButton.icon(
              onPressed: () {
                Provider.of<OrderProvider>(context, listen: false)
                    .updateStatus(order.id, OrderStatus.delivered);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text('✓ Order delivered successfully!'),
                        ),
                      ],
                    ),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.all(16),
                  ),
                );
              },
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Deliver'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}

enum OrderSort {
  newestFirst,
  oldestFirst,
  highestAmount,
  lowestAmount,
}

String _getSortText(OrderSort sort) {
  switch (sort) {
    case OrderSort.newestFirst:
      return 'Newest First';
    case OrderSort.oldestFirst:
      return 'Oldest First';
    case OrderSort.highestAmount:
      return 'Highest Amount';
    case OrderSort.lowestAmount:
      return 'Lowest Amount';
  }
}

String _getStatusText(OrderStatus status) {
  return status.toString().split('.').last;
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
