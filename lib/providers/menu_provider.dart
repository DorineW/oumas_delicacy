// lib/providers/menu_provider.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/menu_item.dart';

class MenuProvider extends ChangeNotifier {
    // Returns the top 5 most expensive available menu items as a placeholder for popular items
    List<MenuItem> get popularItems {
      final available = _menuItems.where((item) => item.isAvailable).toList();
      available.sort((a, b) => b.price.compareTo(a.price));
      return available.take(5).toList();
    }
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
      
      // Query with all columns explicitly with timeout
      final response = await supabase
          .from('menu_items')
          .select('id, product_id, name, description, price, available, created_at, category, meal_weight, image_url')
          .order('name', ascending: true)
          .timeout(const Duration(seconds: 15));

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
      _menuItems = [];
      _error = 'Failed to load menu items: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Refresh menu items
  Future<void> refreshMenuItems() async {
    await loadMenuItems();
  }

  /// Helper method to upload an image and get its public URL
  Future<String?> _uploadImage(Uint8List imageBytes, String itemName) async {
    final supabase = Supabase.instance.client;
    // 1. Define your bucket name (MAKE SURE THIS BUCKET EXISTS IN YOUR SUPABASE PROJECT)
    const bucket = 'menu_images';

    // 2. Create a unique file path
    final fileExtension = 'jpg'; // Or 'png'. Depends on your compression
    final cleanItemName = itemName.replaceAll(' ', '_').replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
    final filePath = '$cleanItemName-${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

    try {
      debugPrint('📤 Uploading image to Storage...');
      // 3. Upload the bytes
      await supabase.storage.from(bucket).uploadBinary(
            filePath,
            imageBytes,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
              contentType: 'image/jpeg', // Use 'image/png' if you prefer
            ),
          );
      debugPrint('✅ Image uploaded, getting URL...');

      // 4. Get the public URL
      final publicUrl = supabase.storage.from(bucket).getPublicUrl(filePath);
      debugPrint('🔗 Public URL: $publicUrl');

      return publicUrl;

    } catch (e) {
      debugPrint('❌ Error uploading image: $e');
      _error = 'Failed to upload image: $e';
      notifyListeners();
      return null;
    }
  }

  // Add a new menu item
  Future<bool> addMenuItem(MenuItem item, Uint8List? imageBytes) async {
    try {
      debugPrint('➕ Adding new menu item: ${item.title}');
      
      final dataToInsert = item.toJson();

      // Upload image first if provided
      if (imageBytes != null) {
        final imageUrl = await _uploadImage(imageBytes, item.title);
        if (imageUrl == null) return false; // Upload failed
        dataToInsert['image_url'] = imageUrl;
      }
      
      final response = await Supabase.instance.client
          .from('menu_items')
          .insert(dataToInsert)
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
  Future<bool> updateMenuItem(MenuItem item, Uint8List? imageBytes) async {
    try {
      debugPrint('🔄 Updating menu item: ${item.title}');
      
      final dataToUpdate = item.toJson();

      // Check if a *new* image was picked
      if (imageBytes != null) {
        final newImageUrl = await _uploadImage(imageBytes, item.title);
        if (newImageUrl == null) return false; // Upload failed
        dataToUpdate['image_url'] = newImageUrl;
      }
      // If imageBytes is null, dataToUpdate['image_url'] already contains
      // the old URL (from the item object), so it will be preserved.

      await Supabase.instance.client
          .from('menu_items')
          .update(dataToUpdate)
          .eq('id', item.id!); // We need the ID to update!

      debugPrint('✅ Menu item updated');
      await loadMenuItems();
      return true;
    } catch (e) {
      debugPrint('❌ Error updating menu item: $e');
      _error = 'Failed to update menu item: $e';
      notifyListeners();
      return false;
    }
  }

  // Delete a menu item
  Future<bool> deleteMenuItem(MenuItem item) async {
    try {
      debugPrint('🗑️ Deleting menu item: ${item.id}');
      
      // TODO: Delete image from storage first, if it exists
      // if (item.imageUrl != null) {
      //   try {
      //     const bucket = 'menu_images';
      //     final client = Supabase.instance.client;
      //     // You need to parse the file name from the URL to delete it
      //     final fileName = item.imageUrl!.split('$bucket/').last;
      //     await client.storage.from(bucket).remove([fileName]);
      //     debugPrint('✅ Image deleted from storage');
      //   } catch (e) {
      //     debugPrint('⚠️ Could not delete image from storage: $e');
      //   }
      // }

      await Supabase.instance.client
          .from('menu_items')
          .delete()
          .eq('id', item.id!);

      debugPrint('✅ Menu item deleted from table');
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