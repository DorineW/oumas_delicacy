import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order.dart' as order_model;

class RiderProvider with ChangeNotifier {
  List<order_model.Order> _orders = [];
  bool _isLoading = false;
  String? _error;

  List<order_model.Order> get orders => List.unmodifiable(_orders);
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Get orders assigned to this rider
  List<order_model.Order> ordersForRider(String riderId) {
    return _orders.where((o) => o.riderId == riderId).toList();
  }

  // Active orders (not delivered/cancelled)
  List<order_model.Order> activeOrdersForRider(String riderId) {
    return _orders.where((o) => 
      o.riderId == riderId &&
      o.status != order_model.OrderStatus.delivered &&
      o.status != order_model.OrderStatus.cancelled
    ).toList();
  }

  // Completed orders
  List<order_model.Order> completedOrdersForRider(String riderId) {
    return _orders.where((o) => 
      o.riderId == riderId &&
      (o.status == order_model.OrderStatus.delivered || 
       o.status == order_model.OrderStatus.cancelled)
    ).toList();
  }

  // Today's orders
  List<order_model.Order> todayOrdersForRider(String riderId) {
    final now = DateTime.now();
    return _orders.where((o) => 
      o.riderId == riderId &&
      o.date.day == now.day &&
      o.date.month == now.month &&
      o.date.year == now.year
    ).toList();
  }

  // Statistics
  int totalDeliveriesToday(String riderId) {
    return todayOrdersForRider(riderId)
        .where((o) => o.status == order_model.OrderStatus.delivered)
        .length;
  }

  double todayEarnings(String riderId) {
    return todayOrdersForRider(riderId)
        .where((o) => o.status == order_model.OrderStatus.delivered)
        .fold(0.0, (sum, order) => sum + (order.totalAmount * 0.1)); // 10% commission
  }

  // MAIN: Load orders from Supabase with detailed debugging (same pattern as MenuProvider)
  Future<void> loadOrdersForRider(String riderId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('🔄 Starting to load orders for rider: $riderId from Supabase...');
      
      final supabase = Supabase.instance.client;
      debugPrint('✅ Supabase client initialized');
      
      // Query orders assigned to this rider with all columns explicitly
      final response = await supabase
          .from('orders')
          .select('''
            id,
            user_auth_id,
            delivery_phone,
            placed_at,
            subtotal,
            delivery_fee,
            tax,
            total,
            status,
            delivery_address,
            rider_id,
            rider_name,
            cancellation_reason,
            delivered_at,
            cancelled_at
          ''')
          .eq('rider_id', riderId)
          .order('placed_at', ascending: false);

      debugPrint('✅ Query executed successfully');
      debugPrint('📊 Response type: ${response.runtimeType}');
      debugPrint('📏 Number of orders fetched: ${response.length}');

      if (response.isEmpty) {
        debugPrint('⚠️ No orders found for rider $riderId');
        _orders = [];
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Parse each order with error handling
      final orders = <order_model.Order>[];
      for (var i = 0; i < response.length; i++) {
        try {
          final json = response[i];
          debugPrint('--- Parsing order ${i + 1}/${response.length} ---');
          debugPrint('Raw JSON: $json');
          
          // Parse order (without items first)
          final order = order_model.Order.fromJson(json);
          
          // Load order items separately
          final itemsResponse = await supabase
              .from('order_items')
              .select('id, product_id, name, quantity, unit_price, total_price')
              .eq('order_id', order.id);

          debugPrint('📦 Loading items for order ${order.id}');
          debugPrint('Items response: $itemsResponse');

          final items = <order_model.OrderItem>[];
          for (final itemJson in itemsResponse) {
            try {
              final item = order_model.OrderItem(
                id: itemJson['product_id'] ?? itemJson['id'],
                title: itemJson['name'],
                quantity: itemJson['quantity'],
                price: (itemJson['unit_price'] as num).toInt(),
              );
              items.add(item);
              debugPrint('  ✅ Item: ${item.title} x${item.quantity}');
            } catch (e) {
              debugPrint('  ❌ Error parsing item: $e');
            }
          }

          // Add order with items
          final orderWithItems = order.copyWith(items: items);
          orders.add(orderWithItems);
          debugPrint('✅ Successfully parsed order: ${order.id} - KES ${order.totalAmount}');
        } catch (e, stackTrace) {
          debugPrint('❌ Error parsing order ${i + 1}: $e');
          debugPrint('Failed JSON: ${response[i]}');
          debugPrint('Stack: $stackTrace');
        }
      }

      _orders = orders;
      _error = null;
      debugPrint('🎉 Successfully loaded ${orders.length} orders for rider');
      
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading rider orders: $e');
      debugPrint('Stack trace: $stackTrace');
      _error = 'Failed to load orders: $e';
      _orders = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Refresh orders
  Future<void> refreshOrders(String riderId) async {
    await loadOrdersForRider(riderId);
  }

  // Update order status
  Future<void> updateOrderStatus(String orderId, order_model.OrderStatus newStatus) async {
    try {
      debugPrint('🔄 Updating order $orderId status to $newStatus');
      
      final Map<String, dynamic> updateData = {
        'status': newStatus.name,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Set delivered_at or cancelled_at timestamps
      if (newStatus == order_model.OrderStatus.delivered) {
        updateData['delivered_at'] = DateTime.now().toIso8601String();
      } else if (newStatus == order_model.OrderStatus.cancelled) {
        updateData['cancelled_at'] = DateTime.now().toIso8601String();
      }

      await Supabase.instance.client
          .from('orders')
          .update(updateData)
          .eq('id', orderId);

      debugPrint('✅ Order status updated in database');

      // Update local order
      final index = _orders.indexWhere((o) => o.id == orderId);
      if (index != -1) {
        _orders[index] = _orders[index].copyWith(
          status: newStatus,
          deliveredAt: newStatus == order_model.OrderStatus.delivered 
              ? DateTime.now() 
              : _orders[index].deliveredAt,
          cancelledAt: newStatus == order_model.OrderStatus.cancelled 
              ? DateTime.now() 
              : _orders[index].cancelledAt,
        );
        notifyListeners();
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to update order status: $e');
      debugPrint('Stack: $stackTrace');
      _error = 'Failed to update order: $e';
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
