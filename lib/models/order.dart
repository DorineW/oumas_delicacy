// lib/models/order.dart
//the order model representing customer orders

enum OrderStatus {
  confirmed,    // Payment confirmed, order ready for preparation
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
  final String id; // Order item ID
  final String? menuItemId; // UUID from menu_items table (optional for backward compatibility)
  final String title;
  final int quantity;
  final int price;
  final int? rating;
  final String? review;

  OrderItem({
    required this.id,
    this.menuItemId,
    required this.title,
    required this.quantity,
    required this.price,
    this.rating,
    this.review,
  });

  int get totalPrice => quantity * price;

  Map<String, dynamic> toJson() => {
    'id': id,
    'product_id': menuItemId, // Match DB column name
    'name': title, // Match DB column name
    'quantity': quantity,
    'unit_price': price, // Match DB column name
    'total_price': totalPrice, // Match DB column name
    'rating': rating,
    'review': review,
  };

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
    id: json['id'],
    menuItemId: json['product_id'], // Match DB column name
    title: json['name'] ?? json['title'], // Support both for backward compatibility
    quantity: json['quantity'],
    price: (json['unit_price'] ?? json['price']) as int, // Support both
    rating: json['rating'],
    review: json['review'],
  );
}

class Order {
  final String id;
  final String? shortId; // Human-readable order ID
  final String customerId; // maps to user_auth_id
  final String customerName; // NOT in DB, will be fetched from users table
  final String? deliveryPhone;
  final List<OrderItem> items;
  final int subtotal;
  final int deliveryFee;
  final int tax;
  final int totalAmount; // maps to total
  final DateTime date; // maps to placed_at
  final OrderStatus status;
  final DeliveryType deliveryType;
  final Map<String, dynamic>? deliveryAddress; // jsonb in DB
  final String? riderId;
  final String? riderName;
  final String? cancellationReason;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;

  Order({
    required this.id,
    this.shortId,
    required this.customerId,
    this.customerName = 'Guest', // Default value since not in DB
    this.deliveryPhone,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.tax,
    required this.totalAmount,
    required this.date,
    required this.status,
    required this.deliveryType,
    this.deliveryAddress,
    this.riderId,
    this.riderName,
    this.cancellationReason,
    this.deliveredAt, // ADDED
    this.cancelledAt, // ADDED
  });

  Order copyWith({
    String? id,
    String? shortId,
    String? customerId,
    String? customerName,
    String? deliveryPhone,
    DateTime? date,
    List<OrderItem>? items,
    int? subtotal,
    int? deliveryFee,
    int? tax,
    int? totalAmount,
    OrderStatus? status,
    DeliveryType? deliveryType,
    String? riderId,
    String? riderName,
    Map<String, dynamic>? deliveryAddress, // FIXED: Map type
    DateTime? deliveredAt,
    DateTime? cancelledAt,
  }) {
    return Order(
      id: id ?? this.id,
      shortId: shortId ?? this.shortId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      deliveryPhone: deliveryPhone ?? this.deliveryPhone,
      date: date ?? this.date,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      tax: tax ?? this.tax,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      deliveryType: deliveryType ?? this.deliveryType,
      riderId: riderId ?? this.riderId,
      riderName: riderName ?? this.riderName,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
    );
  }

  // Get the human-readable order number
  String get orderNumber {
    // Use short_id if available, otherwise fall back to UUID substring
    return shortId ?? id.substring(0, 8).toUpperCase();
  }

  // UPDATED: Match database schema exactly
  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      shortId: json['short_id'] as String?,
      customerId: json['user_auth_id'] as String,
      customerName: json['customer_name'] as String? ?? 'Guest',
      deliveryPhone: json['delivery_phone'] as String?,
      date: DateTime.parse(json['placed_at'] as String),
      items: [], // Load separately
      subtotal: (json['subtotal'] as num?)?.toInt() ?? 0,
      deliveryFee: (json['delivery_fee'] as num?)?.toInt() ?? 0,
      tax: (json['tax'] as num?)?.toInt() ?? 0,
      totalAmount: (json['total'] as num?)?.toInt() ?? 0,
      status: OrderStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => OrderStatus.confirmed,
      ),
      deliveryType: (json['delivery_address'] != null) 
          ? DeliveryType.delivery 
          : DeliveryType.pickup,
      deliveryAddress: json['delivery_address'] as Map<String, dynamic>?, // FIXED: jsonb type
      riderId: json['rider_id'] as String?,
      riderName: json['rider_name'] as String?,
      cancellationReason: json['cancellation_reason'] as String?,
      deliveredAt: json['delivered_at'] != null 
          ? DateTime.parse(json['delivered_at'] as String)
          : null,
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'] as String)
          : null,
    );
  }

  // UPDATED: Convert to database format
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_auth_id': customerId,
      'status': status.name,
      'subtotal': subtotal,
      'delivery_fee': deliveryFee,
      'tax': tax,
      'total': totalAmount,
      'delivery_address': deliveryAddress,
      'placed_at': date.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
      'cancelled_at': cancelledAt?.toIso8601String(),
    };
  }
}
