// lib/services/mpesa_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class MpesaService {
  // Using ngrok public URL for M-Pesa callbacks
  static const String baseUrl = 'https://chaim-eared-kaylin.ngrok-free.dev/api';
  // Change to 'http://10.0.2.2:3000/api' if using Android emulator
  // Change to 'https://your-ngrok-url.ngrok.io/api' for production testing

  /// Format phone number to 254XXXXXXXXX format
  static String formatPhoneNumber(String phone) {
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

  /// Initiate STK Push payment
  static Future<Map<String, dynamic>> initiateStkPush({
    required String phoneNumber,
    required int amount,
    required String userId,
    required Map<String, dynamic> orderDetails, // CHANGED: Added orderDetails
  }) async {
    try {
      // Format phone number to 254XXXXXXXXX
      final formattedPhone = formatPhoneNumber(phoneNumber);
      
      debugPrint('📱 Initiating M-Pesa STK push...');
      debugPrint('   Phone: $phoneNumber → $formattedPhone');
      debugPrint('   Amount: KSh $amount');

      final response = await http.post(
        Uri.parse('$baseUrl/payments/initiate-stk'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phoneNumber': formattedPhone,
          'amount': amount,
          'userId': userId,
          'orderDetails': orderDetails, // CHANGED: Send order details
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Connection timed out'),
      );

      debugPrint('📥 Response status: ${response.statusCode}');
      debugPrint('📥 Response body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        debugPrint('✅ STK push initiated successfully');
        return {
          'success': true,
          'checkoutRequestID': data['checkoutRequestID'],
          'message': data['message'],
          'paymentId': data['paymentId'],
          'environment': data['environment'],
          'testPhoneUsed': data['testPhoneUsed'],
        };
      } else {
        debugPrint('❌ STK push failed: ${data['error']}');
        return {
          'success': false,
          'error': data['error'] ?? 'Payment initiation failed',
          'details': data['details'],
        };
      }
    } catch (e) {
      debugPrint('❌ Exception during STK push: $e');
      return {
        'success': false,
        'error': 'Failed to connect to payment server',
        'details': e.toString(),
      };
    }
  }

  /// Query STK Push status
  static Future<Map<String, dynamic>> queryStkStatus({
    required String checkoutRequestId,
  }) async {
    try {
      debugPrint('🔍 Querying STK status for: $checkoutRequestId');

      final response = await http.post(
        Uri.parse('$baseUrl/payments/query-stk-status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'checkoutRequestId': checkoutRequestId,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'resultCode': data['data']['ResultCode'],
          'resultDesc': data['data']['ResultDesc'],
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to query status',
        };
      }
    } catch (e) {
      debugPrint('❌ Exception during STK query: $e');
      return {
        'success': false,
        'error': 'Failed to query payment status',
      };
    }
  }

  /// Check payment status by checkoutRequestId (when order doesn't exist yet)
  static Future<Map<String, dynamic>> checkPaymentStatus({
    required String checkoutRequestId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/payments/$checkoutRequestId/status'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'status': data['status'],
          'orderId': data['orderId'],
          'total': data['total'],
          'placedAt': data['placedAt'],
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to check payment status',
        };
      }
    } catch (e) {
      debugPrint('❌ Exception checking payment status: $e');
      return {
        'success': false,
        'error': 'Failed to connect to server',
      };
    }
  }

  /// Check order status (legacy - for when order ID is known)
  static Future<Map<String, dynamic>> checkOrderStatus({
    required String orderId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/orders/$orderId/status'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'status': data['status'],
          'total': data['total'],
          'placedAt': data['placed_at'],
        };
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'error': 'Order not found',
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to check order status',
        };
      }
    } catch (e) {
      debugPrint('❌ Exception checking order status: $e');
      return {
        'success': false,
        'error': 'Failed to connect to server',
      };
    }
  }

  /// Mock callback for testing (sandbox only)
  static Future<Map<String, dynamic>> triggerMockCallback({
    required String checkoutRequestId,
    required bool success,
  }) async {
    try {
      debugPrint('🧪 Triggering mock callback: ${success ? 'SUCCESS' : 'FAILURE'}');

      final response = await http.post(
        Uri.parse('$baseUrl/payments/mock-callback'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'checkoutRequestID': checkoutRequestId,
          'success': success,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint('✅ Mock callback sent');
        return {'success': true};
      } else {
        return {'success': false, 'error': 'Failed to send mock callback'};
      }
    } catch (e) {
      debugPrint('❌ Exception during mock callback: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
