// lib/providers/menu_provider.dart
import 'package:flutter/foundation.dart';

class MenuProvider with ChangeNotifier {
  final List<Map<String, dynamic>> _menuItems = [];

  MenuProvider() {
    // keep your existing code, just add this constructor
    _menuItems.addAll(dummyMenuItems); // give UI something to show
  }

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

  // ADDED: Toggle availability of a menu item
  void toggleAvailability(int index) {
    if (index >= 0 && index < _menuItems.length) {
      _menuItems[index]['isAvailable'] = !(_menuItems[index]['isAvailable'] ?? true);
      notifyListeners();
    }
  }

  // ADDED: Check if item is available
  bool isItemAvailable(String title) {
    final item = _menuItems.firstWhere(
      (item) => item['title'] == title,
      orElse: () => {'isAvailable': true},
    );
    return item['isAvailable'] ?? true;
  }

  // ADDED: Mark item as unavailable
  void markAsUnavailable(int index) {
    if (index >= 0 && index < _menuItems.length) {
      _menuItems[index]['isAvailable'] = false;
      notifyListeners();
    }
  }

  // ADDED: Mark item as available
  void markAsAvailable(int index) {
    if (index >= 0 && index < _menuItems.length) {
      _menuItems[index]['isAvailable'] = true;
      notifyListeners();
    }
  }
}

// same dummy list you had before
final List<Map<String, dynamic>> dummyMenuItems = [
  {
    'title': 'Ugali Nyama Choma',
    'price': 210,
    'category': 'Ugali Dishes',
    'description': 'Traditional Kenyan maize meal with grilled meat',
    'rating': 4.8,
    'image': 'assets/images/ugali_nyama.jpg',
  },
  {
    'title': 'Pilau Liver',
    'price': 230,
    'category': 'Rice Dishes',
    'description': 'Spiced rice with tender liver pieces',
    'rating': 4.5,
    'image': 'assets/images/pilau.jpg',
  },
  {
    'title': 'Ugali Samaki',
    'price': 300,
    'category': 'Ugali Dishes',
    'description': 'Maize meal served with fried fish',
    'rating': 4.7,
    'image': 'assets/images/ugali_fish.jpg',
  },
  {
    'title': 'Githeri',
    'price': 120,
    'category': 'Traditional',
    'description': 'Boiled maize and beans mixture',
    'rating': 4.3,
    'image': 'assets/images/Githeri.jpg',
  },
  {
    'title': 'Chapati',
    'price': 20,
    'category': 'Breakfast',
    'description': 'Soft, flaky flatbread',
    'rating': 4.6,
    'image': 'assets/images/Chapati.jpg',
  },
  {
    'title': 'Matoke Beef',
    'price': 230,
    'category': 'Traditional',
    'description': 'Steamed bananas with beef stew',
    'rating': 4.4,
    'image': 'assets/images/matoke.jpg',
  },
  {
    'title': 'Chips Beef',
    'price': 210,
    'category': 'Fast Food',
    'description': 'Crispy fries with beef stew',
    'rating': 4.2,
    'image': 'assets/images/chips_beef.jpg',
  },
  {
    'title': 'Beef Burger',
    'price': 130,
    'category': 'Fast Food',
    'description': 'Juicy beef patty in a bun with veggies',
    'rating': 4.1,
    'image': 'assets/images/burger.jpg',
  },
  {
    'title': 'Tea',
    'price': 30,
    'category': 'Beverages',
    'description': 'Hot Kenyan tea with milk',
    'rating': 4.5,
    'image': 'assets/images/tea.jpg',
  },
  {
    'title': 'Samosa',
    'price': 20,
    'category': 'Snacks',
    'description': 'Crispy pastry filled with spiced meat',
    'rating': 4.7,
    'image': 'assets/images/samosa.jpg',
  },
  {
    'title': 'Pilau Beef Fry',
    'price': 180,
    'category': 'Rice Dishes',
    'description': 'Spiced rice with fried beef',
    'rating': 4.6,
    'image': 'assets/images/pilau_beef.jpg',
  },
  {
    'title': 'Kuku Ugali',
    'price': 220,
    'category': 'Ugali Dishes',
    'description': 'Maize meal with chicken stew',
    'rating': 4.5,
    'image': 'assets/images/kuku_ugali.jpg',
  },
];