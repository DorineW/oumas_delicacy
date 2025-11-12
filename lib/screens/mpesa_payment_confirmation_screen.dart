// lib/screens/mpesa_payment_confirmation_screen.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/mpesa_service.dart';

class MpesaPaymentConfirmationScreen extends StatefulWidget {
  final String orderId;
  final int totalAmount;
  final String checkoutRequestId;
  final String phoneNumber; // ADDED: Customer phone number

  const MpesaPaymentConfirmationScreen({
    super.key,
    required this.orderId,
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
  Timer? _stkQueryTimer;
  String _orderStatus = 'pending';
  String? _stkQueryStatus;
  String? _mpesaReceiptNumber; // ADDED: M-Pesa receipt/transaction code
  int _stkQueryCount = 0;
  int _secondsElapsed = 0;
  final bool _isTestMode = kDebugMode;

  @override
  void initState() {
    super.initState();
    _startPaymentPolling();
    _startStkQueryPolling();
    _startTimeCounter();
  }

  void _startTimeCounter() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsElapsed++);
      if (_orderStatus != 'pending') {
        timer.cancel();
      }
    });
  }

  void _startPaymentPolling() {
    debugPrint('🔄 Starting payment status polling...');
    
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final statusResult = await MpesaService.checkOrderStatus(
        orderId: widget.orderId,
      );

      if (statusResult['success'] == true) {
        final status = statusResult['status'];
        debugPrint('📊 Order status: $status');
        
        setState(() => _orderStatus = status);

        if (status == 'confirmed' || status == 'cancelled') {
          debugPrint('✅ Final status reached: $status');
          timer.cancel();
          _stkQueryTimer?.cancel();
          
          // Navigate after a short delay
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              _navigateToHome();
            }
          });
        }
      }
    });
  }

  void _startStkQueryPolling() {
    debugPrint('🔍 Starting STK query polling...');
    
    _stkQueryTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (!mounted || _stkQueryCount >= 18 || _orderStatus != 'pending') {
        timer.cancel();
        return;
      }

      final queryResult = await MpesaService.queryStkStatus(
        checkoutRequestId: widget.checkoutRequestId,
      );

      if (queryResult['success'] == true) {
        setState(() {
          _stkQueryStatus = queryResult['resultDesc'] ?? 'Querying...';
        });

        if (queryResult['resultCode'] == '0') {
          debugPrint('✅ STK query successful');
          timer.cancel();
        }
      }

      _stkQueryCount++;
    });
  }

  Future<void> _triggerMockCallback(bool success) async {
    final result = await MpesaService.triggerMockCallback(
      orderId: widget.orderId,
      success: success,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['success'] == true
                ? 'Mock ${success ? 'success' : 'failure'} triggered'
                : 'Failed to trigger mock: ${result['error']}',
          ),
          backgroundColor: result['success'] == true ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/',
      (route) => false,
    );
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    _stkQueryTimer?.cancel();
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
              'The payment was not completed',
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
      canPop: _orderStatus != 'pending',
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            _isTestMode ? 'M-Pesa Payment (TEST MODE)' : 'M-Pesa Payment',
          ),
          backgroundColor: _isTestMode ? Colors.orange : AppColors.primary,
          automaticallyImplyLeading: _orderStatus != 'pending',
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
                      _buildDetailRow('Order ID', widget.orderId.substring(0, 8)),
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

                // STK Query Status
                if (_stkQueryStatus != null && _orderStatus == 'pending') ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.blue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _stkQueryStatus!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Test Controls (Debug Mode Only)
                if (_isTestMode && _orderStatus == 'pending') ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.science, color: Colors.orange),
                            SizedBox(width: 8),
                            Text(
                              'TEST CONTROLS',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _triggerMockCallback(true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.check),
                                label: const Text('Simulate Success'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _triggerMockCallback(false),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.close),
                                label: const Text('Simulate Failure'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // Action Button
                if (_orderStatus != 'pending') ...[
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
    final now = DateTime.now();
    final transactionCode = _mpesaReceiptNumber ?? 'TEST${now.millisecondsSinceEpoch.toString().substring(7)}';
    
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
          
          _buildReceiptRow('Transaction Code', transactionCode),
          const SizedBox(height: 12),
          _buildReceiptRow('Phone Number', widget.phoneNumber),
          const SizedBox(height: 12),
          _buildReceiptRow('Order ID', widget.orderId.substring(0, 13)),
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
