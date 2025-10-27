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

    // Send notification to admin
    if (_notificationProvider != null) {
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
        updateStatus(orderId, OrderStatus.confirmed);
        
        // Send notification to customer
        if (_notificationProvider != null) {
          _notificationProvider!.addNotification(AppNotification(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            userId: order.customerId,
            title: 'Order Confirmed',
            message: 'Your order #$orderId has been confirmed and is being prepared',
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

  void updateStatus(String orderId, OrderStatus newStatus) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index == -1) return;

    final order = _orders[index];
    final oldStatus = order.status;
    
    _orders[index] = order.copyWith(status: newStatus);
    notifyListeners();

    // UPDATED: Send notification when status changes
    if (_notificationProvider != null && oldStatus != newStatus) {
      _sendOrderStatusNotification(order, newStatus);
    }
  }

  // UPDATED: More detailed status messages for simplified flow
  void _sendOrderStatusNotification(Order order, OrderStatus newStatus) {
    if (_notificationProvider == null) return;

    String title = '';
    String message = '';

    switch (newStatus) {
      case OrderStatus.pending:
        title = 'Order Received';
        message = 'Your order #${order.id} has been received and is pending confirmation.';
        break;
      case OrderStatus.confirmed:
        title = 'Order Confirmed!';
        message = 'Your order #${order.id} has been confirmed and will be prepared shortly.';
        break;
      case OrderStatus.inProgress:
        title = 'Order In Preparation!';
        message = 'Your order #${order.id} is being prepared by our kitchen.';
        break;
      case OrderStatus.delivered:
        title = 'Order Delivered!';
        message = 'Your order #${order.id} has been delivered successfully. Enjoy your meal!';
        break;
      case OrderStatus.cancelled:
        title = 'Order Cancelled';
        message = 'Your order #${order.id} has been cancelled.';
        break;
    }

    final notification = AppNotification(
      id: _notificationProvider!.generateNotificationId(),
      userId: order.customerId,
      title: title,
      message: message,
      type: 'order_update',
      timestamp: DateTime.now(),
      isRead: false,
      data: {'orderId': order.id, 'status': newStatus.toString()},
    );

    _notificationProvider!.addNotification(notification);
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
    
    debugPrint('✅ Assigning rider $riderName (ID: $riderId) to order $orderId');
    
    // Create updated order with rider info and status changed to inProgress
    _orders[index] = Order(
      id: order.id,
      customerId: order.customerId,
      customerName: order.customerName,
      deliveryPhone: order.deliveryPhone,
      date: order.date,
      items: order.items,
      totalAmount: order.totalAmount,
      status: OrderStatus.inProgress, // UPDATED: Change status to inProgress
      deliveryType: order.deliveryType,
      deliveryAddress: order.deliveryAddress,
      riderId: riderId, // ADDED: Set rider ID
      riderName: riderName, // ADDED: Set rider name
      cancellationReason: order.cancellationReason,
    );

    notifyListeners(); // IMPORTANT: Notify listeners to update UI
    
    debugPrint('✅ Order $orderId status updated to inProgress with rider $riderName');

    // Send notification to rider
    if (_notificationProvider != null) {
      _notificationProvider!.addNotification(AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: riderId,
        title: 'New Delivery Assignment',
        message: 'Order #$orderId has been assigned to you',
        type: 'order_update',
        timestamp: DateTime.now(),
        data: {'orderId': orderId},
      ));
    }

    // Send notification to customer
    if (_notificationProvider != null) {
      _notificationProvider!.addNotification(AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: order.customerId,
        title: 'Rider Assigned',
        message: riderId == 'admin' 
            ? 'Your order is being prepared for in-house delivery'
            : 'Rider $riderName has been assigned to your order',
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
}
