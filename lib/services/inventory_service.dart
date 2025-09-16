import 'package:flutter/foundation.dart';
import '../models/inventory_item.dart';

class InventoryService with ChangeNotifier {
  final List<InventoryItem> _items = [
    InventoryItem(
      id: '1',
      name: 'Flour',
      category: 'Baking',
      quantity: 20,
      unit: 'kg',
      lowStockThreshold: 5,
    ),
    InventoryItem(
      id: '2',
      name: 'Sugar',
      category: 'Baking',
      quantity: 15,
      unit: 'kg',
      lowStockThreshold: 3,
    ),
    // Add more sample items as needed
  ];

  List<InventoryItem> get items => _items;

  void addItem(InventoryItem item) {
    _items.add(item);
    notifyListeners();
  }

  void updateItem(InventoryItem updatedItem) {
    final index = _items.indexWhere((item) => item.id == updatedItem.id);
    if (index != -1) {
      _items[index] = updatedItem;
      notifyListeners();
    }
  }

  void deleteItem(String id) {
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
  }
}