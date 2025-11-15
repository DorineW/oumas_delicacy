// lib/models/product_inventory.dart
class ProductInventory {
  final String id;
  final String productId;
  final String locationId;
  final int quantity;
  final int minimumStockAlert;
  final DateTime? lastRestockDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? locationName;

  ProductInventory({
    required this.id,
    required this.productId,
    required this.locationId,
    required this.quantity,
    required this.minimumStockAlert,
    this.lastRestockDate,
    required this.createdAt,
    required this.updatedAt,
    this.locationName,
  });

  factory ProductInventory.fromJson(Map<String, dynamic> json) {
    return ProductInventory(
      id: json['id'] ?? '',
      productId: json['product_id'] ?? '',
      locationId: json['location_id'] ?? '',
      quantity: json['quantity'] ?? 0,
      minimumStockAlert: json['minimum_stock_alert'] ?? 10,
      lastRestockDate: json['last_restock_date'] != null 
          ? DateTime.parse(json['last_restock_date'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      locationName: json['locations']?['name'],
    );
  }

  bool get isLowStock => quantity <= minimumStockAlert;
  bool get isOutOfStock => quantity == 0;
  int get unitsBelowMinimum => minimumStockAlert - quantity;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'location_id': locationId,
      'quantity': quantity,
      'minimum_stock_alert': minimumStockAlert,
      'last_restock_date': lastRestockDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ProductInventory copyWith({
    String? id,
    String? productId,
    String? locationId,
    int? quantity,
    int? minimumStockAlert,
    DateTime? lastRestockDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? locationName,
  }) {
    return ProductInventory(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      locationId: locationId ?? this.locationId,
      quantity: quantity ?? this.quantity,
      minimumStockAlert: minimumStockAlert ?? this.minimumStockAlert,
      lastRestockDate: lastRestockDate ?? this.lastRestockDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      locationName: locationName ?? this.locationName,
    );
  }
}

// Low Stock Alert model (from view)
class LowStockAlert {
  final String id;
  final String productId;
  final String productName;
  final String locationId;
  final String locationName;
  final int quantity;
  final int minimumStockAlert;
  final int unitsBelowMinimum;
  final DateTime? lastRestockDate;
  final DateTime updatedAt;

  const LowStockAlert({
    required this.id,
    required this.productId,
    required this.productName,
    required this.locationId,
    required this.locationName,
    required this.quantity,
    required this.minimumStockAlert,
    required this.unitsBelowMinimum,
    this.lastRestockDate,
    required this.updatedAt,
  });

  factory LowStockAlert.fromJson(Map<String, dynamic> json) {
    return LowStockAlert(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      locationId: json['location_id'] as String,
      locationName: json['location_name'] as String,
      quantity: json['quantity'] as int,
      minimumStockAlert: json['minimum_stock_alert'] as int,
      unitsBelowMinimum: json['units_below_minimum'] as int,
      lastRestockDate: json['last_restock_date'] != null
          ? DateTime.parse(json['last_restock_date'] as String)
          : null,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

// Available Product at Location model
class AvailableProduct {
  final String productId;
  final String productName;
  final String category;
  final double price;
  final int quantity;
  final bool inStock;

  const AvailableProduct({
    required this.productId,
    required this.productName,
    required this.category,
    required this.price,
    required this.quantity,
    required this.inStock,
  });

  factory AvailableProduct.fromJson(Map<String, dynamic> json) {
    return AvailableProduct(
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      category: json['category'] as String,
      price: (json['price'] as num).toDouble(),
      quantity: json['quantity'] as int,
      inStock: json['in_stock'] as bool,
    );
  }
}