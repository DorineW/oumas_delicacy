class CartItem {
  final String id;
  final String mealTitle;
  final String mealImage;
  final int price;
  int quantity; // Changed from final to mutable

  CartItem({
    required this.id,
    required this.mealTitle,
    required this.mealImage,
    required this.price,
    required this.quantity,
  });

  int get totalPrice => price * quantity;
}