// lib/models/product.dart
class Product {
  String id;
  String name;
  double price;
  String category;
  String description;
  bool available;
  String image;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    this.description = '',
    required this.available,
    required this.image,
  });

  // Optional: Add methods to convert to/from JSON if needed
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'category': category,
      'description': description,
      'available': available,
      'image': image,
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      price: json['price'].toDouble(),
      category: json['category'],
      description: json['description'] ?? '',
      available: json['available'],
      image: json['image'],
    );
  }
}