//lib/models/cart_item.dart
//the cart item model representing items in the shopping cart
class CartItem {
  final String id;
  final String mealTitle;
  final int price; // price per unit in Ksh (integer)
  int quantity;
  final String mealImage;

  CartItem({
    required this.id,
    required this.mealTitle,
    required this.price,
    required this.quantity,
    required this.mealImage,
  });

  int get totalPrice => price * quantity;
}