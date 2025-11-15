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
    required this.createdAt,
    required this.updatedAt,
    this.currentStock,
    this.locationId,
    this.locationName,
  });

  factory StoreItem.fromJson(Map<String, dynamic> json) {
    // Helper to safely extract inventory data
    dynamic getInventoryValue(String key) {
      if (json['inventory'] is List && (json['inventory'] as List).isNotEmpty) {
        return json['inventory'][0][key];
      } else if (json['inventory'] is Map) {
        return json['inventory'][key];
      }
      return null;
    }

    // Helper to safely extract location data
    String? getLocationName() {
      if (json['inventory'] is List && (json['inventory'] as List).isNotEmpty) {
        return json['inventory'][0]['locations']?['name'];
      } else if (json['inventory'] is Map) {
        return json['inventory']['locations']?['name'];
      }
      return null;
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
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      currentStock: getInventoryValue('quantity'),
      locationId: getInventoryValue('location_id'),
      locationName: getLocationName(),
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
      createdAt: createdAt,
      updatedAt: updatedAt,
      currentStock: currentStock ?? this.currentStock,
      locationId: locationId ?? this.locationId,
      locationName: locationName ?? this.locationName,
    );
  }

  // Stock management helpers
  bool get hasStockTracking => currentStock != null;
  bool get isOutOfStock => currentStock != null && currentStock == 0;
  bool get isLowStock => currentStock != null && currentStock! > 0 && currentStock! <= 10;
  bool get isInStock => currentStock == null || currentStock! > 0;
  
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