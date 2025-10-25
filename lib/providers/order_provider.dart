// lib/providers/order_provider.dart
import 'package:flutter/material.dart';
import '../models/order.dart';
import 'dart:math';
import 'notification_provider.dart';
import '../models/notification_model.dart'; // ADDED: Import AppNotification model

class OrderProvider extends ChangeNotifier {
  final List<Order> _orders = [];
  NotificationProvider? _notificationProvider;

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

  Future<void> addOrder(Order order) async {
    _orders.add(order);
    notifyListeners();

    // UPDATED: Send notification to admin with real customer details
    if (_notificationProvider != null) {
      _notificationProvider!.addNotification(
        AppNotification(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: 'New Order Received',
          message: 'Order ${order.id} from ${order.customerName}${order.deliveryPhone != null ? " (${order.deliveryPhone})" : ""}', // UPDATED: Include phone
          userId: 'admin',
          timestamp: DateTime.now(),
          type: 'new_order',
          // REMOVED: orderId parameter (not in AppNotification model)
        ),
      );
    }
  }

  // FIXED: Assign rider to order and update status
  void assignToRider(String orderId, String riderId, String riderName) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index == -1) return;

    final order = _orders[index];
    
    // Create updated order with rider info and status
    _orders[index] = Order(
      id: order.id,
      customerId: order.customerId,
      customerName: order.customerName,
      deliveryPhone: order.deliveryPhone,
      date: order.date,
      items: order.items,
      totalAmount: order.totalAmount,
      status: OrderStatus.assigned, // FIXED: Change status to assigned
      deliveryType: order.deliveryType,
      deliveryAddress: order.deliveryAddress,
      riderId: riderId, // ADDED: Set rider ID
      riderName: riderName, // ADDED: Set rider name
      cancellationReason: order.cancellationReason,
    );

    notifyListeners();

    // FIXED: Send notification to rider using correct parameters
    if (_notificationProvider != null) {
      _notificationProvider!.addNotification(AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: riderId,
        title: 'New Delivery Assignment',
        message: 'Order #$orderId has been assigned to you',
        type: 'order_update', // FIXED: Use string instead of enum
        timestamp: DateTime.now(),
        data: {'orderId': orderId}, // FIXED: Use data parameter instead of relatedOrderId
      ));
    }

    // FIXED: Send notification to customer using correct parameters
    if (_notificationProvider != null) {
      _notificationProvider!.addNotification(AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: order.customerId,
        title: 'Rider Assigned',
        message: riderId == 'admin' 
            ? 'Your order is being prepared for in-house delivery'
            : 'Rider $riderName has been assigned to your order',
        type: 'order_update', // FIXED: Use string instead of enum
        timestamp: DateTime.now(),
        data: {'orderId': orderId}, // FIXED: Use data parameter instead of relatedOrderId
      ));
    }
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

  // UPDATED: More detailed status messages
  void _sendOrderStatusNotification(Order order, OrderStatus newStatus) {
    if (_notificationProvider == null) return;

    String title = '';
    String message = ''; // FIXED: Changed from label to variable

    switch (newStatus) {
      case OrderStatus.confirmed:
        title = 'Order Confirmed!';
        message = 'Your order #${order.id} has been confirmed and is being prepared.';
        break;
      case OrderStatus.assigned:
        title = 'Rider Assigned!';
        message = order.riderName != null
            ? 'Your order #${order.id} has been assigned to ${order.riderName}.'
            : 'Your order #${order.id} has been assigned for delivery.';
        break;
      case OrderStatus.pickedUp:
        title = 'Order Picked Up!';
        message = 'Your order #${order.id} has been picked up and is on the way!';
        break;
      case OrderStatus.onRoute:
        title = 'Out for Delivery!';
        message = 'Your order #${order.id} is on the way to you!';
        break;
      case OrderStatus.delivered:
        title = 'Order Delivered!';
        message = 'Your order #${order.id} has been delivered successfully. Enjoy your meal!'; // FIXED
        break;
      case OrderStatus.cancelled:
        title = 'Order Cancelled';
        message = 'Your order #${order.id} has been cancelled.';
        break;
      case OrderStatus.pending:
        title = 'Order Received';
        message = 'Your order #${order.id} has been received and is pending confirmation.';
        break;
      case OrderStatus.inProcess:
        title = 'Order In Progress';
        message = 'Your order #${order.id} is being prepared by our kitchen.';
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
    if (index != -1) {
      final currentOrder = _orders[index];
      
      _orders[index] = Order(
        id: currentOrder.id,
        customerId: currentOrder.customerId,
        customerName: currentOrder.customerName,
        deliveryPhone: currentOrder.deliveryPhone,
        items: currentOrder.items,
        totalAmount: currentOrder.totalAmount,
        date: currentOrder.date,
        status: OrderStatus.cancelled,
        deliveryType: currentOrder.deliveryType,
        deliveryAddress: currentOrder.deliveryAddress,
        riderId: currentOrder.riderId,
        riderName: currentOrder.riderName,
        cancellationReason: reason, // ADDED: Set cancellation reason
      );
      
      notifyListeners();
      
      // Send notification to customer
      if (_notificationProvider != null) {
        _notificationProvider!.addNotification(
          AppNotification(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: 'Order Cancelled',
            message: 'Your order $orderId has been cancelled. Reason: $reason',
            userId: currentOrder.customerId,
            timestamp: DateTime.now(),
            type: 'order_cancelled',
          ),
        );
      }
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
}
