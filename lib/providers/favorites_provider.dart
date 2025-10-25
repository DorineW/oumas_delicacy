import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesProvider with ChangeNotifier {
  // Map of userId to their favorite meal titles
  final Map<String, Set<String>> _userFavorites = {};

  FavoritesProvider() {
    _loadFavorites();
  }

  // Get favorites for a specific user
  List<String> getFavoritesForUser(String userId) {
    return _userFavorites[userId]?.toList() ?? [];
  }

  // Get count for a specific user
  int getCountForUser(String userId) {
    return _userFavorites[userId]?.length ?? 0;
  }

  // Check if a meal is favorited by a user
  bool isFavorite(String userId, String mealTitle) {
    return _userFavorites[userId]?.contains(mealTitle) ?? false;
  }

  // Toggle favorite for a user
  void toggleFavorite(String userId, String mealTitle) {
    if (_userFavorites[userId] == null) {
      _userFavorites[userId] = {};
    }

    if (_userFavorites[userId]!.contains(mealTitle)) {
      _userFavorites[userId]!.remove(mealTitle);
    } else {
      _userFavorites[userId]!.add(mealTitle);
    }

    _saveFavorites();
    notifyListeners();
  }

  // Load favorites from SharedPreferences
  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('favorites_'));

      for (final key in keys) {
        final userId = key.replaceFirst('favorites_', '');
        final favorites = prefs.getStringList(key) ?? [];
        _userFavorites[userId] = Set.from(favorites);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading favorites: $e');
    }
  }

  // Save favorites to SharedPreferences
  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      for (final entry in _userFavorites.entries) {
        await prefs.setStringList(
          'favorites_${entry.key}',
          entry.value.toList(),
        );
      }
    } catch (e) {
      debugPrint('Error saving favorites: $e');
    }
  }

  // Clear favorites for a user
  void clearUserFavorites(String userId) {
    _userFavorites.remove(userId);
    _saveFavorites();
    notifyListeners();
  }
}
