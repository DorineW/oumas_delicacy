// lib/models/order.dart
//the order model representing customer orders

enum OrderStatus {
  pending,      // Customer placed order
  confirmed,    // Admin/auto-confirmed after 5 minutes
  preparing,    // Kitchen is preparing 
  outForDelivery, // Assigned to rider, on the way
  delivered,    // Successfully delivered
  cancelled,    // Order cancelled
}

enum DeliveryType {
  delivery,
  pickup,
}

class OrderItem {
  final String id;
  final String title;
  final int quantity;
  final int price; // price per item in Ksh
  final int? rating; // ADDED: Individual item rating (1-5)
  final String? review; // ADDED: Individual item review comment

  OrderItem({
    required this.id,
    required this.title,
    required this.quantity,
    required this.price,
    this.rating,
    this.review,
  });

  int get totalPrice => quantity * price;

  // UPDATED: Add rating and review to JSON methods
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'quantity': quantity,
    'price': price,
    'rating': rating,
    'review': review,
  };

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
    id: json['id'],
    title: json['title'],
    quantity: json['quantity'],
    price: json['price'],
    rating: json['rating'],
    review: json['review'],
  );
}

class Order {
  final String id;
  final String customerId;
  final String customerName;
  final String? deliveryPhone; 
  final List<OrderItem> items;
  final int totalAmount;
  final DateTime date;
  final OrderStatus status;
  final DeliveryType deliveryType;
  final String? deliveryAddress;
  final String? riderId;
  final String? riderName;
  final String? cancellationReason; 

  Order({
    required this.id,
    required this.customerId,
    required this.customerName,
    this.deliveryPhone, // ADDED
    required this.items,
    required this.totalAmount,
    required this.date,
    required this.status,
    required this.deliveryType,
    this.deliveryAddress,
    this.riderId,
    this.riderName,
    this.cancellationReason, 
  });

 
  Order copyWith({
    String? id,
    String? customerId,
    String? customerName,
    String? deliveryPhone, 
    DateTime? date,
    List<OrderItem>? items,
    int? totalAmount,
    OrderStatus? status,
    DeliveryType? deliveryType,
    String? riderId,
    String? riderName,
    String? deliveryAddress,
  }) {
    return Order(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      deliveryPhone: deliveryPhone ?? this.deliveryPhone, // ADDED
      date: date ?? this.date,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      deliveryType: deliveryType ?? this.deliveryType,
      riderId: riderId ?? this.riderId,
      riderName: riderName ?? this.riderName,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
    );
  }

  // ADDED: Check if customer can still cancel (within 5 minutes)
  bool get canCancel {
    if (status == OrderStatus.cancelled || status == OrderStatus.delivered) {
      return false;
    }
    final timeSinceOrder = DateTime.now().difference(date).inMinutes;
    return timeSinceOrder < 5; // 5-minute cancellation window
  }

  // ADDED: Get remaining cancellation time in minutes
  int get cancellationTimeRemaining {
    final timeSinceOrder = DateTime.now().difference(date).inMinutes;
    final remaining = 5 - timeSinceOrder;
    return remaining > 0 ? remaining : 0;
  }
}
