import 'package:flutter/foundation.dart';

class MenuProvider with ChangeNotifier {
  List<Map<String, dynamic>> _menuItems = [];

  List<Map<String, dynamic>> get menuItems => _menuItems;

  void addMenuItem(Map<String, dynamic> newItem) {
    _menuItems.add(newItem);
    notifyListeners();
  }

  void updateMenuItem(int index, Map<String, dynamic> updatedItem) {
    if (index >= 0 && index < _menuItems.length) {
      _menuItems[index] = updatedItem;
      notifyListeners();
    }
  }

  void removeMenuItem(int index) {
    if (index >= 0 && index < _menuItems.length) {
      _menuItems.removeAt(index);
      notifyListeners();
    }
  }

  void clearMenu() {
    _menuItems.clear();
    notifyListeners();
  }
}