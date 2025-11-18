// lib/models/product_inventory.dart
class ProductInventory {
  final String id;
  final String productId;
  final String? locationId; // Optional - not used in single location system
  final int quantity;
  final int minimumStockAlert;
  final DateTime? lastRestockDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? locationName;
  final String? productName;

  ProductInventory({
    required this.id,
    required this.productId,
    this.locationId, // Optional
    required this.quantity,
    required this.minimumStockAlert,
    this.lastRestockDate,
    required this.createdAt,
    required this.updatedAt,
    this.locationName,
    this.productName,
  });

  factory ProductInventory.fromJson(Map<String, dynamic> json) {
    return ProductInventory(
      id: json['id'] ?? '',
      productId: json['product_id'] ?? '',
      locationId: json['location_id'], // Can be null
      quantity: json['quantity'] ?? 0,
      minimumStockAlert: json['minimum_stock_alert'] ?? 10,
      lastRestockDate: json['last_restock_date'] != null 
          ? DateTime.parse(json['last_restock_date'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      locationName: json['locations']?['name'],
      productName: json['products']?['name'],
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
    String? productName,
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
      productName: productName ?? this.productName,
    );
  }
}

// Low Stock Alert model (from view) - Single location system
class LowStockAlert {
  final String id;
  final String productId;
  final String productName;
  final String? category; // UPDATED: Category from StoreItems
  final bool trackInventory; // UPDATED: Track inventory flag
  final int quantity;
  final int minimumStockAlert;
  final int unitsBelowMinimum;
  final DateTime? lastRestockDate;
  final DateTime updatedAt;

  const LowStockAlert({
    required this.id,
    required this.productId,
    required this.productName,
    this.category,
    required this.trackInventory,
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
      category: json['category'] as String?,
      trackInventory: json['track_inventory'] as bool? ?? true,
      quantity: json['current_stock'] as int,
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