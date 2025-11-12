// lib/providers/inventory_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/inventory_item.dart';

class InventoryProvider extends ChangeNotifier {
  List<InventoryItem> _items = [];
  bool _isLoading = false;
  String? _error;

  List<InventoryItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Get items by category
  List<InventoryItem> getItemsByCategory(String category) {
    return _items.where((item) => item.category == category).toList();
  }

  // Get available categories
  List<String> get categories {
    return _items.map((item) => item.category).toSet().toList();
  }

  // Get low stock items
  List<InventoryItem> get lowStockItems {
    return _items.where((item) => 
      item.quantity <= item.lowStockThreshold
    ).toList();
  }

  // MAIN: Load inventory items with detailed debugging (same pattern as MenuProvider)
  Future<void> loadInventoryItems() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('🔄 Starting to load inventory items from Supabase...');
      
      final supabase = Supabase.instance.client;
      debugPrint('✅ Supabase client initialized');
      
      // Query from 'inventory' table (not 'inventory_items')
      final response = await supabase
          .from('inventory')
          .select('id, product_id, name, category, quantity, unit, low_stock_threshold, updated_at')
          .order('name', ascending: true);

      debugPrint('✅ Query executed successfully');
      debugPrint('📊 Response type: ${response.runtimeType}');
      debugPrint('📏 Number of items fetched: ${response.length}');

      if (response.isEmpty) {
        debugPrint('⚠️ No inventory items found in database');
        _error = 'No inventory items found';
        _items = [];
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Parse each item with error handling
      final items = <InventoryItem>[];
      for (var i = 0; i < response.length; i++) {
        try {
          final json = response[i];
          debugPrint('--- Parsing item ${i + 1}/${response.length} ---');
          debugPrint('Raw JSON: $json');
          
          // Map database columns to model fields
          final mappedJson = {
            'id': json['id'],
            'product_id': json['product_id'],
            'name': json['name'],
            'category': json['category'],
            'quantity': json['quantity'], // Map current_stock to quantity
            'unit': json['unit'],
            'low_stock_threshold': json['low_stock_threshold'],
            'updated_at': json['updated_at'],
          };
          
          final item = InventoryItem.fromJson(mappedJson);
          items.add(item);
          debugPrint('✅ Successfully parsed: ${item.name} - ${item.quantity} ${item.unit}');
        } catch (e, stackTrace) {
          debugPrint('❌ Error parsing item ${i + 1}: $e');
          debugPrint('Failed JSON: ${response[i]}');
          debugPrint('Stack: $stackTrace');
        }
      }

      _items = items;
      _error = null;
      debugPrint('🎉 Successfully loaded ${items.length} inventory items');
      debugPrint('Categories found: ${categories.join(", ")}');
      
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading inventory items: $e');
      debugPrint('Stack trace: $stackTrace');
      _error = 'Failed to load inventory items: $e';
      _items = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Refresh inventory items
  Future<void> refreshInventoryItems() async {
    await loadInventoryItems();
  }

  // Add a new inventory item
  Future<bool> addInventoryItem(InventoryItem item) async {
    try {
      debugPrint('➕ Adding new inventory item: ${item.name}');
      
      // Map model fields to database columns (don't include id - let Supabase generate it)
      final dbData = {
        'name': item.name,
        'category': item.category,
        'quantity': item.quantity, // Map quantity to current_stock
        'unit': item.unit,
        'low_stock_threshold': item.lowStockThreshold,
        'cost_price': 0.0, // Default cost price
        'is_active': true,
      };
      
      debugPrint('📤 Sending data to DB: $dbData');
      
      final response = await Supabase.instance.client
          .from('inventory')
          .insert(dbData)
          .select()
          .single();

      debugPrint('✅ Inventory item added: $response');
      await loadInventoryItems(); // Reload to get fresh data
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Error adding inventory item: $e');
      debugPrint('Stack trace: $stackTrace');
      _error = 'Failed to add inventory item: $e';
      notifyListeners();
      return false;
    }
  }

  // Update an inventory item
  Future<bool> updateInventoryItem(InventoryItem item) async {
    try {
      if (item.id == null) {
        debugPrint('❌ Cannot update item without ID');
        _error = 'Item ID is required for updates';
        notifyListeners();
        return false;
      }
      
      debugPrint('🔄 Updating inventory item: ${item.name}');
      
      // Map model fields to database columns
      final dbData = {
        'name': item.name,
        'category': item.category,
        'quantity': item.quantity, // Map quantity to current_stock
        'unit': item.unit,
        'low_stock_threshold': item.lowStockThreshold,
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      await Supabase.instance.client
          .from('inventory')
          .update(dbData)
          .eq('id', item.id!);

      debugPrint('✅ Inventory item updated');
      await loadInventoryItems(); // Reload to get fresh data
      return true;
    } catch (e) {
      debugPrint('❌ Error updating inventory item: $e');
      _error = 'Failed to update inventory item: $e';
      notifyListeners();
      return false;
    }
  }

  // Delete an inventory item
  Future<bool> deleteInventoryItem(String id) async {
    try {
      debugPrint('🗑️ Deleting inventory item: $id');
      
      await Supabase.instance.client
          .from('inventory')
          .delete()
          .eq('id', id);

      debugPrint('✅ Inventory item deleted');
      await loadInventoryItems(); // Reload to get fresh data
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting inventory item: $e');
      _error = 'Failed to delete inventory item: $e';
      notifyListeners();
      return false;
    }
  }

  // Update stock quantity
  Future<bool> updateStock(String id, double newQuantity) async {
    try {
      debugPrint('📦 Updating stock for item $id to $newQuantity');
      
      await Supabase.instance.client
          .from('inventory')
          .update({
            'quantity': newQuantity, // Map to current_stock
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);

      debugPrint('✅ Stock updated');
      await loadInventoryItems(); // Reload to get fresh data
      return true;
    } catch (e) {
      debugPrint('❌ Error updating stock: $e');
      _error = 'Failed to update stock: $e';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
