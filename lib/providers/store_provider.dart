// lib/providers/store_provider.dart
// ignore_for_file: unused_import

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/location.dart';
import '../models/store_item.dart';
import '../models/product_inventory.dart';

class StoreProvider with ChangeNotifier {
  final SupabaseClient _supabase;
  List<StoreItem> _storeItems = [];
  List<Location> _locations = [];
  bool _isLoading = false;
  String? _error;
  String? _selectedLocationId;

  StoreProvider(this._supabase);

  List<StoreItem> get storeItems => _storeItems;
  List<Location> get locations => _locations;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedLocationId => _selectedLocationId;

  List<StoreItem> get availableItems => 
      _storeItems.where((item) => item.available && item.isInStock).toList();

  List<StoreItem> get lowStockItems =>
      _storeItems.where((item) => item.isLowStock).toList();

  List<StoreItem> get outOfStockItems =>
      _storeItems.where((item) => item.isOutOfStock).toList();

  /// Check if a store item is available by name
  /// Items are available if: item.available AND (!trackInventory OR currentStock > 0)
  bool isItemAvailable(String itemName) {
    final item = _storeItems.where((item) => item.name == itemName).firstOrNull;
    if (item == null) return false;
    
    // Items without inventory tracking are always available if marked available
    // Items with tracking need stock > 0
    return item.available && 
        (!item.trackInventory || (item.currentStock != null && item.currentStock! > 0));
  }

  /// Set the selected location for filtering store items
  void setSelectedLocation(String? locationId) {
    if (_selectedLocationId != locationId) {
      _selectedLocationId = locationId;
      loadStoreItems(locationId: locationId);
    }
  }

  /// Load store items with current inventory (global, no location filtering)
  Future<void> loadStoreItems({String? locationId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('Loading StoreItems...');
      
      // Query StoreItems and manually join with ProductInventory by product_id
      final storeItemsResponse = await _supabase
          .from('StoreItems')
          .select('*')
          .order('created_at', ascending: false);

      debugPrint('StoreItems loaded: ${(storeItemsResponse as List).length} items');

      final inventoryResponse = await _supabase
          .from('ProductInventory')
          .select('product_id, quantity, minimum_stock_alert, last_restock_date');

      debugPrint('ProductInventory loaded: ${(inventoryResponse as List).length} records');

      // Create a map of product_id -> inventory data for quick lookup
      final inventoryMap = <String, Map<String, dynamic>>{};
      for (final inv in inventoryResponse) {
        final productId = inv['product_id'] as String;
        inventoryMap[productId] = inv;
        debugPrint('📦 Inventory: $productId -> quantity: ${inv['quantity']}');
      }

      debugPrint('📋 InventoryMap contains ${inventoryMap.length} entries');

      // Parse store items and attach inventory data
      _storeItems = (storeItemsResponse).map((json) {
        // Attach inventory data if it exists for this product
        final productId = json['product_id'] as String?;
        final itemName = json['name'] as String?;
        final trackInventory = json['track_inventory'] ?? true;
        
        if (productId != null && inventoryMap.containsKey(productId)) {
          final inventory = inventoryMap[productId]!;
          json['current_stock'] = inventory['quantity'];
          json['minimum_stock_alert'] = inventory['minimum_stock_alert'];
          json['last_restock_date'] = inventory['last_restock_date'];
          debugPrint('✅ $itemName: Found inventory - quantity: ${inventory['quantity']}, track: $trackInventory');
        } else {
          debugPrint('⚠️ $itemName: No inventory record found, track: $trackInventory, productId: $productId');
        }
        
        final item = StoreItem.fromJson(json);
        debugPrint('🎯 $itemName parsed: currentStock=${item.currentStock}, track=${item.trackInventory}, available=${item.available}');
        return item;
      }).toList();

      debugPrint('Parsed ${_storeItems.length} store items successfully');

      // Load locations separately
      await _loadLocations();
      
      _error = null;
    } catch (e, stackTrace) {
      _error = 'Failed to load store items: $e';
      debugPrint('Error loading store items: $e');
      debugPrint('Stack trace: $stackTrace');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadLocations() async {
    try {
      final response = await _supabase
          .from('locations')
          .select()
          .inFilter('location_type', ['Warehouse', 'General Store'])
          .eq('is_active', true);

      _locations = (response as List)
          .map((json) => Location.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error loading locations: $e');
    }
  }

  Future<void> addStoreItem(StoreItem item) async {
    try {
      // 1. First create the base product
      final productResponse = await _supabase
          .from('products')
          .insert({
            'name': item.name,
            'price': item.price,
            'category_text_old': item.category,
            'description': item.description,
            'available': item.available,
            'image': item.imageUrl,
            'product_type': 'Store Item',
          })
          .select()
          .single();

      final productId = productResponse['id'] as String;

      // 2. Create the store item details
      final storeItemData = {
        'product_id': productId,
        'name': item.name,
        'description': item.description,
        'price': item.price,
        'available': item.available,
        'image_url': item.imageUrl,
        'category': item.category,
        'unit_of_measure': item.unitOfMeasure,
        'track_inventory': item.trackInventory,
      };
      
      // Only include unit_description if it exists (for backward compatibility)
      if (item.unitDescription != null && item.unitDescription!.isNotEmpty) {
        storeItemData['unit_description'] = item.unitDescription;
      }
      
      await _supabase
          .from('StoreItems')
          .insert(storeItemData);

      // Note: Initial inventory is NOT created here.
      // If item.trackInventory = true, add inventory via Inventory Management screen.
      // If item.trackInventory = false, no inventory needed at all.

      await loadStoreItems(); // Reload the list
    } catch (e) {
      _error = 'Failed to add store item: $e';
      debugPrint('Error adding store item: $e');
      rethrow;
    }
  }

  Future<void> updateStoreItem(StoreItem item) async {
    try {
      // Only update StoreItems table - it's the primary source for store management
      // The products table is legacy and causes update conflicts
      final updateData = {
        'name': item.name,
        'description': item.description,
        'price': item.price,
        'available': item.available,
        'image_url': item.imageUrl,
        'category': item.category,
        'unit_of_measure': item.unitOfMeasure,
        'track_inventory': item.trackInventory,
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      // Only include unit_description if it exists (for backward compatibility)
      if (item.unitDescription != null && item.unitDescription!.isNotEmpty) {
        updateData['unit_description'] = item.unitDescription;
      }
      
      await _supabase
          .from('StoreItems')
          .update(updateData)
          .eq('id', item.id);

      await loadStoreItems(); // Reload the list
    } catch (e) {
      _error = 'Failed to update store item: $e';
      debugPrint('Error updating store item: $e');
      rethrow;
    }
  }

  Future<void> updateInventory(String productId, String locationId, int quantity) async {
    try {
      debugPrint('📦 Updating inventory - Product: $productId, Location: $locationId, Quantity: $quantity');
      
      // Check if inventory record exists
      final existingInventory = await _supabase
          .from('ProductInventory')
          .select()
          .eq('product_id', productId)
          .eq('location_id', locationId);

      debugPrint('📦 Existing inventory records found: ${existingInventory.length}');

      if (existingInventory.isEmpty) {
        // Create new inventory record
        debugPrint('📦 Creating new inventory record');
        await _supabase
            .from('ProductInventory')
            .insert({
              'product_id': productId,
              'location_id': locationId,
              'quantity': quantity,
              'minimum_stock_alert': 10,
              'last_restock_date': DateTime.now().toIso8601String(),
            });
      } else {
        // Update existing inventory record
        debugPrint('📦 Updating existing inventory record');
        await _supabase
            .from('ProductInventory')
            .update({
              'quantity': quantity,
              'last_restock_date': DateTime.now().toIso8601String(),
            })
            .eq('product_id', productId)
            .eq('location_id', locationId);
      }

      debugPrint('📦 Inventory update successful, reloading store items...');
      await loadStoreItems(); // Reload to reflect changes
      debugPrint('📦 Store items reloaded');
    } catch (e) {
      _error = 'Failed to update inventory: $e';
      debugPrint('❌ Error updating inventory: $e');
      rethrow;
    }
  }

  Future<void> toggleAvailability(String itemId, bool available) async {
    try {
      // Only update StoreItems table
      await _supabase
          .from('StoreItems')
          .update({
            'available': available,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', itemId);

      await loadStoreItems(); // Reload the list
    } catch (e) {
      _error = 'Failed to toggle availability: $e';
      debugPrint('Error toggling availability: $e');
      rethrow;
    }
  }

  Future<String> uploadImage(Uint8List imageBytes, String fileName) async {
    try {
      // Use the existing menu_images bucket for consistency
      const bucketName = 'menu_images';
      
      final filePath = 'store_items/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      
      await _supabase.storage
          .from(bucketName)
          .uploadBinary(filePath, imageBytes);

      final imageUrl = _supabase.storage
          .from(bucketName)
          .getPublicUrl(filePath);

      return imageUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}