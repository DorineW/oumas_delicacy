// lib/screens/mpesa_payment_confirmation_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/mpesa_service.dart';

class MpesaPaymentConfirmationScreen extends StatefulWidget {
  final String? orderId; // CHANGED: Made nullable since order created after payment
  final int totalAmount;
  final String checkoutRequestId;
  final String phoneNumber; // ADDED: Customer phone number

  const MpesaPaymentConfirmationScreen({
    super.key,
    this.orderId, // CHANGED: No longer required
    required this.totalAmount,
    required this.checkoutRequestId,
    required this.phoneNumber, // ADDED
  });

  @override
  State<MpesaPaymentConfirmationScreen> createState() =>
      _MpesaPaymentConfirmationScreenState();
}

class _MpesaPaymentConfirmationScreenState
    extends State<MpesaPaymentConfirmationScreen> {
  Timer? _statusCheckTimer;
  Timer? _timeCounterTimer;
  String _orderStatus = 'waiting';
  String? _mpesaReceiptNumber;
  String? _actualOrderId;
  DateTime? _paymentCompletedAt;
  int _secondsElapsed = 0;
  late final MpesaService _mpesaService;
  StreamSubscription? _paymentStatusSubscription;

  @override
  void initState() {
    super.initState();
    _mpesaService = MpesaService();
    _actualOrderId = widget.orderId; // Initialize with provided orderId (may be null)
    _startPaymentPolling();
    _startTimeCounter();
  }

  void _startTimeCounter() {
    _timeCounterTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsElapsed++);
      if (_orderStatus != 'waiting') {
        timer.cancel();
      }
    });
  }

  void _startPaymentPolling() {
    debugPrint('🔄 Starting payment status listening...');
    
    // Use real-time status listening via Stream
    _paymentStatusSubscription = _mpesaService
        .listenToPaymentStatus(widget.checkoutRequestId)
        .listen((status) {
      if (!mounted) return;
      
      debugPrint('📊 Payment status changed: $status');
      
      setState(() {
        // Map payment status to order status
        if (status == 'completed') {
          _orderStatus = 'confirmed';
          if (_paymentCompletedAt == null) {
            _paymentCompletedAt = DateTime.now();
          }
        } else if (status == 'failed' || status == 'cancelled') {
          _orderStatus = status;
        } else {
          _orderStatus = 'waiting';
        }
      });

      // Navigate after status change
      if (status == 'completed') {
        debugPrint('✅ Payment completed');
        _statusCheckTimer?.cancel();
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _navigateToHome();
          }
        });
      } else if (status == 'failed' || status == 'cancelled') {
        debugPrint('❌ Payment $status');
        _statusCheckTimer?.cancel();
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            _navigateToHome();
          }
        });
      }
    });
    
    // Set a timeout after 2 minutes
    _statusCheckTimer = Timer(const Duration(minutes: 2), () {
      if (!mounted) return;
      if (_orderStatus == 'waiting') {
        debugPrint('⏱️ Payment timeout reached');
        setState(() {
          _orderStatus = 'failed';
        });
        _paymentStatusSubscription?.cancel();
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _navigateToHome();
          }
        });
      }
    });
  }



  void _navigateToHome() {
    // Navigate back to the root and clear all previous routes
    // User lands on the main dashboard/home screen
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/home',
      (route) => false,
    );
  }

  @override
  void dispose() {
    _paymentStatusSubscription?.cancel();
    _statusCheckTimer?.cancel();
    _timeCounterTimer?.cancel();
    super.dispose();
  }

  Widget _buildStatusIcon() {
    switch (_orderStatus) {
      case 'confirmed':
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 80,
          ),
        );
      case 'cancelled':
      case 'failed':
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.cancel,
            color: Colors.red,
            size: 80,
          ),
        );
      default:
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              strokeWidth: 6,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        );
    }
  }

  Widget _buildStatusMessage() {
    switch (_orderStatus) {
      case 'confirmed':
        return const Column(
          children: [
            Text(
              'Payment Confirmed!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Your order has been successfully placed',
              style: TextStyle(fontSize: 16, color: AppColors.darkText),
              textAlign: TextAlign.center,
            ),
          ],
        );
      case 'cancelled':
        return const Column(
          children: [
            Text(
              'Payment Cancelled',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Your payment was cancelled or failed',
              style: TextStyle(fontSize: 16, color: AppColors.darkText),
              textAlign: TextAlign.center,
            ),
          ],
        );
      case 'failed':
        return const Column(
          children: [
            Text(
              'Payment Timeout',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'No payment received. Please try again.',
              style: TextStyle(fontSize: 16, color: AppColors.darkText),
              textAlign: TextAlign.center,
            ),
          ],
        );
      default:
        return Column(
          children: [
            const Text(
              'Waiting for Payment',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please complete the M-Pesa prompt on your phone',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Time elapsed: $_secondsElapsed seconds',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _orderStatus != 'waiting',
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('M-Pesa Payment'),
          backgroundColor: AppColors.primary,
          automaticallyImplyLeading: _orderStatus != 'waiting',
          iconTheme: const IconThemeData(color: AppColors.white),
          titleTextStyle: const TextStyle(
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),

                // Status Icon
                _buildStatusIcon(),
                const SizedBox(height: 32),

                // Status Message
                _buildStatusMessage(),
                const SizedBox(height: 32),

                // Order Details Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Order Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkText,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_actualOrderId != null)
                        _buildDetailRow('Order ID', _actualOrderId!.substring(0, 8))
                      else
                        _buildDetailRow('Order ID', 'Creating...'),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        'Amount',
                        'KSh ${widget.totalAmount.toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow('Status', _orderStatus.toUpperCase()),
                    ],
                  ),
                ),

                // Receipt (only show when payment confirmed)
                if (_orderStatus == 'confirmed') ...[
                  const SizedBox(height: 16),
                  _buildReceipt(),
                ],

                // Action Button
                if (_orderStatus != 'waiting') ...[
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _navigateToHome,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Back to Home',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.darkText,
          ),
        ),
      ],
    );
  }

  // ADDED: Receipt widget
  Widget _buildReceipt() {
    // Use the actual payment completion time, fallback to current time
    final now = _paymentCompletedAt ?? DateTime.now();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, color: Colors.green, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Payment Receipt',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Colors.green),
          
          _buildReceiptRow('Transaction Code', _mpesaReceiptNumber ?? 'N/A'),
          const SizedBox(height: 12),
          _buildReceiptRow('Phone Number', widget.phoneNumber),
          const SizedBox(height: 12),
          if (_actualOrderId != null)
            _buildReceiptRow('Order ID', _actualOrderId!.substring(0, 13))
          else
            _buildReceiptRow('Order ID', 'N/A'),
          const SizedBox(height: 12),
          _buildReceiptRow('Amount Paid', 'KSh ${widget.totalAmount.toStringAsFixed(2)}'),
          const SizedBox(height: 12),
          _buildReceiptRow('Date', '${now.day}/${now.month}/${now.year}'),
          const SizedBox(height: 12),
          _buildReceiptRow('Time', '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}'),
          
          const Divider(height: 24, color: Colors.green),
          
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Column(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 32),
                SizedBox(height: 8),
                Text(
                  'Payment Successful',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'You will receive an SMS confirmation shortly',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
