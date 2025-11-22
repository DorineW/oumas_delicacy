import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/mpesa_service.dart';

class MpesaProvider with ChangeNotifier {
  final MpesaService _mpesaService = MpesaService();

  bool _isProcessing = false;
  String? _checkoutRequestId;
  String _paymentStatus = 'idle'; // idle, pending, completed, failed, timeout
  String? _errorMessage;
  StreamSubscription? _statusSubscription;
  Timer? _pollTimer;
  Timer? _timeoutTimer;

  bool get isProcessing => _isProcessing;
  String get paymentStatus => _paymentStatus;
  String? get errorMessage => _errorMessage;
  String? get checkoutRequestId => _checkoutRequestId;

  /// Initiate M-Pesa payment
  Future<bool> initiatePayment({
    required String phoneNumber,
    required int amount,
    String? orderId,
    required String accountReference,
    String? transactionDesc,
  }) async {
    debugPrint('💳 MpesaProvider: initiatePayment called');
    debugPrint('   Phone: $phoneNumber');
    debugPrint('   Amount: $amount');
    
    _isProcessing = true;
    _errorMessage = null;
    _paymentStatus = 'pending';
    notifyListeners();

    try {
      final result = await _mpesaService.initiatePayment(
        phoneNumber: phoneNumber,
        amount: amount,
        orderId: orderId,
        accountReference: accountReference,
        transactionDesc: transactionDesc,
      );

      debugPrint('   Service result: $result');

      if (result['success'] == true) {
        _checkoutRequestId = result['checkoutRequestId'];
        
        debugPrint('✅ Payment initiated: $_checkoutRequestId');
        debugPrint('   Starting status polling...');
        
        // Start listening to payment status
        _listenToPaymentStatus();
        
        return true;
      } else {
        _errorMessage = result['error'] ?? 'Payment initiation failed';
        _paymentStatus = 'failed';
        _isProcessing = false;
        notifyListeners();
        debugPrint('❌ Payment initiation failed: $_errorMessage');
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _paymentStatus = 'failed';
      _isProcessing = false;
      notifyListeners();
      debugPrint('❌ Payment exception: $e');
      return false;
    }
  }

  /// Listen to payment status changes in real-time
  void _listenToPaymentStatus() {
    if (_checkoutRequestId == null) return;

    // Cancel any existing timers/subscriptions
    _statusSubscription?.cancel();
    _pollTimer?.cancel();
    _timeoutTimer?.cancel();

    int pollCount = 0;
    const maxPolls = 36; // 3 minutes (36 * 5 seconds) - Extended timeout

    // Try realtime subscription but don't rely on it
    try {
      _statusSubscription = _mpesaService
          .listenToPaymentStatus(_checkoutRequestId!)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: (sink) {
              debugPrint('⚠️ Realtime subscription timed out, using polling only');
              sink.close();
            },
          )
          .listen(
        (status) {
          debugPrint('💳 Realtime status update: $status');
          _updatePaymentStatus(status);
        },
        onError: (error) {
          debugPrint('⚠️ Realtime error (will use polling): $error');
          // Don't mark as failed, continue with polling
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('⚠️ Realtime subscription failed (will use polling): $e');
      // Continue with polling even if realtime fails
    }

    // Aggressive polling - check every 3 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_paymentStatus != 'pending' || pollCount >= maxPolls) {
        timer.cancel();
        return;
      }
      
      pollCount++;
      debugPrint('🔄 Manual status check ($pollCount/$maxPolls)...');
      checkStatus();
    });

    // Timeout after 3 minutes (extended from 2 minutes)
    _timeoutTimer = Timer(const Duration(minutes: 3), () {
      if (_paymentStatus == 'pending') {
        debugPrint('⏱️ Payment timeout after 3 minutes - checking one final time...');
        
        // One final check before timing out
        checkStatus().then((_) {
          Future.delayed(const Duration(seconds: 2), () {
            if (_paymentStatus == 'pending') {
              _errorMessage = 'Payment verification timed out. Your payment may still be processing. Please check "My Orders" or M-Pesa message.';
              _paymentStatus = 'timeout';
              _isProcessing = false;
              _statusSubscription?.cancel();
              _pollTimer?.cancel();
              notifyListeners();
              debugPrint('⏱️ Final timeout - payment status still pending');
            }
          });
        });
      }
    });
  }

  /// Update payment status and handle completion
  void _updatePaymentStatus(String status) {
    _paymentStatus = status;
    
    if (status == 'completed') {
      _isProcessing = false;
      _statusSubscription?.cancel();
      debugPrint('✅ Payment completed successfully!');
    } else if (status == 'failed') {
      _isProcessing = false;
      _errorMessage = 'Payment failed';
      _statusSubscription?.cancel();
      debugPrint('❌ Payment failed');
    } else if (status == 'cancelled') {
      _isProcessing = false;
      _errorMessage = 'Payment cancelled by user';
      _statusSubscription?.cancel();
      debugPrint('❌ Payment cancelled');
    }
    
    notifyListeners();
  }

  /// Manually check payment status
  Future<void> checkStatus() async {
    if (_checkoutRequestId == null) return;

    try {
      final status = await _mpesaService.checkPaymentStatus(_checkoutRequestId!);
      if (status != null && status != _paymentStatus) {
        debugPrint('📊 Status changed: $_paymentStatus → $status');
        _updatePaymentStatus(status);
      }
    } catch (e) {
      debugPrint('⚠️ Error checking status: $e');
      // Don't fail on polling errors, just log and continue
    }
  }

  /// Get user's transaction history
  Future<List<Map<String, dynamic>>> getTransactionHistory() async {
    return await _mpesaService.getUserTransactions();
  }

  /// Get receipt for a transaction
  Future<Map<String, dynamic>?> getReceipt(String transactionId) async {
    return await _mpesaService.getReceipt(transactionId);
  }

  /// Reset payment state
  void reset() {
    _isProcessing = false;
    _checkoutRequestId = null;
    _paymentStatus = 'idle';
    _errorMessage = null;
    _statusSubscription?.cancel();
    _pollTimer?.cancel();
    _timeoutTimer?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _pollTimer?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }
}
