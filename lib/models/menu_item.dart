//lib/models/menu_item.dart
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// Enum representing the weight/portion size of a meal
enum MealWeight {
  Light,
  Medium,
  Heavy;

  /// Get display name for UI
  String get displayName {
    switch (this) {
      case MealWeight.Light:
        return 'Light';
      case MealWeight.Medium:
        return 'Medium';
      case MealWeight.Heavy:
        return 'Heavy';
    }
  }

  /// Parse from string (for database)
  static MealWeight fromString(String value) {
    switch (value.toLowerCase()) {
      case 'light':
        return MealWeight.Light;
      case 'heavy':
        return MealWeight.Heavy;
      case 'medium':
      default:
        return MealWeight.Medium;
    }
  }
}

class MenuItem extends Equatable {
  final String? id; // ADDED: Maps to 'id' (uuid)
  final String? productId; // ADDED: Maps to 'product_id' (uuid)
  final String title; // RENAMED: Maps to 'name' in DB
  final int price;
  final double rating; // KEPT: For app logic (not in DB)
  final String category;
  final MealWeight mealWeight;
  final String? description;
  final String? imageUrl;
  final bool isAvailable;

  const MenuItem({
    this.id,
    this.productId,
    required this.title,
    required this.price,
    this.rating = 4.5, // Default rating for new items
    required this.category,
    required this.mealWeight,
    this.description,
    this.imageUrl,
    this.isAvailable = true,
  });

  // FIXED: Match Supabase schema
  factory MenuItem.fromJson(Map<String, dynamic> json) {
    try {
      debugPrint('📦 Parsing MenuItem: ${json['name']}');
      
      return MenuItem(
        id: json['id'] as String?,
        productId: json['product_id'] as String?,
        title: json['name'] as String,
        price: _parsePrice(json['price']),
        rating: 4.5,
        category: json['category'] as String? ?? 'Main Course',
        mealWeight: MealWeight.fromString(json['meal_weight'] as String? ?? 'Medium'),
        description: json['description'] as String?,
        imageUrl: json['image_url'] as String?,
        isAvailable: json['available'] as bool? ?? true,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error parsing MenuItem from JSON: $e');
      debugPrint('📋 JSON data: $json');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // ADDED: Safe price parsing
  static int _parsePrice(dynamic price) {
    if (price == null) return 0;
    if (price is int) return price;
    if (price is double) return price.toInt();
    if (price is num) return price.toInt();
    if (price is String) return int.tryParse(price) ?? 0;
    debugPrint('⚠️ Unknown price type: ${price.runtimeType}');
    return 0;
  }

  // FIXED: Match Supabase schema
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'name': title, // ✅ 'name' in DB
      'price': price,
      'category': category,
      'meal_weight': mealWeight.name,
      'description': description,
      'image_url': imageUrl,
      'available': isAvailable, // ✅ 'available' in DB
      // DON'T include updated_at - let database trigger handle it automatically
    };
    
    // Include IDs only if they exist (for updates)
    if (id != null) json['id'] = id;
    if (productId != null) json['product_id'] = productId;
    
    return json;
  }

  // ADDED: copyWith method for easy updates
  MenuItem copyWith({
    String? id,
    String? productId,
    String? title,
    int? price,
    double? rating,
    String? category,
    MealWeight? mealWeight,
    String? description,
    String? imageUrl,
    bool? isAvailable,
  }) {
    return MenuItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      title: title ?? this.title,
      price: price ?? this.price,
      rating: rating ?? this.rating,
      category: category ?? this.category,
      mealWeight: mealWeight ?? this.mealWeight,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }

  @override
  List<Object?> get props => [
        id,
        productId,
        title,
        price,
        rating,
        category,
        mealWeight,
        description,
        imageUrl,
        isAvailable,
      ];
}
