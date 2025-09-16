// lib/screens/order_history_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../models/order.dart';
import '../providers/order_provider.dart';

class OrderHistoryScreen extends StatelessWidget {
  // optional: pass the current customerId to show only their orders
  final String? customerId;

  const OrderHistoryScreen({Key? key, this.customerId}) : super(key: key);

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')}";
  }

  Widget _statusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
      case OrderStatus.confirmed:
        return const Icon(Icons.check_circle_outline, color: Colors.orange, size: 28);
      case OrderStatus.inProcess:
        return const Icon(Icons.local_shipping, color: Colors.blue, size: 28);
      case OrderStatus.delivered:
        return const Icon(Icons.done_all, color: Colors.green, size: 28);
      case OrderStatus.cancelled:
        return const Icon(Icons.cancel, color: Colors.red, size: 28);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);
    // seed demo if empty (optional)
    provider.seedDemo(customerId: customerId);

    final orders = customerId == null ? provider.orders : provider.ordersForCustomer(customerId!);

    final confirmed = orders.where((o) => o.status == OrderStatus.confirmed).toList();
    final inProcess = orders.where((o) => o.status == OrderStatus.inProcess).toList();
    final delivered = orders.where((o) => o.status == OrderStatus.delivered).toList();
    final cancelled = orders.where((o) => o.status == OrderStatus.cancelled).toList();
    final pending = orders.where((o) => o.status == OrderStatus.pending).toList();

    final sections = <Map<String, List<Order>>>[
      if (pending.isNotEmpty) {'Pending': pending},
      if (confirmed.isNotEmpty) {'Confirmed': confirmed},
      if (inProcess.isNotEmpty) {'In Process': inProcess},
      if (delivered.isNotEmpty) {'Delivered': delivered},
      if (cancelled.isNotEmpty) {'Cancelled': cancelled},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Order History"),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: orders.isEmpty
            ? const Center(child: Text("No orders found.", style: TextStyle(fontSize: 18, color: Colors.grey)))
            : ListView(
                children: sections.expand((section) {
                  final title = section.keys.first;
                  final list = section.values.first;
                  return [
                    Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    const SizedBox(height: 8),
                    ...list.map((order) => _orderCard(context, order)).toList(),
                    const SizedBox(height: 18),
                  ];
                }).toList(),
              ),
      ),
    );
  }

  Widget _orderCard(BuildContext context, Order order) {
    final provider = Provider.of<OrderProvider>(context, listen: false);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.receipt_long, color: AppColors.primary, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Order #${order.id}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 4),
                Text("Date: ${_formatDate(order.date)}\nTotal: Ksh ${order.totalAmount}", style: const TextStyle(fontSize: 14)),
              ]),
            ),
            _statusIcon(order.status),
          ]),
          const SizedBox(height: 10),
          if (order.status == OrderStatus.pending || order.status == OrderStatus.confirmed || order.status == OrderStatus.inProcess)
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => _confirmCancel(context, order, provider),
                icon: const Icon(Icons.cancel, size: 18),
                label: const Text("Cancel Order"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  void _confirmCancel(BuildContext context, Order order, OrderProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Order"),
        content: Text("Are you sure you want to cancel order #${order.id}?"),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("No")),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              provider.cancelOrder(order.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Order #${order.id} cancelled."), backgroundColor: Colors.redAccent),
              );
            },
            child: const Text("Yes", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
