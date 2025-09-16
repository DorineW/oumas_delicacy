// lib/providers/order_provider.dart
import 'package:flutter/material.dart';
import '../models/order.dart';
import 'dart:math';

class OrderProvider extends ChangeNotifier {
  final List<Order> _orders = [];

  List<Order> get orders => List.unmodifiable(_orders);

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
    _orders.insert(0, order);
    notifyListeners();
  }

  void updateStatus(String orderId, OrderStatus newStatus) {
    final i = _orders.indexWhere((o) => o.id == orderId);
    if (i >= 0) {
      _orders[i].status = newStatus;
      notifyListeners();
    }
  }

  void cancelOrder(String orderId) {
    updateStatus(orderId, OrderStatus.cancelled);
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
}
