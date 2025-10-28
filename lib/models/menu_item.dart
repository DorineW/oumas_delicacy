//lib/models/cart_provider.dart
//the cart provider managing shopping cart state
import 'package:flutter/material.dart';
import '../models/cart_item.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  void addToCart(CartItem item) {
    _items.add(item);
    notifyListeners();
  }

  void removeItem(String id) {
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }

  /// Sum of `CartItem.totalPrice` for the whole basket.
  int get totalPrice =>
      _items.fold<int>(0, (sum, item) => sum + item.totalPrice);
}
