//lib/models/inventory_item.dart
//the inventory item model representing items in stock
class InventoryItem {
  final String? id; // Made optional - Supabase generates UUID
  final String? productId; // ADDED: Match DB schema
  final String name;
  final String category;
  final double quantity;
  final String unit;
  final double lowStockThreshold;
  final DateTime? updatedAt; // ADDED: Match DB schema

  InventoryItem({
    this.id, // Now optional
    this.productId,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.lowStockThreshold,
    this.updatedAt,
  });

  // ADDED: Parse from Supabase JSON (same pattern as MenuItem)
  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'] as String,
      productId: json['product_id'] as String?,
      name: json['name'] as String,
      category: json['category'] as String? ?? 'Uncategorized',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] as String? ?? 'units',
      lowStockThreshold: (json['low_stock_threshold'] as num?)?.toDouble() ?? 0.0,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  // ADDED: Convert to JSON for Supabase
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'name': name,
      'category': category,
      'quantity': quantity,
      'unit': unit,
      'low_stock_threshold': lowStockThreshold,
      'updated_at': updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
    
    // Include IDs only if they exist (for updates)
    if (id != null) json['id'] = id;
    if (productId != null) json['product_id'] = productId;
    
    return json;
  }

  // ADDED: Check if stock is low
  bool get isLowStock => quantity <= lowStockThreshold;

  // ADDED: Copy with method for updates
  InventoryItem copyWith({
    String? id,
    String? productId,
    String? name,
    String? category,
    double? quantity,
    String? unit,
    double? lowStockThreshold,
    DateTime? updatedAt,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
