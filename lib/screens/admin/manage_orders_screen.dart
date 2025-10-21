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
          _buildStatItem('Revenue', 'Ksh ${totalRevenue.toStringAsFixed(0)}', Icons.attach_money, AppColors.success),
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
    final provider = Provider.of<OrderProvider>(context, listen: false);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ScaleTransition(
        scale: Tween<double>(begin: widget.highlighted ? 1.04 : 1.0, end: 1.0)
            .animate(CurvedAnimation(
                parent: _controller, curve: Curves.easeInOut)),
        child: FadeTransition(
          opacity: widget.highlighted ? _opacity : AlwaysStoppedAnimation(1.0),
          child: Card(
            elevation: widget.highlighted ? 6 : 2,
            shape: RoundedRectangleBorder(
              side: widget.highlighted
                  ? BorderSide(color: AppColors.accent, width: 2)
                  : BorderSide.none,
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              leading: CircleAvatar(
                backgroundColor: widget.highlighted
                    ? AppColors.primary
                    : AppColors.accent,
                child: Text(widget.order.customerName[0]),
              ),
              title: Text(widget.order.id,
                  style: TextStyle(
                    fontWeight: widget.highlighted
                        ? FontWeight.bold
                        : FontWeight.w600,
                    color: AppColors.darkText,
                  )),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Text(
                    widget.order.items.map((e) => e.title).join(', '),
                    style: TextStyle(
                        color: AppColors.darkText.withAlpha((0.8 * 255).round())),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${widget.order.date.hour.toString().padLeft(2, '0')}:${widget.order.date.minute.toString().padLeft(2, '0')} • Ksh ${widget.order.totalAmount}',
                    style: TextStyle(color: AppColors.lightGray),
                  ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.open_in_new),
                onPressed: () =>
                    _openDetails(context, widget.order, provider),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openDetails(BuildContext context, Order order, OrderProvider provider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Order ${order.id}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${order.customerName}'),
            const SizedBox(height: 8),
            Text('Items: ${order.items.map((e) => '${e.title} x${e.quantity}').join(', ')}'),
            const SizedBox(height: 8),
            Text('Amount: Ksh ${order.totalAmount}'),
            const SizedBox(height: 8),
            Text('Status: ${order.status.toString().split('.').last}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
          if (order.status != OrderStatus.delivered &&
              order.status != OrderStatus.cancelled)
            TextButton(
              onPressed: () {
                provider.updateStatus(order.id, OrderStatus.delivered);
                Navigator.of(context).pop();
              },
              child: const Text('Mark Delivered'),
            ),
          if (order.status != OrderStatus.cancelled)
            TextButton(
              onPressed: () {
                provider.cancelOrder(order.id);
                Navigator.of(context).pop();
              },
              child: const Text('Cancel Order',
                  style: TextStyle(color: Colors.red)),
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
    case OrderStatus.inProcess:
      return Colors.purple;
    case OrderStatus.delivered:
      return AppColors.success;
    case OrderStatus.cancelled:
      return Colors.red;
  }
}
