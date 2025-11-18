// lib/providers/inventory_provider.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_inventory.dart';

class InventoryProvider with ChangeNotifier {
  final SupabaseClient _supabase;
  
  List<ProductInventory> _inventory = [];
  List<LowStockAlert> _lowStockAlerts = [];
  bool _isLoading = false;
  String? _error;

  InventoryProvider(this._supabase);

  // Getters
  List<ProductInventory> get inventory => _inventory;
  List<LowStockAlert> get lowStockAlerts => _lowStockAlerts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load all inventory (single location system)
  Future<void> loadInventory() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('ProductInventory')
          .select('''
            *,
            products(name, price, category_text_old)
          ''')
          .order('updated_at', ascending: false);

      _inventory = (response as List)
          .map((json) => ProductInventory.fromJson(json))
          .toList();

      _error = null;
    } catch (e) {
      _error = 'Failed to load inventory: $e';
      debugPrint('Error loading inventory: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load low stock items (for admin alerts)
  Future<void> loadLowStockAlerts() async {
    try {
      final response = await _supabase
          .from('low_stock_items')
          .select('*')
          .order('units_below_minimum', ascending: false);

      _lowStockAlerts = (response as List)
          .map((json) => LowStockAlert.fromJson(json))
          .toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading low stock alerts: $e');
    }
  }

  /// Add a new inventory item
  Future<void> addInventoryItem({
    required String productId,
    required int initialQuantity,
    int minimumStockAlert = 10,
  }) async {
    try {
      await _supabase.from('ProductInventory').insert({
        'product_id': productId,
        'quantity': initialQuantity,
        'minimum_stock_alert': minimumStockAlert,
        'last_restock_date': DateTime.now().toIso8601String(),
      });

      // Reload inventory
      await loadInventory();
    } catch (e) {
      _error = 'Failed to add inventory item: $e';
      debugPrint('Error adding inventory item: $e');
      rethrow;
    }
  }

  /// Update inventory quantity (restock)
  Future<void> restockItem({
    required String inventoryId,
    required int quantityToAdd,
  }) async {
    try {
      // Get current quantity
      final current = _inventory.firstWhere((item) => item.id == inventoryId);
      final newQuantity = current.quantity + quantityToAdd;

      await _supabase
          .from('ProductInventory')
          .update({
            'quantity': newQuantity,
            'last_restock_date': DateTime.now().toIso8601String(),
          })
          .eq('id', inventoryId);

      // Record in stock history
      await _supabase.from('stock_history').insert({
        'inventory_item_id': inventoryId,
        'change': quantityToAdd,
        'reason': 'Restock',
      });

      // Reload inventory
      await loadInventory();
      await loadLowStockAlerts();
    } catch (e) {
      _error = 'Failed to restock item: $e';
      debugPrint('Error restocking item: $e');
      rethrow;
    }
  }

  /// Restock inventory by product (simplified - no location)
  Future<bool> restock(String productId, int quantityToAdd) async {
    try {
      // Find the inventory item
      final inventoryItem = _inventory.firstWhere(
        (item) => item.productId == productId,
        orElse: () => throw Exception('Inventory item not found'),
      );

      final newQuantity = inventoryItem.quantity + quantityToAdd;

      await _supabase
          .from('ProductInventory')
          .update({
            'quantity': newQuantity,
            'last_restock_date': DateTime.now().toIso8601String(),
          })
          .eq('product_id', productId);

      // Record in stock history
      await _supabase.from('stock_history').insert({
        'inventory_item_id': inventoryItem.id,
        'change': quantityToAdd,
        'reason': 'Restock',
      });

      // Reload inventory
      await loadInventory();
      await loadLowStockAlerts();

      return true;
    } catch (e) {
      _error = 'Failed to restock: $e';
      debugPrint('Error restocking: $e');
      return false;
    }
  }

  /// Update inventory item settings
  Future<void> updateInventoryItem({
    required String inventoryId,
    int? quantity,
    int? minimumStockAlert,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      
      if (quantity != null) {
        updateData['quantity'] = quantity;
      }
      if (minimumStockAlert != null) {
        updateData['minimum_stock_alert'] = minimumStockAlert;
      }

      if (updateData.isEmpty) return;

      await _supabase
          .from('ProductInventory')
          .update(updateData)
          .eq('id', inventoryId);

      // Reload inventory
      await loadInventory();
      await loadLowStockAlerts();
    } catch (e) {
      _error = 'Failed to update inventory item: $e';
      debugPrint('Error updating inventory item: $e');
      rethrow;
    }
  }

  /// Delete an inventory item
  Future<void> deleteInventoryItem(String inventoryId) async {
    try {
      await _supabase
          .from('ProductInventory')
          .delete()
          .eq('id', inventoryId);

      // Reload inventory
      await loadInventory();
      await loadLowStockAlerts();
    } catch (e) {
      _error = 'Failed to delete inventory item: $e';
      debugPrint('Error deleting inventory item: $e');
      rethrow;
    }
  }

  /// Record stock adjustment (increase or decrease)
  Future<void> adjustStock({
    required String inventoryId,
    required int adjustment,
    String? reason,
  }) async {
    try {
      // Get current quantity
      final current = _inventory.firstWhere((item) => item.id == inventoryId);
      final newQuantity = (current.quantity + adjustment).clamp(0, 999999);

      await _supabase
          .from('ProductInventory')
          .update({'quantity': newQuantity})
          .eq('id', inventoryId);

      // Record in stock history
      await _supabase.from('stock_history').insert({
        'inventory_item_id': inventoryId,
        'change': adjustment,
        'reason': reason ?? (adjustment > 0 ? 'Stock added' : 'Stock removed'),
      });

      // Reload inventory
      await loadInventory();
      await loadLowStockAlerts();
    } catch (e) {
      _error = 'Failed to adjust stock: $e';
      debugPrint('Error adjusting stock: $e');
      rethrow;
    }
  }

  /// Get inventory statistics
  Map<String, int> getStats() {
    return {
      'total_products': _inventory.length,
      'in_stock': _inventory.where((item) => item.quantity > item.minimumStockAlert).length,
      'low_stock': _inventory.where((item) => item.isLowStock && !item.isOutOfStock).length,
      'out_of_stock': _inventory.where((item) => item.isOutOfStock).length,
    };
  }

  /// Get low stock items
  List<ProductInventory> getLowStockItems() {
    return _inventory.where((item) => item.isLowStock).toList();
  }

  /// Get out of stock items
  List<ProductInventory> getOutOfStockItems() {
    return _inventory.where((item) => item.isOutOfStock).toList();
  }

  /// Clear error message
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
