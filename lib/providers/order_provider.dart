// lib/providers/order_provider.dart
import 'package:flutter/material.dart';
import '../models/order.dart';
import 'dart:math';
import 'notification_provider.dart';
import '../models/notification_model.dart'; // ADDED: Import AppNotification model
import 'dart:async'; // ADDED: Import async for Timer

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

  // For demo: seed some data
  void seedDemo({String? customerId}) {
    if (_orders.isNotEmpty) return;
    final now = DateTime.now();
    _orders.addAll([
      Order(
        id: 'ord001',
        customerId: customerId ?? 'cust1',
        customerName: 'Jane Doe',
        date: now.subtract(const Duration(days: 2)),
        items: [OrderItem(id: 'i1', title: 'Burger', quantity: 1, price: 500)],
        totalAmount: 500,
        status: OrderStatus.confirmed,
        deliveryType: DeliveryType.delivery,
      ),
      Order(
        id: 'ord002',
        customerId: customerId ?? 'cust2',
        customerName: 'John Smith',
        date: now.subtract(const Duration(days: 5)),
        items: [OrderItem(id: 'i2', title: 'Fries', quantity: 2, price: 200)],
        totalAmount: 400,
        status: OrderStatus.delivered,
        deliveryType: DeliveryType.pickup,
      ),
    ]);
    notifyListeners();
  }

  void addOrder(Order order) {
    _orders.add(order);
    notifyListeners();

    debugPrint('✅ Order ${order.id} added with status: ${order.status}');

    // ADDED: Start auto-confirmation timer for pending orders
    if (order.status == OrderStatus.pending) {
      _startAutoConfirmTimer(order.id);
    }

    // Send notification to customer
    if (_notificationProvider != null) {
      _notificationProvider!.addNotification(AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: order.customerId,
        title: 'Order Placed',
        message: 'Your order #${order.id} has been placed successfully',
        type: 'order_update',
        timestamp: DateTime.now(),
        data: {'orderId': order.id},
      ));
    }

    // UPDATED: Only send notification to admin if NOT cancelled
    if (_notificationProvider != null && order.status != OrderStatus.cancelled) {
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
        updateStatus(orderId, OrderStatus.confirmed); // UPDATED: Set to confirmed
        
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

  // UPDATED: Send order status notification helper
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
      case OrderStatus.preparing: // UPDATED
        title = 'Order Being Prepared';
        message = 'The kitchen is preparing your order #$orderId';
        break;
      case OrderStatus.outForDelivery: // UPDATED
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

  void updateStatus(String orderId, OrderStatus newStatus) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index == -1) {
      debugPrint('❌ Order $orderId not found');
      return;
    }

    final order = _orders[index];
    final oldStatus = order.status;

    // UPDATED: Handle preparing and outForDelivery statuses
    if (oldStatus == OrderStatus.pending && newStatus != OrderStatus.confirmed && newStatus != OrderStatus.cancelled) {
      debugPrint('❌ Cannot change from pending to $newStatus directly');
      return;
    }

    _orders[index] = Order(
      id: order.id,
      customerId: order.customerId,
      customerName: order.customerName,
      deliveryPhone: order.deliveryPhone,
      date: order.date,
      items: order.items,
      totalAmount: order.totalAmount,
      status: newStatus,
      deliveryType: order.deliveryType,
      deliveryAddress: order.deliveryAddress,
      riderId: order.riderId,
      riderName: order.riderName,
      cancellationReason: order.cancellationReason,
    );

    debugPrint('✅ Order $orderId status updated: $oldStatus → $newStatus');
    notifyListeners();

    // UPDATED: Use the notification helper method
    _sendOrderStatusNotification(orderId, newStatus);
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
      totalAmount: order.totalAmount,
      status: OrderStatus.cancelled,
      deliveryType: order.deliveryType,
      deliveryAddress: order.deliveryAddress,
      riderId: order.riderId,
      riderName: order.riderName,
      cancellationReason: reason, // ADDED: Store reason
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

  // ADDED/FIXED: Assign rider to order and update status to inProgress
  void assignToRider(String orderId, String riderId, String riderName) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index == -1) {
      debugPrint('❌ Order $orderId not found');
      return;
    }

    final order = _orders[index];
    
    // UPDATED: Change status to outForDelivery when assigned to rider
    _orders[index] = Order(
      id: order.id,
      customerId: order.customerId,
      customerName: order.customerName,
      deliveryPhone: order.deliveryPhone,
      date: order.date,
      items: order.items,
      totalAmount: order.totalAmount,
      status: OrderStatus.outForDelivery, // UPDATED: New status
      deliveryType: order.deliveryType,
      deliveryAddress: order.deliveryAddress,
      riderId: riderId,
      riderName: riderName,
      cancellationReason: order.cancellationReason,
    );

    debugPrint('✅ Order $orderId assigned to rider $riderId ($riderName) - Status: outForDelivery');
    notifyListeners();

    // Send notification to rider
    if (_notificationProvider != null) {
      _notificationProvider!.addNotification(AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: riderId, // FIXED: Send to correct rider ID
        title: 'New Delivery Assignment',
        message: 'Order #$orderId has been assigned to you',
        type: 'new_delivery',
        timestamp: DateTime.now(),
        data: {'orderId': orderId},
      ));
    }

    // Send notification to customer
    if (_notificationProvider != null) {
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
}
