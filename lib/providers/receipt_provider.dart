import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/receipt.dart';
import '../services/receipt_service.dart';

class ReceiptProvider with ChangeNotifier {
  final ReceiptService _receiptService = ReceiptService();
  final SupabaseClient _supabase = Supabase.instance.client;

  // Cache of receipts by transaction ID for quick lookup
  final Map<String, Receipt> _receiptCache = {};
  
  // Cache of receipts by order ID for quick lookup
  final Map<String, Receipt> _receiptsByOrder = {};
  
  // List of all user receipts (for history screen)
  List<Receipt> _receipts = [];
  
  // Stream subscriptions
  final Map<String, StreamSubscription> _subscriptions = {};
  StreamSubscription? _userReceiptsSubscription;
  
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Receipt> get receipts => List.unmodifiable(_receipts);

  /// Get receipt by transaction ID from cache or fetch
  Receipt? getReceiptByTransactionId(String transactionId) {
    return _receiptCache[transactionId];
  }

  /// Get receipt by order ID from cache or fetch
  Receipt? getReceiptByOrderId(String orderId) {
    return _receiptsByOrder[orderId];
  }

  /// Check if receipt exists for order
  bool hasReceiptForOrder(String orderId) {
    return _receiptsByOrder.containsKey(orderId);
  }

  /// Load receipt for specific order with realtime updates
  /// Returns true if receipt exists immediately, false if waiting
  Future<bool> loadReceiptForOrder(String orderId) async {
    debugPrint('🧾 Loading receipt for order: $orderId');

    // First check cache
    if (_receiptsByOrder.containsKey(orderId)) {
      debugPrint('✅ Receipt found in cache');
      return true;
    }

    // Try to fetch from database
    try {
      final receipt = await _receiptService.getReceiptByOrderId(orderId);
      
      if (receipt != null) {
        debugPrint('✅ Receipt loaded: ${receipt.receiptNumber}');
        _addToCache(receipt, orderId);
        notifyListeners();
        return true;
      }

      debugPrint('⏳ No receipt yet, setting up realtime listener...');
      
      // Set up realtime listener for this order's receipt
      await _listenForReceiptByOrder(orderId);
      
      return false;
    } catch (e) {
      debugPrint('❌ Error loading receipt: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Listen for receipt creation for a specific order in realtime
  Future<void> _listenForReceiptByOrder(String orderId) async {
    // Cancel existing subscription for this order
    _subscriptions['order_$orderId']?.cancel();

    try {
      // First get the transaction ID for this order
      final transactionResponse = await _supabase
          .from('mpesa_transactions')
          .select('transaction_id')
          .eq('order_id', orderId)
          .eq('status', 'completed')
          .maybeSingle();

      if (transactionResponse == null) {
        debugPrint('⚠️ No completed transaction found for order $orderId');
        return;
      }

      final transactionId = transactionResponse['transaction_id'] as String;
      debugPrint('📡 Listening for receipt with transaction ID: $transactionId');

      // Listen to receipts table for this transaction
      _subscriptions['order_$orderId'] = _supabase
          .from('receipts')
          .stream(primaryKey: ['id'])
          .eq('transaction_id', transactionId)
          .listen(
        (data) {
          debugPrint('📥 Receipt stream update: ${data.length} receipts');
          
          if (data.isNotEmpty) {
            final receiptData = data.first;
            
            // Fetch full receipt with items
            _fetchFullReceipt(receiptData['id'] as String, orderId);
          }
        },
        onError: (error) {
          debugPrint('❌ Receipt stream error: $error');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('❌ Error setting up receipt listener: $e');
    }
  }

  /// Fetch full receipt details including items
  Future<void> _fetchFullReceipt(String receiptId, String? orderId) async {
    try {
      final response = await _supabase
          .from('receipts')
          .select('''
            *,
            receipt_items (*)
          ''')
          .eq('id', receiptId)
          .single();

      final receipt = Receipt.fromJson(response);
      debugPrint('✅ Receipt generated: ${receipt.receiptNumber}');
      
      _addToCache(receipt, orderId);
      notifyListeners();
      
      // Cancel subscription after receipt is received
      _subscriptions['order_$orderId']?.cancel();
      _subscriptions.remove('order_$orderId');
    } catch (e) {
      debugPrint('❌ Error fetching full receipt: $e');
    }
  }

  /// Add receipt to cache
  void _addToCache(Receipt receipt, String? orderId) {
    _receiptCache[receipt.transactionId] = receipt;
    
    if (orderId != null) {
      _receiptsByOrder[orderId] = receipt;
    }
    
    // Add to receipts list if not already there
    final index = _receipts.indexWhere((r) => r.id == receipt.id);
    if (index == -1) {
      _receipts.insert(0, receipt); // Add to beginning (most recent first)
    } else {
      _receipts[index] = receipt; // Update existing
    }
  }

  /// Load all receipts for current user with realtime updates
  Future<void> loadUserReceipts() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('❌ No user logged in');
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('📥 Loading user receipts...');
      
      // Load initial receipts
      _receipts = await _receiptService.getUserReceipts();
      
      // Populate caches
      for (final receipt in _receipts) {
        _receiptCache[receipt.transactionId] = receipt;
        
        // Get order ID for this receipt's transaction
        try {
          final txResponse = await _supabase
              .from('mpesa_transactions')
              .select('order_id')
              .eq('transaction_id', receipt.transactionId)
              .maybeSingle();
          
          if (txResponse != null) {
            final orderId = txResponse['order_id'] as String;
            _receiptsByOrder[orderId] = receipt;
          }
        } catch (e) {
          debugPrint('⚠️ Could not map receipt to order: $e');
        }
      }
      
      debugPrint('✅ Loaded ${_receipts.length} receipts');
      
      // Set up realtime listener for new receipts
      _listenToUserReceipts(userId);
      
      _isLoading = false;
      _error = null;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading receipts: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Listen to new receipts for current user in realtime
  void _listenToUserReceipts(String userId) {
    _userReceiptsSubscription?.cancel();

    // Get user's transaction IDs
    _supabase
        .from('mpesa_transactions')
        .select('transaction_id')
        .eq('user_auth_id', userId)
        .eq('status', 'completed')
        .then((transactions) {
      if (transactions.isEmpty) return;

      final transactionIds = (transactions as List)
          .map((t) => t['transaction_id'] as String)
          .toList();

      // Listen for new receipts
      _userReceiptsSubscription = _supabase
          .from('receipts')
          .stream(primaryKey: ['id'])
          .inFilter('transaction_id', transactionIds)
          .listen(
        (data) {
          debugPrint('📥 User receipts stream update: ${data.length} receipts');
          
          for (final receiptData in data) {
            final receiptId = receiptData['id'] as String;
            
            // Check if we already have this receipt
            final exists = _receipts.any((r) => r.id == receiptId);
            if (!exists) {
              // Fetch full receipt with items
              _fetchFullReceipt(receiptId, null);
            }
          }
        },
        onError: (error) {
          debugPrint('❌ User receipts stream error: $error');
        },
        cancelOnError: false,
      );
    }).catchError((e) {
      debugPrint('❌ Error setting up user receipts listener: $e');
    });
  }

  /// Manually refresh receipt for order (fallback for polling)
  Future<bool> refreshReceiptForOrder(String orderId) async {
    try {
      final receipt = await _receiptService.getReceiptByOrderId(orderId);
      
      if (receipt != null) {
        _addToCache(receipt, orderId);
        notifyListeners();
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('❌ Error refreshing receipt: $e');
      return false;
    }
  }

  /// Mark receipt as printed
  Future<bool> markAsPrinted(String receiptId) async {
    try {
      final success = await _receiptService.markAsPrinted(receiptId);
      
      if (success) {
        // Update cache by reloading the receipt
        if (_receipts.any((r) => r.id == receiptId)) {
          // Recreate receipt with updated isPrinted flag
          // (Since Receipt is immutable, we need to create a new instance)
          // For now, just reload the receipt
          await _fetchFullReceipt(receiptId, null);
        }
        
        notifyListeners();
      }
      
      return success;
    } catch (e) {
      debugPrint('❌ Error marking receipt as printed: $e');
      return false;
    }
  }

  /// Clear cache and subscriptions
  void clear() {
    _receiptCache.clear();
    _receiptsByOrder.clear();
    _receipts.clear();
    
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    
    _userReceiptsSubscription?.cancel();
    _userReceiptsSubscription = null;
    
    _isLoading = false;
    _error = null;
    
    notifyListeners();
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _userReceiptsSubscription?.cancel();
    super.dispose();
  }
}
