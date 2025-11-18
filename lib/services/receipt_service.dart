// lib/services/receipt_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/receipt.dart';

class ReceiptService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch receipt by order ID
  Future<Receipt?> getReceiptByOrderId(String orderId) async {
    try {
      // First get the transaction for this order
      final transactionResponse = await _supabase
          .from('mpesa_transactions')
          .select('transaction_id')
          .eq('order_id', orderId)
          .eq('status', 'completed')
          .maybeSingle();

      if (transactionResponse == null) {
        return null;
      }

      final transactionId = transactionResponse['transaction_id'] as String;
      
      // Fetch receipt with items
      final response = await _supabase
          .from('receipts')
          .select('''
            *,
            receipt_items (*)
          ''')
          .eq('transaction_id', transactionId)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return Receipt.fromJson(response);
    } catch (e) {
      print('Error fetching receipt by order ID: $e');
      return null;
    }
  }

  /// Fetch receipt by transaction ID
  Future<Receipt?> getReceiptByTransactionId(String transactionId) async {
    try {
      final response = await _supabase
          .from('receipts')
          .select('''
            *,
            receipt_items (*)
          ''')
          .eq('transaction_id', transactionId)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return Receipt.fromJson(response);
    } catch (e) {
      print('Error fetching receipt by transaction ID: $e');
      return null;
    }
  }

  /// Fetch receipt by receipt number
  Future<Receipt?> getReceiptByNumber(String receiptNumber) async {
    try {
      final response = await _supabase
          .from('receipts')
          .select('''
            *,
            receipt_items (*)
          ''')
          .eq('receipt_number', receiptNumber)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return Receipt.fromJson(response);
    } catch (e) {
      print('Error fetching receipt by number: $e');
      return null;
    }
  }

  /// Fetch all receipts for current user
  Future<List<Receipt>> getUserReceipts() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return [];
      }

      // Get user's transactions
      final transactionsResponse = await _supabase
          .from('mpesa_transactions')
          .select('transaction_id')
          .eq('user_auth_id', userId)
          .eq('status', 'completed');

      if (transactionsResponse.isEmpty) {
        return [];
      }

      final transactionIds = (transactionsResponse as List)
          .map((t) => t['transaction_id'] as String)
          .toList();

      // Fetch receipts for these transactions
      final response = await _supabase
          .from('receipts')
          .select('''
            *,
            receipt_items (*)
          ''')
          .inFilter('transaction_id', transactionIds)
          .order('issue_date', ascending: false);

      return (response as List)
          .map((json) => Receipt.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching user receipts: $e');
      return [];
    }
  }

  /// Mark receipt as printed
  Future<bool> markAsPrinted(String receiptId) async {
    try {
      await _supabase
          .from('receipts')
          .update({
            'is_printed': true,
            'printed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', receiptId);
      
      return true;
    } catch (e) {
      print('Error marking receipt as printed: $e');
      return false;
    }
  }
}
