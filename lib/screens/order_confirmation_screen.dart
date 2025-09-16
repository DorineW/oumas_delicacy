// lib/screens/order_confirmation_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cart_item.dart';
import '../models/order.dart';
import '../providers/order_provider.dart';

class OrderConfirmationScreen extends StatefulWidget {
  final List<CartItem> orderItems;
  final DeliveryType deliveryType;
  final int totalAmount;
  final String customerId;
  final String customerName;

  const OrderConfirmationScreen({
    Key? key,
    required this.orderItems,
    required this.deliveryType,
    required this.totalAmount,
    required this.customerId,
    required this.customerName,
  }) : super(key: key);

  @override
  State<OrderConfirmationScreen> createState() => _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen> {
  bool _addedToProvider = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_addedToProvider) {
      final provider = Provider.of<OrderProvider>(context, listen: false);
      final id = provider.generateOrderId();
      final items = widget.orderItems
          .map((c) => OrderItem(id: c.id, title: c.mealTitle, quantity: c.quantity, price: c.price))
          .toList();

      final order = Order(
        id: id,
        customerId: widget.customerId,
        customerName: widget.customerName,
        date: DateTime.now(),
        items: items,
        totalAmount: widget.totalAmount,
        status: OrderStatus.confirmed,
        deliveryType: widget.deliveryType,
      );

      provider.addOrder(order);
      _addedToProvider = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order Confirmation')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 100),
          const SizedBox(height: 20),
          const Text('Order Placed Successfully!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Text(
            widget.deliveryType == DeliveryType.delivery ? 'Your food will be delivered soon' : 'Your food will be ready for pickup shortly',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 30),
          const Text('Order Details', style: TextStyle(fontWeight: FontWeight.bold)),
          ...widget.orderItems.map((item) => ListTile(
                title: Text('${item.mealTitle} x${item.quantity}'),
                trailing: Text('KES ${item.price * item.quantity}'),
              )),
          const Divider(),
          Text('Total: KES ${widget.totalAmount}', style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
              child: const Text('Back to Home'),
            ),
          ),
        ]),
      ),
    );
  }
}
