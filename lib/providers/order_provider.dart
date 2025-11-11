// lib/providers/order_provider.dart
import 'package:flutter/material.dart';
import '../models/order.dart'; // CHANGED: Import Order from model
import 'dart:math';
import 'notification_provider.dart';
import '../models/notification_model.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderProvider extends ChangeNotifier {
  final List<Order> _orders = [];
  NotificationProvider? _notificationProvider;
  final Map<String, Timer> _autoConfirmTimers = {}; // ADDED: Track auto-confirm timers
  final Set<String> _viewedPendingOrders = {}; // ADDED: Track viewed orders

  // ADDED: Set notification provider reference
  void setNotificationProvider(NotificationProvider provider) {
    _notificationProvider = provider;
  }

  List<Order> get orders => List.unmodifiable(_orders);

  // UPDATED: Get ALL orders for a specific rider (including completed)
  List<Order> ordersForRider(String riderId) {
    return _orders.where((order) => 
      order.riderId == riderId
    ).toList();
  }

  // ADDED: Get active orders for rider (not delivered/cancelled)
  List<Order> activeOrdersForRider(String riderId) {
    return _orders.where((order) => 
      order.riderId == riderId &&
      order.status != OrderStatus.delivered &&
      order.status != OrderStatus.cancelled
    ).toList();
  }

  // ADDED: Get completed orders for rider
  List<Order> completedOrdersForRider(String riderId) {
    return _orders.where((order) => 
      order.riderId == riderId &&
      (order.status == OrderStatus.delivered || order.status == OrderStatus.cancelled)
    ).toList();
  }

  // REMOVED: seedDemo method - no more fake data!

  // UPDATED: Add order and save to Supabase
  Future<void> addOrder(Order order) async {
    try {
      debugPrint('💾 Saving order ${order.id} to Supabase...');
      
      // Save order to Supabase
      await Supabase.instance.client.from('orders').insert({
        'id': order.id,
        'user_auth_id': order.customerId,
        'status': order.status.name,
        'subtotal': order.subtotal,
        'delivery_fee': order.deliveryFee,
        'tax': order.tax,
        'total': order.totalAmount,
        'delivery_address': order.deliveryAddress,
        'placed_at': order.date.toIso8601String(),
      });

      // Save order items
      for (final item in order.items) {
        await Supabase.instance.client.from('order_items').insert({
          'order_id': order.id,
          'product_id': item.id,
          'name': item.title,
          'quantity': item.quantity,
          'unit_price': item.price,
          'total_price': item.totalPrice,
        });
      }

      debugPrint('✅ Order ${order.id} saved to database');

      // Add to local list
      _orders.add(order);
      notifyListeners();

      // Start auto-confirmation timer
      if (order.status == OrderStatus.pending) {
        _startAutoConfirmTimer(order.id);
      }

      // Send notifications
      if (_notificationProvider != null && order.status != OrderStatus.cancelled) {
        _notificationProvider!.addNotification(AppNotification(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: order.customerId,
          title: 'Order Placed',
          message: 'Your order #${order.id} has been placed successfully',
          type: 'order_update',
          timestamp: DateTime.now(),
          data: {'orderId': order.id},
        ));

        _notificationProvider!.addNotification(AppNotification(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: 'admin',
          title: 'New Order',
          message: 'New order #${order.id} from ${order.customerName}',
          type: 'new_order',
          timestamp: DateTime.now(),
          data: {'orderId': order.id},
        ));
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to save order: $e');
      debugPrint('Stack: $stackTrace');
      rethrow;
    }
  }

  // UPDATED: Load orders from Supabase
  Future<void> loadOrders(String userId) async {
    try {
      debugPrint('📥 Loading orders for user: $userId');
      
      final data = await Supabase.instance.client
          .from('orders')
          .select('*, order_items(*)')
          .eq('user_auth_id', userId)
          .order('placed_at', ascending: false);

      _orders.clear();
      for (final json in data as List) {
        final order = Order.fromJson(json);
        
        // Load order items
        final items = (json['order_items'] as List).map((item) => OrderItem(
          id: item['product_id'] ?? item['id'],
          title: item['name'],
          quantity: item['quantity'],
          price: (item['unit_price'] as num).toInt(),
        )).toList();

        _orders.add(order.copyWith(items: items));
      }
      
      debugPrint('✅ Loaded ${_orders.length} orders');
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to load orders: $e');
      debugPrint('Stack: $stackTrace');
    }
  }

  // UPDATED: Update status in Supabase - REMOVED incorrect @override
  Future<void> updateStatus(String orderId, OrderStatus newStatus) async {
    try {
      final index = _orders.indexWhere((o) => o.id == orderId);
      if (index == -1) {
        debugPrint('❌ Order $orderId not found');
        return;
      }

      final order = _orders[index];
      
      // Update in Supabase
      final Map<String, dynamic> updateData = {
        'status': newStatus.name,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Set delivered_at or cancelled_at timestamps
      if (newStatus == OrderStatus.delivered) {
        updateData['delivered_at'] = DateTime.now().toIso8601String();
      } else if (newStatus == OrderStatus.cancelled) {
        updateData['cancelled_at'] = DateTime.now().toIso8601String();
      }

      await Supabase.instance.client
          .from('orders')
          .update(updateData)
          .eq('id', orderId);

      debugPrint('✅ Order $orderId status updated to $newStatus in database');

      // Update local order
      _orders[index] = order.copyWith(
        status: newStatus,
        deliveredAt: newStatus == OrderStatus.delivered ? DateTime.now() : order.deliveredAt,
        cancelledAt: newStatus == OrderStatus.cancelled ? DateTime.now() : order.cancelledAt,
      );

      notifyListeners();
      _sendOrderStatusNotification(orderId, newStatus);
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to update order status: $e');
      debugPrint('Stack: $stackTrace');
    }
  }

  // ADDED: Start auto-confirmation timer
  void _startAutoConfirmTimer(String orderId) {
    // Cancel existing timer if any
    _autoConfirmTimers[orderId]?.cancel();
    
    // Create new timer
    _autoConfirmTimers[orderId] = Timer(const Duration(minutes: 5), () {
      final orderIndex = _orders.indexWhere((o) => o.id == orderId);
      if (orderIndex == -1) {
        debugPrint('❌ Order $orderId not found for auto-confirmation');
        return;
      }

      final order = _orders[orderIndex];
      
      // Only auto-confirm if still pending (not cancelled by customer)
      if (order.status == OrderStatus.pending) {
        debugPrint('⏰ Auto-confirming order $orderId after 5 minutes');
        updateStatus(orderId, OrderStatus.confirmed);
        
        // Send notification to customer
        if (_notificationProvider != null) {
          _notificationProvider!.addNotification(AppNotification(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            userId: order.customerId,
            title: 'Order Confirmed',
            message: 'Your order #$orderId has been confirmed and will be prepared soon',
            type: 'order_update',
            timestamp: DateTime.now(),
            data: {'orderId': orderId},
          ));
        }
      }
      
      // Clean up timer
      _autoConfirmTimers.remove(orderId);
    });
  }

  // ADDED: Send order status notification helper
  void _sendOrderStatusNotification(String orderId, OrderStatus newStatus) {
    if (_notificationProvider == null) return;

    final order = _orders.firstWhere((o) => o.id == orderId, orElse: () => _orders.first);
    
    String title = '';
    String message = '';

    switch (newStatus) {
      case OrderStatus.confirmed:
        title = 'Order Confirmed';
        message = 'Your order #$orderId has been confirmed';
        break;
      case OrderStatus.preparing:
        title = 'Order Being Prepared';
        message = 'The kitchen is preparing your order #$orderId';
        break;
      case OrderStatus.outForDelivery:
        title = 'Out for Delivery';
        message = 'Your order #$orderId is on its way!';
        break;
      case OrderStatus.delivered:
        title = 'Order Delivered';
        message = 'Your order #$orderId has been delivered. Enjoy!';
        break;
      case OrderStatus.cancelled:
        title = 'Order Cancelled';
        message = 'Your order #$orderId has been cancelled';
        break;
      default:
        return;
    }

    _notificationProvider!.addNotification(AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: order.customerId,
      title: title,
      message: message,
      type: 'order_update',
      timestamp: DateTime.now(),
      data: {'orderId': orderId},
    ));
  }

  // ADDED: Cancel order with reason
  void cancelOrder(String orderId, String reason) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index == -1) {
      debugPrint('❌ Order $orderId not found');
      return;
    }

    final order = _orders[index];
    
    // ADDED: Cancel auto-confirm timer
    _autoConfirmTimers[orderId]?.cancel();
    _autoConfirmTimers.remove(orderId);
    
    debugPrint('❌ Cancelling order $orderId with reason: $reason');
    
    _orders[index] = Order(
      id: order.id,
      customerId: order.customerId,
      customerName: order.customerName,
      deliveryPhone: order.deliveryPhone,
      date: order.date,
      items: order.items,
      subtotal: order.subtotal, // FIXED: Added required field
      deliveryFee: order.deliveryFee, // FIXED: Added required field
      tax: order.tax, // FIXED: Added required field
      totalAmount: order.totalAmount,
      status: OrderStatus.cancelled,
      deliveryType: order.deliveryType,
      deliveryAddress: order.deliveryAddress,
      riderId: order.riderId,
      riderName: order.riderName,
      cancellationReason: reason,
      cancelledAt: DateTime.now(), // FIXED: Set cancellation timestamp
    );

    notifyListeners();
    
    // Send notification to customer
    if (_notificationProvider != null) {
      _notificationProvider!.addNotification(
        AppNotification(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: 'Order Cancelled',
          message: 'Your order $orderId has been cancelled. Reason: $reason',
          userId: order.customerId,
          timestamp: DateTime.now(),
          type: 'order_cancelled',
        ),
      );
    }
  }

  List<Order> ordersForCustomer(String customerId) {
    return _orders.where((o) => o.customerId == customerId).toList();
  }

  List<Order> ordersByStatus(OrderStatus status) {
    return _orders.where((o) => o.status == status).toList();
  }

  // Fixed: avoid using firstWhere(orElse: () => null) which is invalid.
  Order? getById(String id) {
    final idx = _orders.indexWhere((o) => o.id == id);
    if (idx == -1) return null;
    return _orders[idx];
  }

  String generateOrderId() {
    final rnd = Random().nextInt(9999);
    final ts = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    return 'ORD-${ts + rnd}';
  }

  // ADDED: Rate an individual order item
  void rateOrderItem(String orderId, String itemId, int rating, String review) {
    final orderIndex = _orders.indexWhere((o) => o.id == orderId);
    if (orderIndex != -1) {
      final order = _orders[orderIndex];
      final itemIndex = order.items.indexWhere((i) => i.id == itemId);
      
      if (itemIndex != -1) {
        // Update the item with rating and review
        final updatedItems = List<OrderItem>.from(order.items);
        updatedItems[itemIndex] = OrderItem(
          id: order.items[itemIndex].id,
          title: order.items[itemIndex].title,
          quantity: order.items[itemIndex].quantity,
          price: order.items[itemIndex].price,
          rating: rating,
          review: review,
        );
        
        // Create updated order
        _orders[orderIndex] = Order(
          id: order.id,
          customerId: order.customerId,
          customerName: order.customerName,
          date: order.date,
          items: updatedItems,
          subtotal: order.subtotal, // FIXED: Added required field
          deliveryFee: order.deliveryFee, // FIXED: Added required field
          tax: order.tax, // FIXED: Added required field
          totalAmount: order.totalAmount,
          status: order.status,
          deliveryType: order.deliveryType,
          deliveryAddress: order.deliveryAddress,
          deliveryPhone: order.deliveryPhone,
          riderId: order.riderId,
          riderName: order.riderName,
        );
        
        notifyListeners();
      }
    }
  }

  // UPDATED: Assign to rider - FIXED to include all required fields
  void assignToRider(String orderId, String riderId, String riderName) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index == -1) {
      debugPrint('❌ Order $orderId not found');
      return;
    }

    final order = _orders[index];
    
    _orders[index] = Order(
      id: order.id,
      customerId: order.customerId,
      customerName: order.customerName,
      deliveryPhone: order.deliveryPhone,
      date: order.date,
      items: order.items,
      subtotal: order.subtotal, // FIXED: Added required field
      deliveryFee: order.deliveryFee, // FIXED: Added required field
      tax: order.tax, // FIXED: Added required field
      totalAmount: order.totalAmount,
      status: OrderStatus.outForDelivery,
      deliveryType: order.deliveryType,
      deliveryAddress: order.deliveryAddress,
      riderId: riderId,
      riderName: riderName,
      cancellationReason: order.cancellationReason,
    );

    debugPrint('✅ Order $orderId assigned to rider $riderId ($riderName) - Status: outForDelivery');
    notifyListeners();

    // Send notifications
    if (_notificationProvider != null) {
      _notificationProvider!.addNotification(AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: riderId,
        title: 'New Delivery Assignment',
        message: 'Order #$orderId has been assigned to you',
        type: 'new_delivery',
        timestamp: DateTime.now(),
        data: {'orderId': orderId},
      ));

      _notificationProvider!.addNotification(AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: order.customerId,
        title: 'Order Out for Delivery',
        message: 'Your order #$orderId is on its way!',
        type: 'order_update',
        timestamp: DateTime.now(),
        data: {'orderId': orderId},
      ));
    }
  }

  // ADDED: Clean up timers on dispose
  @override
  void dispose() {
    for (var timer in _autoConfirmTimers.values) {
      timer.cancel();
    }
    _autoConfirmTimers.clear();
    super.dispose();
  }

  // ADDED: Get unviewed pending orders count (excludes cancelled)
  int get unviewedPendingOrdersCount {
    return _orders
        .where((o) => 
            o.status == OrderStatus.pending && 
            !_viewedPendingOrders.contains(o.id))
        .length;
  }

  // ADDED: Mark all current pending orders as viewed
  void markPendingOrdersAsViewed() {
    final pendingOrders = _orders.where((o) => o.status == OrderStatus.pending);
    for (final order in pendingOrders) {
      _viewedPendingOrders.add(order.id);
    }
    debugPrint('✅ Marked ${pendingOrders.length} pending orders as viewed');
    notifyListeners();
  }

  Future<void> createOrder({
    required List<OrderItem> items,
    required DeliveryType deliveryType,
    required int totalAmount,
    required String customerId, // This should be auth_id
    required String customerName,
    String? deliveryAddress,
    String? specialInstructions,
  }) async {
    try {
      // VERIFY: customerId is the UUID from auth.users.id (not email)
      final orderId = 'ORD-${DateTime.now().millisecondsSinceEpoch}';
      
      // Insert into Supabase orders table
      await Supabase.instance.client.from('orders').insert({
        'id': orderId,
        'user_auth_id': customerId, // CHANGED: use user_auth_id (FK to public.users.auth_id)
        'customer_name': customerName,
        'total_amount': totalAmount,
        'status': 'pending',
        'delivery_type': deliveryType.name,
        'delivery_address': deliveryAddress,
        'special_instructions': specialInstructions,
        'created_at': DateTime.now().toIso8601String(),
      });

      // ...existing order items insertion...
      
    } catch (e) {
      debugPrint('❌ Order creation failed: $e');
      rethrow;
    }
  }

  // REMOVED: Order class definition (now imported from models/order.dart)
}
