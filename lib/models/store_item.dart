// lib/models/store_item.dart
class StoreItem {
  final String id;
  final String productId;
  final String name;
  final String description;
  final double price;
  final bool available;
  final String? imageUrl;
  final String category;
  final String unitOfMeasure; // Legacy field, kept for compatibility
  final String? unitDescription; // New flexible field: "500g", "2L", "Half", etc.
  final bool trackInventory; // If true, uses ProductInventory. If false, always available.
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? currentStock;
  final String? locationId;
  final String? locationName;

  StoreItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.description,
    required this.price,
    required this.available,
    this.imageUrl,
    required this.category,
    required this.unitOfMeasure,
    this.unitDescription,
    this.trackInventory = true, // Default to tracking inventory
    required this.createdAt,
    required this.updatedAt,
    this.currentStock,
    this.locationId,
    this.locationName,
  });

  factory StoreItem.fromJson(Map<String, dynamic> json) {
    // Extract current stock - check multiple possible locations
    int? currentStock;
    if (json['current_stock'] != null) {
      currentStock = json['current_stock'] as int?;
    } else if (json['ProductInventory'] is List && (json['ProductInventory'] as List).isNotEmpty) {
      currentStock = json['ProductInventory'][0]['quantity'] as int?;
    } else if (json['ProductInventory'] is Map) {
      currentStock = json['ProductInventory']['quantity'] as int?;
    } else if (json['inventory'] is List && (json['inventory'] as List).isNotEmpty) {
      currentStock = json['inventory'][0]['quantity'] as int?;
    } else if (json['inventory'] is Map) {
      currentStock = json['inventory']['quantity'] as int?;
    }

    return StoreItem(
      id: json['id'] ?? '',
      productId: json['product_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      available: json['available'] ?? true,
      imageUrl: json['image_url'],
      category: json['category'] ?? 'General',
      unitOfMeasure: json['unit_of_measure'] ?? 'Piece',
      unitDescription: json['unit_description'],
      trackInventory: json['track_inventory'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      currentStock: currentStock,
      locationId: null, // No longer used in single location system
      locationName: null, // No longer used in single location system
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'name': name,
      'description': description,
      'price': price,
      'available': available,
      'image_url': imageUrl,
      'category': category,
      'unit_of_measure': unitOfMeasure,
      'unit_description': unitDescription,
      'track_inventory': trackInventory,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  StoreItem copyWith({
    String? name,
    String? description,
    double? price,
    bool? available,
    String? imageUrl,
    String? category,
    String? unitOfMeasure,
    String? unitDescription,
    bool? trackInventory,
    int? currentStock,
    String? locationId,
    String? locationName,
  }) {
    return StoreItem(
      id: id,
      productId: productId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      available: available ?? this.available,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      unitOfMeasure: unitOfMeasure ?? this.unitOfMeasure,
      unitDescription: unitDescription ?? this.unitDescription,
      trackInventory: trackInventory ?? this.trackInventory,
      createdAt: createdAt,
      updatedAt: updatedAt,
      currentStock: currentStock ?? this.currentStock,
      locationId: locationId ?? this.locationId,
      locationName: locationName ?? this.locationName,
    );
  }

  // Stock management helpers
  bool get hasStockTracking => trackInventory;
  bool get isOutOfStock => trackInventory && currentStock != null && currentStock == 0;
  bool get isLowStock => trackInventory && currentStock != null && currentStock! > 0 && currentStock! <= 10;
  bool get isInStock => !trackInventory || currentStock == null || currentStock! > 0;
  
  String get stockStatus {
    if (!hasStockTracking) return 'Not tracked';
    if (isOutOfStock) return 'Out of stock';
    if (isLowStock) return 'Low stock ($currentStock left)';
    return 'In stock ($currentStock)';
  }
  
  // Get display name with unit
  String get displayNameWithUnit {
    if (unitDescription != null && unitDescription!.isNotEmpty) {
      return '$name ($unitDescription)';
    }
    return name;
  }
}