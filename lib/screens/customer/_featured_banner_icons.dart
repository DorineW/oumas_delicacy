// Helper function to get appropriate icons for categories
import 'package:flutter/material.dart';

IconData getIconForCategory(String category) {
  switch (category.toLowerCase()) {
    case 'fruits':
      return Icons.apple;
    case 'vegetables':
      return Icons.eco;
    case 'dairy':
      return Icons.local_drink;
    case 'meat':
      return Icons.set_meal;
    case 'bakery':
      return Icons.bakery_dining;
    case 'beverages':
      return Icons.local_cafe;
    default:
      return Icons.shopping_basket;
  }
}
