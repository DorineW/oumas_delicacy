// lib/models/order.dart


enum OrderStatus { pending, confirmed, inProcess, delivered, cancelled }

enum DeliveryType { delivery, pickup }

class OrderItem {
  final String id;
  final String title;
  final int quantity;
  final int price; // price per item in Ksh

  OrderItem({
    required this.id,
    required this.title,
    required this.quantity,
    required this.price,
  });

  int get totalPrice => quantity * price;
}

class Order {
  final String id;
  final String customerId; // customer identifier
  final String customerName;
  final DateTime date;
  final List<OrderItem> items;
  final int totalAmount;
  OrderStatus status;
  final DeliveryType deliveryType;

  Order({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.date,
    required this.items,
    required this.totalAmount,
    this.status = OrderStatus.pending,
    this.deliveryType = DeliveryType.delivery,
  });
}
