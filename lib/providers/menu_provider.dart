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