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

  StoreProvider(this._supabase);

  List<StoreItem> get storeItems => _storeItems;
  List<Location> get locations => _locations;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<StoreItem> get availableItems => 
      _storeItems.where((item) => item.available).toList();

  List<StoreItem> get lowStockItems =>
      _storeItems.where((item) => (item.currentStock ?? 0) <= (item.currentStock ?? 0) * 0.2).toList();

  Future<void> loadStoreItems() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('StoreItems')
          .select('''
            *,
            products:product_id(
              *,
              ProductInventory(*, locations(*))
            )
          ''')
          .order('created_at', ascending: false);

      _storeItems = (response as List)
          .map((json) => StoreItem.fromJson(json))
          .toList();

      // Load locations separately
      await _loadLocations();
      
    } catch (e) {
      _error = 'Failed to load store items: $e';
      debugPrint('Error loading store items: $e');
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

  Future<void> addStoreItem(StoreItem item, String? locationId, int initialStock) async {
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
      };
      
      // Only include unit_description if it exists (for backward compatibility)
      if (item.unitDescription != null && item.unitDescription!.isNotEmpty) {
        storeItemData['unit_description'] = item.unitDescription;
      }
      
      await _supabase
          .from('StoreItems')
          .insert(storeItemData);

      // 3. Create initial inventory if location is provided
      if (locationId != null && initialStock > 0) {
        await _supabase
            .from('ProductInventory')
            .insert({
              'product_id': productId,
              'location_id': locationId,
              'quantity': initialStock,
              'minimum_stock_alert': 10,
            });
      }

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
      // Check if inventory record exists
      final existingInventory = await _supabase
          .from('ProductInventory')
          .select()
          .eq('product_id', productId)
          .eq('location_id', locationId);

      if (existingInventory.isEmpty) {
        // Create new inventory record
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
        await _supabase
            .from('ProductInventory')
            .update({
              'quantity': quantity,
              'last_restock_date': DateTime.now().toIso8601String(),
            })
            .eq('product_id', productId)
            .eq('location_id', locationId);
      }

      await loadStoreItems(); // Reload to reflect changes
    } catch (e) {
      _error = 'Failed to update inventory: $e';
      debugPrint('Error updating inventory: $e');
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