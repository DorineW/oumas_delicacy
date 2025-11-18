import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/mpesa_provider.dart';

class MpesaPaymentButton extends StatefulWidget {
  final String phoneNumber;
  final int amount;
  final String? orderId;
  final String orderReference;
  final VoidCallback onSuccess;
  final VoidCallback? onCancel;

  const MpesaPaymentButton({
    Key? key,
    required this.phoneNumber,
    required this.amount,
    this.orderId,
    required this.orderReference,
    required this.onSuccess,
    this.onCancel,
  }) : super(key: key);

  @override
  State<MpesaPaymentButton> createState() => _MpesaPaymentButtonState();
}

class _MpesaPaymentButtonState extends State<MpesaPaymentButton> {
  void _showPaymentDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PaymentDialog(
        phoneNumber: widget.phoneNumber,
        amount: widget.amount,
        orderId: widget.orderId,
        orderReference: widget.orderReference,
        onSuccess: widget.onSuccess,
        onCancel: widget.onCancel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _showPaymentDialog(context),
        icon: const Icon(Icons.phone_android, size: 24),
        label: const Text(
          'Pay with M-Pesa',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
  }
}

class _PaymentDialog extends StatefulWidget {
  final String phoneNumber;
  final int amount;
  final String? orderId;
  final String orderReference;
  final VoidCallback onSuccess;
  final VoidCallback? onCancel;

  const _PaymentDialog({
    required this.phoneNumber,
    required this.amount,
    this.orderId,
    required this.orderReference,
    required this.onSuccess,
    this.onCancel,
  });

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  @override
  void initState() {
    super.initState();
    // Defer payment initiation until after build completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initiatePayment();
    });
  }

  Future<void> _initiatePayment() async {
    if (!mounted) return;
    
    final mpesaProvider = context.read<MpesaProvider>();
    
    final success = await mpesaProvider.initiatePayment(
      phoneNumber: widget.phoneNumber,
      amount: widget.amount,
      orderId: widget.orderId,
      accountReference: widget.orderReference,
      transactionDesc: 'Payment for ${widget.orderReference}',
    );

    if (!success && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mpesaProvider.errorMessage ?? 'Payment failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MpesaProvider>(
      builder: (context, mpesaProvider, child) {
        final status = mpesaProvider.paymentStatus;

        // Handle payment completion
        if (status == 'completed') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pop();
              widget.onSuccess();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 8),
                      Text('✅ Payment successful!'),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          });
        }

        // Handle payment failure
        if (status == 'failed' || status == 'cancelled') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          mpesaProvider.errorMessage ?? '❌ Payment $status',
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 4),
                ),
              );
              mpesaProvider.reset();
            }
          });
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.phone_android,
                  color: Colors.green,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'M-Pesa Payment',
                style: TextStyle(fontSize: 20),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (status == 'pending') ...[
                const SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    color: Colors.green,
                    strokeWidth: 6,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Check your phone',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.phoneNumber,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Amount to pay',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'KSh ${widget.amount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Steps to complete payment:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '1. Check your phone for M-Pesa prompt\n'
                        '2. Enter your M-Pesa PIN\n'
                        '3. Confirm the payment',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                mpesaProvider.reset();
                Navigator.of(context).pop();
                widget.onCancel?.call();
              },
              icon: const Icon(Icons.close),
              label: const Text('Cancel'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
              ),
            ),
          ],
        );
      },
    );
  }
}
