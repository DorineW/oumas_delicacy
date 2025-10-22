// lib/providers/cart_provider.dart
import 'package:flutter/foundation.dart';
import '../models/cart_item.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => [..._items];

  // total item count (sum of quantities)
  int get totalQuantity => _items.fold(0, (s, i) => s + i.quantity);

  // total price
  int get totalPrice => _items.fold(0, (s, i) => s + i.totalPrice);

  // add item: merge by mealTitle to increment existing quantity
  void addItem(CartItem item) {
    final idx = _items.indexWhere((i) => i.mealTitle == item.mealTitle);
    if (idx >= 0) {
      _items[idx].quantity += item.quantity;
    } else {
      _items.add(item);
    }
    notifyListeners();
  }

  void removeItem(String id) {
    _items.removeWhere((i) => i.id == id);
    notifyListeners();
  }

  // Add clearCart method
  void clearCart() {
    _items.clear();
    notifyListeners();
  }

  void updateQuantity(String id, int quantity) {
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx >= 0) {
      _items[idx].quantity = quantity;
      if (_items[idx].quantity <= 0) _items.removeAt(idx);
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}