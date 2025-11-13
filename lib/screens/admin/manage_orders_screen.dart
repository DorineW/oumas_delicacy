// lib/screens/admin/manage_orders_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/colors.dart';
import '../../models/order.dart';
import '../../providers/order_provider.dart';

// ADDED: OrderSort enum
enum OrderSort {
  newestFirst,
  oldestFirst,
  highestAmount,
  lowestAmount,
}

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

  // FIXED: Initialize with ALL statuses selected by default
  Set<OrderStatus> _selectedStatuses = Set.from(OrderStatus.values);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);

    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToHighlightedOrder();
      // ADDED: Mark all pending orders as viewed
      _markPendingOrdersAsViewed();
    });
  }

  // ADDED: Mark pending orders as viewed (resets notification count)
  void _markPendingOrdersAsViewed() {
    final provider = context.read<OrderProvider>();
    provider.markPendingOrdersAsViewed();
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

    // FIXED: Add return statement
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

    return filtered; // ADDED: Missing return statement
  }

  // ADDED: Missing _getSortText method (only define once)
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
                onPressed: () {
                  setDialogState(() {
                    _selectedStatuses.clear();
                  });
                },
                child: const Text('Clear All'),
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
        
        final pendingOrders = filteredOrders.where((o) => o.status == OrderStatus.pending).toList();
        final confirmedOrders = filteredOrders.where((o) => o.status == OrderStatus.confirmed).toList();
        final preparingOrders = filteredOrders.where((o) => o.status == OrderStatus.preparing).toList();
        final outForDeliveryOrders = filteredOrders.where((o) => o.status == OrderStatus.outForDelivery).toList();
        final deliveredOrders = filteredOrders.where((o) => o.status == OrderStatus.delivered).toList();
        final cancelledOrders = filteredOrders.where((o) => o.status == OrderStatus.cancelled).toList();

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
              isScrollable: true,
              tabs: const [
                Tab(text: 'Pending'),
                Tab(text: 'Confirmed'),
                Tab(text: 'Preparing'),
                Tab(text: 'Out for Delivery'),
                Tab(text: 'Delivered'),
                Tab(text: 'Cancelled'),
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
                    _buildOrderList(pendingOrders),
                    _buildOrderList(confirmedOrders),
                    _buildOrderList(preparingOrders),
                    _buildOrderList(outForDeliveryOrders),
                    _buildOrderList(deliveredOrders),
                    _buildOrderList(cancelledOrders),
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

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
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

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
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
  Timer? _refreshTimer; // ADDED: Timer to refresh cancellation time

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

    // ADDED: Start refresh timer for pending orders to update cancellation time
    if (widget.order.status == OrderStatus.pending && widget.order.canCancel) {
      _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
        if (mounted) {
          setState(() {}); // Refresh to update cancellation time
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _refreshTimer?.cancel(); // ADDED: Cancel refresh timer
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
                ? const BorderSide(color: AppColors.accent, width: 2)
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
                            Text(
                              widget.order.id,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
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
                  
                  // ADDED: Cancellation timer warning for pending orders
                  if (widget.order.status == OrderStatus.pending && widget.order.canCancel) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.timer, size: 16, color: Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Auto-confirms in ${widget.order.cancellationTimeRemaining} min',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Customer can still cancel',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 8),
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
              // ADDED: Show pending status warning for admin
              if (widget.order.status == OrderStatus.pending && widget.order.canCancel) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.hourglass_bottom, size: 20, color: Colors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pending Confirmation',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'This order will auto-confirm in ${widget.order.cancellationTimeRemaining} minutes if not cancelled by customer.',
                              style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              // ADDED: Show cancellation reason if cancelled
              if (widget.order.status == OrderStatus.cancelled && 
                  widget.order.cancellationReason != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.cancel, size: 20, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Cancellation Reason:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.order.cancellationReason!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
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
                  _buildDetailRow('Address', 
                    widget.order.deliveryAddress!['address']?.toString() ?? 'N/A'), // FIXED: Extract address
                if (widget.order.deliveryPhone != null)
                  _buildDetailRow('Phone', widget.order.deliveryPhone!),
                if (widget.order.riderId != null)
                  _buildDetailRow('Rider', widget.order.riderName ?? 'Unknown'),
              ],
            ],
          ),
        ),
        actions: [
          // UPDATED: Confirm button for pending orders
          if (widget.order.status == OrderStatus.pending)
            ElevatedButton(
              onPressed: () {
                Provider.of<OrderProvider>(context, listen: false)
                    .updateStatus(widget.order.id, OrderStatus.confirmed);
                Navigator.pop(context);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✓ Order confirmed'),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm Order'),
            ),

          // ADDED: Start Preparing button for confirmed orders
          if (widget.order.status == OrderStatus.confirmed)
            ElevatedButton(
              onPressed: () {
                Provider.of<OrderProvider>(context, listen: false)
                    .updateStatus(widget.order.id, OrderStatus.preparing);
                Navigator.pop(context);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✓ Kitchen started preparing order'),
                    backgroundColor: Colors.purple,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Start Preparing'),
            ),

          // UPDATED: Assign Rider button for preparing orders
          if (widget.order.status == OrderStatus.preparing)
            ElevatedButton(
              onPressed: () {
                // Close this dialog first
                Navigator.pop(context);
                
                // Use Navigator.context to get the screen's context (not dialog's)
                // This context remains mounted after dialog closes
                final navigatorContext = Navigator.of(context, rootNavigator: true).context;
                
                // Show rider assignment dialog using the screen context
                _assignRiderDialog(navigatorContext, widget.order);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
              child: const Text('Assign Rider'),
            ),

          // UPDATED: Mark Delivered for orders out for delivery
          if (widget.order.status == OrderStatus.outForDelivery)
            ElevatedButton(
              onPressed: () {
                Provider.of<OrderProvider>(context, listen: false)
                    .updateStatus(widget.order.id, OrderStatus.delivered);
                Navigator.pop(context);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✓ Order marked as delivered'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
              child: const Text('Mark Delivered'),
            ),

          // Cancel with reason for non-cancelled/non-delivered orders
          if (widget.order.status != OrderStatus.cancelled &&
              widget.order.status != OrderStatus.delivered)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showCancellationDialog(context, widget.order);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Cancel Order'),
            ),
          
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Fetch real riders from database with their current status
  Future<void> _assignRiderDialog(BuildContext context, Order order) async {
    debugPrint('🚀 _assignRiderDialog called for order ${order.id}');
    
    // Get provider BEFORE showing dialog
    final provider = Provider.of<OrderProvider>(context, listen: false);
    
    // Fetch riders from Supabase riders table
    List<Map<String, dynamic>> riders = [];
    String? errorMessage;
    
    try {
      debugPrint('📡 Fetching riders from Supabase riders table...');
      final supabase = Supabase.instance.client;
      
      // Fetch riders from riders table
      final response = await supabase
          .from('riders')
          .select('id, auth_id, name, phone, vehicle, is_available')
          .eq('is_available', true)
          .order('name');
      
      debugPrint('📊 Found ${response.length} available riders in riders table');
      
      riders = List<Map<String, dynamic>>.from(response);
      
      // Get rider statuses (check if they have active deliveries)
      for (var rider in riders) {
        final activeDeliveries = provider.orders.where((o) => 
          o.riderId == rider['auth_id'] && 
          o.status == OrderStatus.outForDelivery
        ).length;
        
        rider['active_deliveries'] = activeDeliveries;
        
        debugPrint('   👤 ${rider['name']}: $activeDeliveries active deliveries (${rider['vehicle'] ?? 'N/A'})');
      }
      
      debugPrint('✅ Total riders fetched: ${riders.length}');
    } catch (e) {
      debugPrint('❌ Error fetching riders: $e');
      errorMessage = e.toString();
    }
    
    // Check context TWICE - once before showing dialog, once in the check
    if (!context.mounted) {
      debugPrint('⚠️ Context not mounted after fetching, cannot show dialog');
      return;
    }
    
    debugPrint('✅ Context is mounted, showing dialog...');

    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Assign Rider'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Order info
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Assign delivery for order #${order.orderNumber}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Loading or error state
                if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 8),
                        Text('Error: $errorMessage', 
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  )
                else if (riders.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.people_outline, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('No riders available', 
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                else
                  // Rider list
                  ...riders.map((rider) {
                    final activeDeliveries = rider['active_deliveries'] as int;
                    final isAvailable = activeDeliveries == 0;
                    final vehicle = rider['vehicle'] as String?;
                    final phone = rider['phone'] as String?;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isAvailable 
                              ? AppColors.success.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            vehicle?.toLowerCase().contains('bike') ?? false
                              ? Icons.pedal_bike
                              : Icons.delivery_dining, 
                            color: isAvailable ? AppColors.success : Colors.orange,
                          ),
                        ),
                        title: Text(
                          rider['name'] ?? 'Unknown Rider',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (vehicle != null)
                              Text('🚗 $vehicle', style: const TextStyle(fontSize: 12)),
                            if (phone != null)
                              Text('📞 $phone', style: const TextStyle(fontSize: 12)),
                            Text(
                              isAvailable 
                                ? '✅ Available now' 
                                : '⏱️ Delivering $activeDeliveries order${activeDeliveries > 1 ? 's' : ''}',
                              style: TextStyle(
                                color: isAvailable ? AppColors.success : Colors.orange,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        trailing: Icon(
                          isAvailable ? Icons.check_circle : Icons.access_time,
                          color: isAvailable ? AppColors.success : Colors.orange,
                          size: 20,
                        ),
                        onTap: () => Navigator.pop(dialogContext, rider),
                      ),
                    );
                  }),
                
                const Divider(),
                
                // In-house delivery option
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.admin_panel_settings, color: AppColors.primary),
                  ),
                  title: const Text('In-House Delivery'),
                  subtitle: const Text('Admin will handle delivery'),
                  onTap: () => Navigator.pop(dialogContext, {
                    'auth_id': 'admin', 
                    'name': 'In-House',
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );

    debugPrint('🔍 Dialog result: $selected');

    if (!mounted) {
      debugPrint('⚠️ Widget not mounted after dialog');
      return;
    }
    if (selected == null) {
      debugPrint('❌ Dialog cancelled or no selection made');
      return;
    }
    
    // Use provider that was captured BEFORE dialog
    final riderId = selected['auth_id'] as String;
    final riderName = selected['name'] as String;
    
    debugPrint('🔔 Assigning order ${order.id} to rider $riderId ($riderName)');
    await provider.assignToRider(order.id, riderId, riderName);
    debugPrint('✅ Rider assignment initiated');
    
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                riderId == 'admin'
                    ? 'Order assigned to In-House delivery'
                    : 'Order assigned to $riderName',
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
  }

  // ADDED: Cancellation reason dialog
  void _showCancellationDialog(BuildContext context, Order order) {
    String? selectedReason;
    final TextEditingController customController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cancel, color: Colors.red, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Cancel Order',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info, size: 16, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Order ${order.id}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select cancellation reason:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Reason options
                  ...[
                    'Customer Requested',
                    'Out of Stock',
                    'Restaurant Busy',
                    'Delivery Area Issue',
                    'Payment Problem',
                    'Other',
                  ].map((reason) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: selectedReason == reason 
                          ? AppColors.primary.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selectedReason == reason
                            ? AppColors.primary
                            : AppColors.lightGray.withOpacity(0.3),
                      ),
                    ),
                    child: RadioListTile<String>(
                      title: Text(
                        reason,
                        style: TextStyle(
                          fontSize: 13,
                          color: selectedReason == reason
                              ? AppColors.primary
                              : AppColors.darkText,
                          fontWeight: selectedReason == reason
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      value: reason,
                      groupValue: selectedReason,
                      activeColor: AppColors.primary,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      onChanged: (value) => setDialogState(() => selectedReason = value),
                    ),
                  )),
                  
                  // Custom reason input
                  if (selectedReason == 'Other') ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: customController,
                      decoration: InputDecoration(
                        labelText: 'Please specify reason',
                        hintText: 'Enter custom reason...',
                        prefixIcon: const Icon(Icons.edit, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  customController.dispose();
                  Navigator.pop(context);
                },
                child: const Text('Back'),
              ),
              ElevatedButton(
                onPressed: selectedReason == null ? null : () {
                  String reason = selectedReason!;
                  
                  // Use custom reason if "Other" is selected
                  if (selectedReason == 'Other') {
                    final custom = customController.text.trim();
                    if (custom.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please specify a custom reason'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    reason = custom;
                  }
                  
                  // Cancel the order with reason
                  Provider.of<OrderProvider>(context, listen: false)
                      .cancelOrder(order.id, reason);
                  
                  customController.dispose();
                  Navigator.pop(context);
                  
                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text('Order ${order.id} cancelled: $reason'),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Confirm Cancellation'),
              ),
            ],
          );
        },
      ),
    ).then((_) => customController.dispose());
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

  // ADDED: Missing helper methods
  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
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
      case OrderStatus.pending:
        return 'Pending';
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
}
