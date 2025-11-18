import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

enum FavoriteItemType {
  menuItem('menu_item'),
  storeItem('store_item');

  final String value;
  const FavoriteItemType(this.value);

  static FavoriteItemType fromString(String value) {
    return FavoriteItemType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => FavoriteItemType.menuItem,
    );
  }
}

class Favorite {
  final String id;
  final String userAuthId;
  final String productId;
  final FavoriteItemType itemType;
  final DateTime createdAt;

  Favorite({
    required this.id,
    required this.userAuthId,
    required this.productId,
    required this.itemType,
    required this.createdAt,
  });

  // ADDED: Parse from Supabase JSON (same pattern as MenuItem)
  factory Favorite.fromJson(Map<String, dynamic> json) {
    return Favorite(
      id: json['id'] as String,
      userAuthId: json['user_auth_id'] as String,
      productId: json['product_id'] as String,
      itemType: FavoriteItemType.fromString(json['item_type'] as String? ?? 'menu_item'),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  // ADDED: Convert to JSON for Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_auth_id': userAuthId,
      'product_id': productId,
      'item_type': itemType.value,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class FavoritesProvider with ChangeNotifier {
  List<Favorite> _favorites = [];
  bool _isLoading = false;
  String? _error;
  String? _currentUserId;
  bool _cacheLoaded = false;

  // Cache keys
  static const String _cacheKey = 'cached_favorites';
  static const String _cacheTimestampKey = 'favorites_cache_timestamp';
  static const Duration _cacheValidDuration = Duration(hours: 24);

  List<Favorite> get allFavorites => _favorites;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load cached favorites from SharedPreferences
  Future<void> _loadFromCache() async {
    if (_cacheLoaded) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_cacheKey);
      final timestamp = prefs.getInt(_cacheTimestampKey);
      
      if (cachedData != null && timestamp != null) {
        final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
        final isCacheValid = cacheAge < _cacheValidDuration.inMilliseconds;
        
        final List<dynamic> jsonList = json.decode(cachedData);
        _favorites = jsonList.map((json) => Favorite.fromJson(json)).toList();
        _cacheLoaded = true;
        
        debugPrint('📦 Loaded ${_favorites.length} favorites from cache (age: ${(cacheAge / 1000 / 60).toStringAsFixed(0)} minutes, valid: $isCacheValid)');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error loading favorites cache: $e');
    }
  }

  /// Save favorites to SharedPreferences cache
  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _favorites.map((fav) => fav.toJson()).toList();
      final jsonString = json.encode(jsonList);
      
      await prefs.setString(_cacheKey, jsonString);
      await prefs.setInt(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
      
      debugPrint('💾 Cached ${_favorites.length} favorites to local storage');
    } catch (e) {
      debugPrint('❌ Error saving favorites cache: $e');
    }
  }

  // Set current user (call after login)
  void setCurrentUser(String? userId) {
    _currentUserId = userId;
    if (userId != null) {
      loadFavorites(userId);
    } else {
      _favorites = [];
      notifyListeners();
    }
  }

  // MAIN: Load favorites with detailed debugging (same pattern as MenuProvider)
  Future<void> loadFavorites(String userId) async {
    // Load from cache first if not already loaded
    if (!_cacheLoaded) {
      await _loadFromCache();
    }
    
    // Preserve existing data during loading
    final cachedFavorites = List<Favorite>.from(_favorites);
    
    _isLoading = true;
    _error = null;
    _currentUserId = userId;
    notifyListeners();

    try {
      debugPrint('🔄 Starting to load favorites from Supabase for user: $userId...');
      
      final supabase = Supabase.instance.client;
      debugPrint('✅ Supabase client initialized');
      
      // Query with all columns explicitly with timeout
      final response = await supabase
          .from('favorites')
          .select('id, user_auth_id, product_id, item_type, created_at')
          .eq('user_auth_id', userId)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 10));

      debugPrint('✅ Query executed successfully');
      debugPrint('📊 Response type: ${response.runtimeType}');
      debugPrint('📏 Number of favorites fetched: ${response.length}');

      if (response.isEmpty) {
        debugPrint('⚠️ No favorites found for this user');
        _favorites = [];
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Parse each favorite with error handling
      final favorites = <Favorite>[];
      for (var i = 0; i < response.length; i++) {
        try {
          final json = response[i];
          debugPrint('--- Parsing favorite ${i + 1}/${response.length} ---');
          debugPrint('Raw JSON: $json');
          
          final favorite = Favorite.fromJson(json);
          favorites.add(favorite);
          debugPrint('✅ Successfully parsed: Favorite ${favorite.id} - Product ${favorite.productId}');
        } catch (e, stackTrace) {
          debugPrint('❌ Error parsing favorite ${i + 1}: $e');
          debugPrint('Failed JSON: ${response[i]}');
          debugPrint('Stack: $stackTrace');
        }
      }

      _favorites = favorites;
      _error = null;
      debugPrint('🎉 Successfully loaded ${favorites.length} favorites');
      
      // Save to cache for offline use
      await _saveToCache();
      
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading favorites: $e');
      debugPrint('Stack trace: $stackTrace');
      
      // Restore cached data on error
      _favorites = cachedFavorites;
      
      // Set appropriate error message
      _error = cachedFavorites.isEmpty
          ? 'No internet connection. Please check your network.'
          : 'Limited connectivity. Showing cached favorites.';
      
      debugPrint('📦 Restored ${cachedFavorites.length} cached favorites');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Refresh favorites
  Future<void> refreshFavorites() async {
    if (_currentUserId != null) {
      await loadFavorites(_currentUserId!);
    }
  }

  // Check if a product is favorited
  bool isFavorite(String userId, String productId, {FavoriteItemType type = FavoriteItemType.menuItem}) {
    return _favorites.any((f) => 
      f.productId == productId && 
      f.userAuthId == userId &&
      f.itemType == type
    );
  }

  // Get all favorite product IDs for a user (optionally filtered by type)
  Set<String> getFavoriteIds(String userId, {FavoriteItemType? type}) {
    return _favorites
        .where((f) => 
          f.userAuthId == userId &&
          (type == null || f.itemType == type)
        )
        .map((f) => f.productId)
        .toSet();
  }

  // Get favorites for a specific user (optionally filtered by type)
  List<String> getFavoritesForUser(String userId, {FavoriteItemType? type}) {
    return _favorites
        .where((f) => 
          f.userAuthId == userId &&
          (type == null || f.itemType == type)
        )
        .map((f) => f.productId)
        .toList();
  }

  // Get count for a specific user (optionally filtered by type)
  int getCountForUser(String userId, {FavoriteItemType? type}) {
    return _favorites.where((f) => 
      f.userAuthId == userId &&
      (type == null || f.itemType == type)
    ).length;
  }

  // Toggle favorite status
  Future<void> toggleFavorite(String userId, String productId, {FavoriteItemType type = FavoriteItemType.menuItem}) async {
    try {
      final isFav = isFavorite(userId, productId, type: type);
      
      if (isFav) {
        // Remove from favorites
        debugPrint('➖ Removing from favorites: $productId (${type.value})');
        final favorite = _favorites.firstWhere(
          (f) => f.productId == productId && f.userAuthId == userId && f.itemType == type,
        );
        
        await Supabase.instance.client
            .from('favorites')
            .delete()
            .eq('id', favorite.id);

        debugPrint('✅ Removed from favorites');
        _favorites.removeWhere(
          (f) => f.productId == productId && f.userAuthId == userId && f.itemType == type,
        );
        
      } else {
        // Add to favorites
        debugPrint('➕ Adding to favorites: $productId (${type.value})');
        
        final response = await Supabase.instance.client
            .from('favorites')
            .insert({
              'user_auth_id': userId,
              'product_id': productId,
              'item_type': type.value,
            })
            .select()
            .single();

        debugPrint('✅ Added to favorites: $response');
        final newFavorite = Favorite.fromJson(response);
        _favorites.add(newFavorite);
      }
      
      notifyListeners();
      
    } catch (e) {
      debugPrint('❌ Error toggling favorite: $e');
      _error = e.toString();
      notifyListeners();
      rethrow; // Re-throw so UI can show error
    }
  }

  // Get count of favorites for current user
  int get favoriteCount => _favorites.where((f) => f.userAuthId == _currentUserId).length;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearFavorites() {
    _favorites = [];
    _currentUserId = null;
    notifyListeners();
  }

  // Clear favorites for a user (logout)
  void clearUserFavorites(String userId) {
    _favorites.removeWhere((f) => f.userAuthId == userId);
    if (_currentUserId == userId) {
      _currentUserId = null;
    }
    notifyListeners();
  }
}
