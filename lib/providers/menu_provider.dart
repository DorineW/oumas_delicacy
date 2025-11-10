// lib/providers/menu_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/menu_item.dart';

class MenuProvider extends ChangeNotifier {
  List<MenuItem> _menuItems = [];
  bool _isLoading = false;
  String? _error;

  List<MenuItem> get menuItems => _menuItems;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Get items by category
  List<MenuItem> getItemsByCategory(String category) {
    return _menuItems.where((item) => item.category == category).toList();
  }

  // Get available categories
  List<String> get categories {
    return _menuItems.map((item) => item.category).toSet().toList();
  }

  // Check if item is available
  bool isItemAvailable(String title) {
    return _menuItems.any((item) => item.title == title && item.isAvailable);
  }

  // MAIN: Load menu items with detailed debugging
  Future<void> loadMenuItems() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('🔄 Starting to load menu items from Supabase...');
      
      final supabase = Supabase.instance.client;
      debugPrint('✅ Supabase client initialized');
      
      // Query with all columns explicitly
      final response = await supabase
          .from('menu_items')
          .select('id, product_id, name, description, price, available, created_at, category, meal_weight, image_url')
          .order('name', ascending: true);

      debugPrint('✅ Query executed successfully');
      debugPrint('📊 Response type: ${response.runtimeType}');
      debugPrint('📏 Number of items fetched: ${response.length}');

      if (response.isEmpty) {
        debugPrint('⚠️ No menu items found in database');
        _error = 'No menu items found';
        _menuItems = [];
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Parse each item with error handling
      final items = <MenuItem>[];
      for (var i = 0; i < response.length; i++) {
        try {
          // FIXED: Removed unnecessary cast
          final json = response[i];
          debugPrint('--- Parsing item ${i + 1}/${response.length} ---');
          debugPrint('Raw JSON: $json');
          
          final item = MenuItem.fromJson(json);
          items.add(item);
          debugPrint('✅ Successfully parsed: ${item.title} - KES ${item.price}');
        } catch (e, stackTrace) {
          debugPrint('❌ Error parsing item ${i + 1}: $e');
          debugPrint('Failed JSON: ${response[i]}');
          debugPrint('Stack: $stackTrace');
        }
      }

      _menuItems = items;
      _error = null;
      debugPrint('🎉 Successfully loaded ${items.length} menu items');
      debugPrint('Categories found: ${categories.join(", ")}');
      
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading menu items: $e');
      debugPrint('Stack trace: $stackTrace');
      _error = 'Failed to load menu items: $e';
      _menuItems = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Refresh menu items
  Future<void> refreshMenuItems() async {
    await loadMenuItems();
  }

  // Add a new menu item
  Future<bool> addMenuItem(MenuItem item) async {
    try {
      debugPrint('➕ Adding new menu item: ${item.title}');
      
      final response = await Supabase.instance.client
          .from('menu_items')
          .insert(item.toJson())
          .select()
          .single();

      debugPrint('✅ Menu item added: $response');
      await loadMenuItems(); // Reload to get fresh data
      return true;
    } catch (e) {
      debugPrint('❌ Error adding menu item: $e');
      _error = 'Failed to add menu item: $e';
      notifyListeners();
      return false;
    }
  }

  // Update a menu item
  Future<bool> updateMenuItem(MenuItem item) async {
    try {
      debugPrint('🔄 Updating menu item: ${item.title}');
      
      await Supabase.instance.client
          .from('menu_items')
          .update(item.toJson())
          .eq('id', item.id!);

      debugPrint('✅ Menu item updated');
      await loadMenuItems(); // Reload to get fresh data
      return true;
    } catch (e) {
      debugPrint('❌ Error updating menu item: $e');
      _error = 'Failed to update menu item: $e';
      notifyListeners();
      return false;
    }
  }

  // Delete a menu item
  Future<bool> deleteMenuItem(String id) async {
    try {
      debugPrint('🗑️ Deleting menu item: $id');
      
      await Supabase.instance.client
          .from('menu_items')
          .delete()
          .eq('id', id);

      debugPrint('✅ Menu item deleted');
      await loadMenuItems(); // Reload to get fresh data
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting menu item: $e');
      _error = 'Failed to delete menu item: $e';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
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