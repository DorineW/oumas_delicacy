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
  final Map<String, dynamic>? deliveryAddress; // FIXED: Match Order model
  final String? specialInstructions;
  final String? phoneNumber; // ADDED

  const OrderConfirmationScreen({
    super.key,
    required this.orderItems,
    required this.deliveryType,
    required this.totalAmount,
    required this.customerId,
    required this.customerName,
    this.deliveryAddress,
    this.specialInstructions,
    this.phoneNumber, // ADDED
  });

  @override
  State<OrderConfirmationScreen> createState() => _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen> {
  bool _addedToProvider = false;
  late Order _order;
  Timer? _cancellationTimer;
  Timer? _autoConfirmTimer; // ADDED: Timer for auto-confirmation
  int _cancellationTimeLeft = 300; // 5 minutes
  bool _canCancel = true;

  @override
  void initState() {
    super.initState();
    _startCancellationTimer();
    
    // FIXED: Defer initialization until after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_addedToProvider) {
        _initializeOrder();
      }
    });
  }

  @override
  void dispose() {
    _cancellationTimer?.cancel();
    _autoConfirmTimer?.cancel(); // ADDED: Cancel auto-confirm timer
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

    // FIXED: Calculate amounts
    final subtotal = items.fold<int>(0, (sum, item) => sum + (item.price * item.quantity));
    final deliveryFee = widget.deliveryType == DeliveryType.delivery ? 150 : 0; // Default delivery fee
    const tax = 0; // No tax

    _order = Order(
      id: id,
      customerId: widget.customerId,
      customerName: widget.customerName,
      deliveryPhone: widget.phoneNumber,
      date: DateTime.now(),
      items: items,
      subtotal: subtotal, // FIXED: Added required field
      deliveryFee: deliveryFee, // FIXED: Added required field
      tax: tax, // FIXED: Added required field
      totalAmount: widget.totalAmount,
      status: OrderStatus.pending,
      deliveryType: widget.deliveryType,
      deliveryAddress: widget.deliveryAddress,
    );

    provider.addOrder(_order);
    setState(() {
      _addedToProvider = true;
    });
    
    // ADDED: Start auto-confirmation timer
    _startAutoConfirmTimer();
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

  // ADDED: Auto-confirm order after 5 minutes
  void _startAutoConfirmTimer() {
    _autoConfirmTimer = Timer(const Duration(minutes: 5), () {
      if (!mounted) return;
      
      final provider = Provider.of<OrderProvider>(context, listen: false);
      final currentOrder = provider.orders.firstWhere(
        (o) => o.id == _order.id,
        orElse: () => _order,
      );
      
      // Only auto-confirm if still pending (not cancelled)
      if (currentOrder.status == OrderStatus.pending) {
        provider.updateStatus(_order.id, OrderStatus.confirmed);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Your order has been confirmed!'),
                  ),
                ],
              ),
              backgroundColor: Colors.blue,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    });
  }

  void _cancelOrder() async {
    final confirmed = await _showCancellationReasonDialog();

    if (confirmed != null && confirmed.isNotEmpty) {
      final provider = Provider.of<OrderProvider>(context, listen: false);
      provider.cancelOrder(_order.id, confirmed); // UPDATED: Use cancelOrder with reason
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Order cancelled successfully'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
        
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    }
  }

  // ADDED: Show cancellation reason dialog
  Future<String?> _showCancellationReasonDialog() async {
    String? selectedReason;
    final TextEditingController customController = TextEditingController();
    
    final result = await showDialog<String>(
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
                        const Icon(Icons.timer, size: 16, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Time remaining: ${_formatTimeLeft(_cancellationTimeLeft)}',
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
                    'Please tell us why you want to cancel:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Reason options
                  ...[
                    'Changed my mind',
                    'Ordered by mistake',
                    'Too expensive',
                    'Found better alternative',
                    'Taking too long',
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
                        hintText: 'Enter your reason...',
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
                child: const Text('Keep Order'),
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
                  
                  customController.dispose();
                  Navigator.pop(context, reason);
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
    );
    
    return result;
  }

  String _formatTimeLeft(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Widget _buildCelebrationSection() {
    return Column(
      children: [
        const Icon(
          Icons.celebration,
          color: AppColors.primary,
          size: 80,
        ),
        const SizedBox(height: 16),
        Text(
          _canCancel ? 'Order Placed!' : 'Order Confirmed!',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _canCancel
              ? 'Your order is pending confirmation...'
              : widget.deliveryType == DeliveryType.delivery 
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
                child: const Icon(Icons.fastfood, color: AppColors.primary, size: 20),
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

  // UPDATED: Cancellation policy with better messaging
  Widget _buildCancellationPolicy() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: _canCancel ? Colors.orange.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _canCancel ? Colors.orange.withOpacity(0.3) : Colors.blue.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _canCancel ? Icons.timer : Icons.check_circle,
                color: _canCancel ? Colors.orange : Colors.blue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _canCancel ? 'Cancellation Window' : 'Order Confirmed',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _canCancel ? Colors.orange : Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _canCancel 
              ? 'Your order will be automatically confirmed in ${_formatTimeLeft(_cancellationTimeLeft)}. You can cancel before then.'
              : 'Your order has been confirmed and is being prepared. Contact support for any changes.',
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
            
            // FIXED: Direct navigation to order history
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const OrderHistoryScreen(), // FIXED: Removed customerId parameter
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
