// lib/screens/admin/manage_orders_screen.dart
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

class _ManageOrdersScreenState extends State<ManageOrdersScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.highlightOrderId != null) {
        final provider = Provider.of<OrderProvider>(context, listen: false);
        final index =
            provider.orders.indexWhere((o) => o.id == widget.highlightOrderId);
        if (index != -1) {
          _scrollController.animateTo(
            index * 100.0, // rough card height
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);
    provider.seedDemo(); // demo data

    final orders = provider.orders;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Orders'),
        backgroundColor: AppColors.primary,
      ),
      body: orders.isEmpty
          ? const Center(child: Text('No orders found'))
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final o = orders[index];
                final highlighted = widget.highlightOrderId != null &&
                    widget.highlightOrderId == o.id;
                return AdminOrderCard(order: o, highlighted: highlighted);
              },
            ),
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
