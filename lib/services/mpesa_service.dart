// lib/services/mpesa_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MpesaService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Format phone number to 254XXXXXXXXX format
  String formatPhoneNumber(String phone) {
    // Remove all non-digit characters
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');
    
    // If starts with 0, replace with 254
    if (cleaned.startsWith('0')) {
      cleaned = '254${cleaned.substring(1)}';
    }
    // If starts with +254, remove the +
    else if (cleaned.startsWith('254')) {
      // Already in correct format
    }
    // If starts with just country code without +
    else if (cleaned.length == 9) {
      // Assume it's missing the 254 prefix
      cleaned = '254$cleaned';
    }
    
    return cleaned;
  }

  /// Initiate M-Pesa STK Push using Supabase Edge Function
  Future<Map<String, dynamic>> initiatePayment({
    required String phoneNumber,
    required int amount,
    String? orderId,
    required String accountReference,
    String? transactionDesc,
  }) async {
    try {
      final formattedPhone = formatPhoneNumber(phoneNumber);
      
      debugPrint('🔄 Initiating M-Pesa payment...');
      debugPrint('   Raw Phone: $phoneNumber');
      debugPrint('   Formatted Phone: $formattedPhone');
      debugPrint('   Amount: $amount');
      debugPrint('   Account Ref: $accountReference');
      debugPrint('   Order ID: $orderId');

      final body = {
        'phoneNumber': formattedPhone,
        'amount': amount,
        'orderId': orderId,
        'accountReference': accountReference,
        'transactionDesc': transactionDesc ?? 'Payment for order $accountReference',
      };
      
      debugPrint('   Request body: $body');

      final response = await _supabase.functions.invoke(
        'mpesa-stk-push',
        body: body,
      );

      debugPrint('   Response status: ${response.status}');
      debugPrint('   Response data: ${response.data}');

      if (response.status != 200) {
        debugPrint('❌ STK Push failed with status ${response.status}: ${response.data}');
        throw Exception('Failed to initiate payment: ${response.data}');
      }

      final data = response.data as Map<String, dynamic>;
      
      if (data['success'] == true) {
        debugPrint('✅ STK Push sent successfully');
        debugPrint('   Checkout Request ID: ${data['checkoutRequestId']}');
        debugPrint('   Transaction ID: ${data['transactionId']}');
        return {
          'success': true,
          'message': data['message'],
          'checkoutRequestId': data['checkoutRequestId'],
          'merchantRequestId': data['merchantRequestId'],
          'transactionId': data['transactionId'],
        };
      } else {
        debugPrint('❌ STK Push unsuccessful: ${data['error']}');
        throw Exception(data['error'] ?? 'Payment initiation failed');
      }
    } catch (e) {
      debugPrint('❌ Payment error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Check payment status by querying M-Pesa API directly
  /// This works in sandbox and updates the database with real M-Pesa status
  Future<String?> checkPaymentStatus(String checkoutRequestId) async {
    try {
      debugPrint('🔍 Querying M-Pesa for transaction status...');
      
      // Call the query status Edge Function
      final response = await _supabase.functions.invoke(
        'mpesa-query-status',
        body: {
          'checkoutRequestId': checkoutRequestId,
        },
      );

      if (response.status != 200) {
        debugPrint('⚠️ Query failed, checking database...');
        // Fallback to database check
        final dbResponse = await _supabase
            .from('mpesa_transactions')
            .select('status, result_desc')
            .eq('checkout_request_id', checkoutRequestId)
            .maybeSingle();

        if (dbResponse == null) return null;
        return dbResponse['status'] as String?;
      }

      final data = response.data as Map<String, dynamic>;
      
      if (data['success'] == true) {
        final status = data['status'] as String;
        debugPrint('✅ Transaction status: $status');
        return status;
      }
      
      return null;
    } catch (e) {
      debugPrint('Error checking payment status: $e');
      // Fallback to database check
      try {
        final response = await _supabase
            .from('mpesa_transactions')
            .select('status, result_desc')
            .eq('checkout_request_id', checkoutRequestId)
            .maybeSingle();

        if (response == null) return null;
        return response['status'] as String?;
      } catch (e2) {
        debugPrint('Error in fallback check: $e2');
        return null;
      }
    }
  }

  /// Listen to payment status changes in real-time
  Stream<String> listenToPaymentStatus(String checkoutRequestId) {
    return _supabase
        .from('mpesa_transactions')
        .stream(primaryKey: ['id'])
        .eq('checkout_request_id', checkoutRequestId)
        .map((data) {
          if (data.isEmpty) return 'pending';
          return data.first['status'] as String;
        });
  }

  /// Get user's transaction history
  Future<List<Map<String, dynamic>>> getUserTransactions() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('mpesa_transactions')
          .select()
          .eq('user_auth_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching transactions: $e');
      return [];
    }
  }

  /// Get receipt for a transaction
  Future<Map<String, dynamic>?> getReceipt(String transactionId) async {
    try {
      final response = await _supabase
          .from('receipts')
          .select('''
            *,
            receipt_items(*)
          ''')
          .eq('transaction_id', transactionId)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('Error fetching receipt: $e');
      return null;
    }
  }

  /// Legacy method - for backward compatibility
  @Deprecated('Use initiatePayment instead')
  Future<Map<String, dynamic>> initiateStkPush({
    required String phoneNumber,
    required int amount,
    required String userId,
    required Map<String, dynamic> orderDetails,
  }) async {
    return initiatePayment(
      phoneNumber: phoneNumber,
      amount: amount,
      orderId: orderDetails['orderId'],
      accountReference: orderDetails['orderReference'] ?? 'ORDER',
      transactionDesc: orderDetails['description'],
    );
  }

  /// Legacy method - for backward compatibility
  @Deprecated('Use checkPaymentStatus instead')
  Future<Map<String, dynamic>> queryStkStatus({
    required String checkoutRequestId,
  }) async {
    final status = await checkPaymentStatus(checkoutRequestId);
    return {
      'success': status != null,
      'resultCode': status == 'completed' ? 0 : (status == 'failed' ? 1 : null),
      'resultDesc': status,
    };
  }

  /// Legacy method - for backward compatibility  
  @Deprecated('Use checkPaymentStatus instead')
  Future<Map<String, dynamic>> checkOrderStatus({
    required String orderId,
  }) async {
    try {
      final response = await _supabase
          .from('orders')
          .select('status, total, placed_at')
          .eq('id', orderId)
          .maybeSingle();

      if (response == null) {
        return {'success': false, 'error': 'Order not found'};
      }

      return {
        'success': true,
        'status': response['status'],
        'total': response['total'],
        'placedAt': response['placed_at'],
      };
    } catch (e) {
      debugPrint('❌ Exception checking order status: $e');
      return {
        'success': false,
        'error': 'Failed to connect to server',
      };
    }
  }
}
