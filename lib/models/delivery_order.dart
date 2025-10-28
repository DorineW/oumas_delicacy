//lib/models/delivery_order.dart
//the order model representing customer orders
class DeliveryOrder {
  final String id;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final String deliveryAddress;
  final double amount;
  final DateTime orderTime;
  final OrderStatus status;
  final List<OrderItem> items;
  final String specialInstructions;
  final String paymentMethod;
  final double distance;
  final int estimatedTime;

  const DeliveryOrder({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    required this.deliveryAddress,
    required this.amount,
    required this.orderTime,
    required this.status,
    required this.items,
    required this.specialInstructions,
    required this.paymentMethod,
    required this.distance,
    required this.estimatedTime,
  });

  DeliveryOrder copyWith({
    OrderStatus? status,
  }) {
    return DeliveryOrder(
      id: id,
      customerName: customerName,
      customerPhone: customerPhone,
      customerAddress: customerAddress,
      deliveryAddress: deliveryAddress,
      amount: amount,
      orderTime: orderTime,
      status: status ?? this.status,
      items: items,
      specialInstructions: specialInstructions,
      paymentMethod: paymentMethod,
      distance: distance,
      estimatedTime: estimatedTime,
    );
  }
}

class OrderItem {
  final String name;
  final int quantity;
  final double price;

  const OrderItem(this.name, this.quantity, this.price);
}

enum OrderStatus {
  assigned,
  pickedUp,
  onRoute,
  delivered,
}
