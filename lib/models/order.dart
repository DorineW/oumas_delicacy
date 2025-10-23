// lib/models/order.dart


enum OrderStatus {
  pending,
  confirmed,
  assigned,    // ADDED: Order assigned to rider
  pickedUp,    // ADDED: Rider picked up order
  onRoute,     // ADDED: Rider is delivering
  delivered,
  cancelled,
  inProcess,   // KEPT: For backward compatibility
}

enum DeliveryType { delivery, pickup }

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
  final DateTime date;
  final List<OrderItem> items;
  final int totalAmount;
  final OrderStatus status;
  final DeliveryType deliveryType;
  final String? riderId;           // ADDED: Assigned rider ID
  final String? riderName;         // ADDED: Assigned rider name
  final String? deliveryAddress;   // ADDED: Delivery address
  final String? deliveryPhone;     // ADDED: Customer phone
  final Map<String, double>? deliveryLocation; // ADDED: Lat/Lng

  Order({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.date,
    required this.items,
    required this.totalAmount,
    required this.status,
    required this.deliveryType,
    this.riderId,
    this.riderName,
    this.deliveryAddress,
    this.deliveryPhone,
    this.deliveryLocation,
  });

  // ADDED: Copy with method for updates
  Order copyWith({
    String? id,
    String? customerId,
    String? customerName,
    DateTime? date,
    List<OrderItem>? items,
    int? totalAmount,
    OrderStatus? status,
    DeliveryType? deliveryType,
    String? riderId,
    String? riderName,
    String? deliveryAddress,
    String? deliveryPhone,
    Map<String, double>? deliveryLocation,
  }) {
    return Order(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      date: date ?? this.date,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      deliveryType: deliveryType ?? this.deliveryType,
      riderId: riderId ?? this.riderId,
      riderName: riderName ?? this.riderName,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryPhone: deliveryPhone ?? this.deliveryPhone,
      deliveryLocation: deliveryLocation ?? this.deliveryLocation,
    );
  }
}
