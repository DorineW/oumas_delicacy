// lib/screens/order_confirmation_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../models/cart_item.dart';
import '../models/order.dart';
import '../providers/order_provider.dart';
import 'order_history_screen.dart';

class OrderConfirmationScreen extends StatefulWidget {
  final List<CartItem> orderItems;
  final DeliveryType deliveryType;
  final int totalAmount;
  final String customerId;
  final String customerName;
  final String? deliveryAddress;
  final String? specialInstructions;

  const OrderConfirmationScreen({
    super.key,
    required this.orderItems,
    required this.deliveryType,
    required this.totalAmount,
    required this.customerId,
    required this.customerName,
    this.deliveryAddress,
    this.specialInstructions,
  });

  @override
  State<OrderConfirmationScreen> createState() => _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen> {
  bool _addedToProvider = false;
  late Order _order;
  Timer? _cancellationTimer;
  int _cancellationTimeLeft = 300; // 5 minutes
  bool _canCancel = true;

  @override
  void initState() {
    super.initState();
    _startCancellationTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_addedToProvider) {
      _initializeOrder();
    }
  }

  @override
  void dispose() {
    _cancellationTimer?.cancel();
    super.dispose();
  }

  void _initializeOrder() {
    final provider = Provider.of<OrderProvider>(context, listen: false);
    final id = provider.generateOrderId();
    final items = widget.orderItems
        .map((c) => OrderItem(
              id: c.id, 
              title: c.mealTitle, 
              quantity: c.quantity, 
              price: c.price,
            ))
        .toList();

    _order = Order(
      id: id,
      customerId: widget.customerId,
      customerName: widget.customerName,
      date: DateTime.now(),
      items: items,
      totalAmount: widget.totalAmount,
      status: OrderStatus.confirmed,
      deliveryType: widget.deliveryType,
    );

    provider.addOrder(_order);
    _addedToProvider = true;
  }

  void _startCancellationTimer() {
    _cancellationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cancellationTimeLeft > 0) {
        setState(() {
          _cancellationTimeLeft--;
        });
      } else {
        setState(() {
          _canCancel = false;
        });
        timer.cancel();
      }
    });
  }

  void _cancelOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order?'),
        content: Text(
          'You have ${_formatTimeLeft(_cancellationTimeLeft)} left to cancel. Are you sure?',
        ),
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
      final provider = Provider.of<OrderProvider>(context, listen: false);
      provider.updateStatus(_order.id, OrderStatus.cancelled);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    }
  }

  String _formatTimeLeft(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Widget _buildCelebrationSection() {
    return Column(
      children: [
        Icon(
          Icons.celebration,
          color: AppColors.primary,
          size: 80,
        ),
        const SizedBox(height: 16),
        const Text(
          'Order Confirmed!',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.deliveryType == DeliveryType.delivery 
            ? 'Your delicious food is on its way!'
            : 'Your order will be ready for pickup soon!',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.darkText.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildOrderSummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Summary',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            ...widget.orderItems.map((item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Icon(Icons.fastfood, color: AppColors.primary, size: 20),
              ),
              title: Text(item.mealTitle),
              subtitle: Text('Quantity: ${item.quantity}'),
              trailing: Text(
                'KES ${(item.price * item.quantity).toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            )),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  'KES ${widget.totalAmount}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCancellationPolicy() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _canCancel ? Icons.timer : Icons.lock_clock,
                color: Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _canCancel ? 'Cancellation Policy' : 'Cancellation Period Ended',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _canCancel 
              ? 'You can cancel within 5 minutes. Time remaining: ${_formatTimeLeft(_cancellationTimeLeft)}'
              : 'The 5-minute cancellation period has ended. Contact support for urgent concerns.',
            style: TextStyle(
              color: AppColors.darkText.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Confirmation'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildCelebrationSection(),
            const SizedBox(height: 32),
            _buildOrderSummary(),
            const SizedBox(height: 16),
            _buildCancellationPolicy(),
            const SizedBox(height: 32),
            
            Row(
              children: [
                if (_canCancel)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cancelOrder,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancel Order'),
                    ),
                  ),
                if (_canCancel) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Continue Shopping'),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OrderHistoryScreen(customerId: widget.customerId),
                  ),
                );
              },
              child: const Text('View Order History'),
            ),
          ],
        ),
      ),
    );
  }
}
