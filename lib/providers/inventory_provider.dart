// lib/providers/inventory_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/inventory_item.dart';
import '../models/product_inventory.dart';

class InventoryProvider extends ChangeNotifier {
  List<InventoryItem> _items = [];
  bool _isLoading = false;
  String? _error;
  
  // ProductInventory (Phase 3 multi-location system)
  List<ProductInventory> _inventory = [];
  List<LowStockAlert> _lowStockAlerts = [];

  List<InventoryItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // ProductInventory getters
  List<ProductInventory> get inventory => _inventory;
  List<LowStockAlert> get lowStockAlerts => _lowStockAlerts;

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
      
      // Query from 'inventory_items' table
      final response = await supabase
          .from('inventory_items')
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
        'quantity': item.quantity,
        'unit': item.unit,
        'low_stock_threshold': item.lowStockThreshold,
      };
      
      debugPrint('📤 Sending data to DB: $dbData');
      
      final response = await Supabase.instance.client
          .from('inventory_items')
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
          .from('inventory_items')
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
          .from('inventory_items')
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
          .from('inventory_items')
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
  
  // ============================================================================
  // PRODUCT INVENTORY (Phase 3 - Multi-location inventory management)
  // ============================================================================
  
  /// Load inventory for a specific location
  Future<void> loadInventoryForLocation(String locationId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('🔄 Loading inventory for location: $locationId');
      
      final response = await Supabase.instance.client
          .from('product_inventory')
          .select('''
            *,
            location:locations!product_inventory_location_id_fkey(id, name),
            product:menu_items!product_inventory_product_id_fkey(id, name)
          ''')
          .eq('location_id', locationId);

      debugPrint('✅ Loaded ${response.length} inventory items');
      
      _inventory = (response as List)
          .map((json) => ProductInventory.fromJson(json))
          .toList();
      
      _error = null;
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading inventory: $e');
      debugPrint('Stack trace: $stackTrace');
      _error = 'Failed to load inventory: $e';
      _inventory = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Load low stock alerts across all locations
  Future<void> loadLowStockAlerts() async {
    try {
      debugPrint('🔄 Loading low stock alerts');
      
      final response = await Supabase.instance.client
          .from('low_stock_alerts')
          .select();

      debugPrint('✅ Loaded ${response.length} low stock alerts');
      
      _lowStockAlerts = (response as List)
          .map((json) => LowStockAlert.fromJson(json))
          .toList();
      
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading low stock alerts: $e');
      debugPrint('Stack trace: $stackTrace');
      _lowStockAlerts = [];
    }
    notifyListeners();
  }
  
  /// Restock inventory (add quantity)
  Future<bool> restock(String productId, String locationId, int quantity) async {
    try {
      debugPrint('➕ Restocking product $productId at location $locationId: +$quantity');
      
      await Supabase.instance.client
          .rpc('restock_inventory', params: {
            'p_product_id': productId,
            'p_location_id': locationId,
            'p_quantity': quantity,
          });

      debugPrint('✅ Restock successful');
      
      // Reload inventory for current location
      await loadInventoryForLocation(locationId);
      await loadLowStockAlerts();
      
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Error restocking: $e');
      debugPrint('Stack trace: $stackTrace');
      _error = 'Failed to restock: $e';
      notifyListeners();
      return false;
    }
  }
  
  /// Update or insert inventory item
  Future<bool> upsertInventory(ProductInventory item) async {
    try {
      debugPrint('🔄 Upserting inventory for product ${item.productId}');
      
      await Supabase.instance.client
          .from('product_inventory')
          .upsert(item.toJson())
          .eq('product_id', item.productId)
          .eq('location_id', item.locationId);

      debugPrint('✅ Inventory updated');
      
      // Reload inventory
      await loadInventoryForLocation(item.locationId);
      await loadLowStockAlerts();
      
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Error updating inventory: $e');
      debugPrint('Stack trace: $stackTrace');
      _error = 'Failed to update inventory: $e';
      notifyListeners();
      return false;
    }
  }
  
  /// Get location statistics
  Map<String, int> getLocationStats(String locationId) {
    final locationInventory = _inventory.where((item) => item.locationId == locationId).toList();
    
    return {
      'total_products': locationInventory.length,
      'in_stock': locationInventory.where((item) => !item.isOutOfStock).length,
      'low_stock': locationInventory.where((item) => item.isLowStock && !item.isOutOfStock).length,
      'out_of_stock': locationInventory.where((item) => item.isOutOfStock).length,
    };
  }
  
  /// Check if product is available at location
  Future<bool> checkStockAvailability(String productId, String locationId, int quantity) async {
    try {
      final response = await Supabase.instance.client
          .from('product_inventory')
          .select('quantity')
          .eq('product_id', productId)
          .eq('location_id', locationId)
          .maybeSingle();

      if (response == null) return false;
      
      final currentStock = response['quantity'] as int;
      return currentStock >= quantity;
    } catch (e) {
      debugPrint('❌ Error checking stock availability: $e');
      return false;
    }
  }
  
  /// Update inventory after order placement
  Future<bool> updateInventoryOnOrder(String orderId) async {
    try {
      debugPrint('🔄 Updating inventory for order $orderId');
      
      await Supabase.instance.client
          .rpc('update_inventory_on_order', params: {
            'p_order_id': orderId,
          });

      debugPrint('✅ Inventory updated for order');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Error updating inventory on order: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }
  
  /// Get available products at location
  Future<List<AvailableProduct>> getAvailableProductsAtLocation(String locationId) async {
    try {
      debugPrint('🔄 Getting available products at location $locationId');
      
      final response = await Supabase.instance.client
          .rpc('get_available_products_at_location', params: {
            'p_location_id': locationId,
          }) as List;

      debugPrint('✅ Found ${response.length} available products');
      
      return response
          .map((json) => AvailableProduct.fromJson(json))
          .toList();
    } catch (e, stackTrace) {
      debugPrint('❌ Error getting available products: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }
}
