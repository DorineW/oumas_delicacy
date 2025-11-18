import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/mpesa_service.dart';

class MpesaProvider with ChangeNotifier {
  final MpesaService _mpesaService = MpesaService();

  bool _isProcessing = false;
  String? _checkoutRequestId;
  String _paymentStatus = 'idle'; // idle, pending, completed, failed
  String? _errorMessage;
  StreamSubscription? _statusSubscription;

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

      if (result['success'] == true) {
        _checkoutRequestId = result['checkoutRequestId'];
        
        // Start listening to payment status
        _listenToPaymentStatus();
        
        debugPrint('✅ Payment initiated: $_checkoutRequestId');
        return true;
      } else {
        _errorMessage = result['error'] ?? 'Payment initiation failed';
        _paymentStatus = 'failed';
        _isProcessing = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _paymentStatus = 'failed';
      _isProcessing = false;
      notifyListeners();
      return false;
    }
  }

  /// Listen to payment status changes in real-time
  void _listenToPaymentStatus() {
    if (_checkoutRequestId == null) return;

    // Cancel any existing subscription
    _statusSubscription?.cancel();

    int pollCount = 0;
    const maxPolls = 24; // 2 minutes (24 * 5 seconds)

    _statusSubscription = _mpesaService
        .listenToPaymentStatus(_checkoutRequestId!)
        .listen(
      (status) {
        debugPrint('💳 Payment status update: $status');
        _paymentStatus = status;
        
        if (status == 'completed') {
          _isProcessing = false;
          _statusSubscription?.cancel();
          debugPrint('✅ Payment completed successfully!');
        } else if (status == 'failed' || status == 'cancelled') {
          _isProcessing = false;
          _errorMessage = 'Payment $status';
          _statusSubscription?.cancel();
          debugPrint('❌ Payment $status');
        }
        
        notifyListeners();
      },
      onError: (error) {
        debugPrint('❌ Payment status error: $error');
        _errorMessage = error.toString();
        _paymentStatus = 'failed';
        _isProcessing = false;
        _statusSubscription?.cancel();
        notifyListeners();
      },
    );

    // Also poll manually every 5 seconds as backup (sandbox callback may be unreliable)
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_paymentStatus != 'pending' || pollCount >= maxPolls) {
        timer.cancel();
        return;
      }
      
      pollCount++;
      debugPrint('🔄 Manual status check ($pollCount/$maxPolls)...');
      checkStatus();
    });

    // Timeout after 2 minutes
    Future.delayed(const Duration(minutes: 2), () {
      if (_paymentStatus == 'pending') {
        _errorMessage = 'Payment timeout - please check your phone and complete the payment';
        _paymentStatus = 'failed';
        _isProcessing = false;
        _statusSubscription?.cancel();
        notifyListeners();
        debugPrint('⏱️ Payment timeout after 2 minutes');
      }
    });
  }

  /// Manually check payment status
  Future<void> checkStatus() async {
    if (_checkoutRequestId == null) return;

    try {
      final status = await _mpesaService.checkPaymentStatus(_checkoutRequestId!);
      if (status != null) {
        _paymentStatus = status;
        
        if (status == 'completed' || status == 'failed') {
          _isProcessing = false;
          _statusSubscription?.cancel();
        }
        
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error checking status: $e');
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
    notifyListeners();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }
}
