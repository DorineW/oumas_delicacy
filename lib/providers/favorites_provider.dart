import 'package:flutter/foundation.dart';

class FavoritesProvider extends ChangeNotifier {
  final Set<String> _favoriteIds = {};

  Set<String> get favoriteIds => _favoriteIds;

  bool isFavorite(String mealTitle) {
    return _favoriteIds.contains(mealTitle);
  }

  void toggleFavorite(String mealTitle) {
    if (_favoriteIds.contains(mealTitle)) {
      _favoriteIds.remove(mealTitle);
    } else {
      _favoriteIds.add(mealTitle);
    }
    notifyListeners();
  }

  void addFavorite(String mealTitle) {
    _favoriteIds.add(mealTitle);
    notifyListeners();
  }

  void removeFavorite(String mealTitle) {
    _favoriteIds.remove(mealTitle);
    notifyListeners();
  }

  void clearFavorites() {
    _favoriteIds.clear();
    notifyListeners();
  }

  int get favoritesCount => _favoriteIds.length;
}
