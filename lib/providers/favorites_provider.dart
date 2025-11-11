import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Favorite {
  final String id;
  final String userAuthId;
  final String productId;
  final DateTime createdAt;

  Favorite({
    required this.id,
    required this.userAuthId,
    required this.productId,
    required this.createdAt,
  });

  // ADDED: Parse from Supabase JSON (same pattern as MenuItem)
  factory Favorite.fromJson(Map<String, dynamic> json) {
    return Favorite(
      id: json['id'] as String,
      userAuthId: json['user_auth_id'] as String,
      productId: json['product_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  // ADDED: Convert to JSON for Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_auth_id': userAuthId,
      'product_id': productId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class FavoritesProvider with ChangeNotifier {
  List<Favorite> _favorites = [];
  bool _isLoading = false;
  String? _error;
  String? _currentUserId;

  List<Favorite> get allFavorites => _favorites;
  bool get isLoading => _isLoading;
  String? get error => _error;

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
    _isLoading = true;
    _error = null;
    _currentUserId = userId;
    notifyListeners();

    try {
      debugPrint('🔄 Starting to load favorites from Supabase for user: $userId...');
      
      final supabase = Supabase.instance.client;
      debugPrint('✅ Supabase client initialized');
      
      // Query with all columns explicitly
      final response = await supabase
          .from('favorites')
          .select('id, user_auth_id, product_id, created_at')
          .eq('user_auth_id', userId)
          .order('created_at', ascending: false);

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
      
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading favorites: $e');
      debugPrint('Stack trace: $stackTrace');
      _error = 'Failed to load favorites: $e';
      _favorites = [];
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
  bool isFavorite(String userId, String productId) {
    return _favorites.any((f) => f.productId == productId && f.userAuthId == userId);
  }

  // Get all favorite product IDs for a user
  Set<String> getFavoriteIds(String userId) {
    return _favorites
        .where((f) => f.userAuthId == userId)
        .map((f) => f.productId)
        .toSet();
  }

  // Get favorites for a specific user
  List<String> getFavoritesForUser(String userId) {
    return _favorites
        .where((f) => f.userAuthId == userId)
        .map((f) => f.productId)
        .toList();
  }

  // Get count for a specific user
  int getCountForUser(String userId) {
    return _favorites.where((f) => f.userAuthId == userId).length;
  }

  // Toggle favorite status
  Future<void> toggleFavorite(String userId, String productId) async {
    try {
      final isFav = isFavorite(userId, productId);
      
      if (isFav) {
        // Remove from favorites
        debugPrint('➖ Removing from favorites: $productId');
        final favorite = _favorites.firstWhere(
          (f) => f.productId == productId && f.userAuthId == userId,
        );
        
        await Supabase.instance.client
            .from('favorites')
            .delete()
            .eq('id', favorite.id);

        debugPrint('✅ Removed from favorites');
        _favorites.removeWhere(
          (f) => f.productId == productId && f.userAuthId == userId,
        );
        
      } else {
        // Add to favorites
        debugPrint('➕ Adding to favorites: $productId');
        
        final response = await Supabase.instance.client
            .from('favorites')
            .insert({
              'user_auth_id': userId,
              'product_id': productId,
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
      _error = 'Failed to update favorite: $e';
      notifyListeners();
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
