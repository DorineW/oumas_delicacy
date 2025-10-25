import 'package:flutter/foundation.dart';

class Review {
  final String orderId;
  final String mealTitle;
  final String userName;
  final bool isAnonymous;
  final int rating;
  final String comment;
  final DateTime date;
  int likes;
  bool isLiked;

  Review({
    required this.orderId,
    required this.mealTitle,
    required this.userName,
    required this.isAnonymous,
    required this.rating,
    required this.comment,
    required this.date,
    this.likes = 0,
    this.isLiked = false,
  });

  String get displayName => isAnonymous ? 'Anonymous User' : userName;
}

class ReviewsProvider with ChangeNotifier {
  final List<Review> _reviews = [];

  List<Review> get allReviews => _reviews;

  // Get reviews for a specific meal, sorted with comments first
  List<Review> getReviewsForMeal(String mealTitle) {
    final mealReviews = _reviews.where((r) => r.mealTitle == mealTitle).toList();
    
    // Sort: comments first, then by date (newest first)
    mealReviews.sort((a, b) {
      // Comments take priority
      if (a.comment.isNotEmpty && b.comment.isEmpty) return -1;
      if (a.comment.isEmpty && b.comment.isNotEmpty) return 1;
      
      // Then by date
      return b.date.compareTo(a.date);
    });
    
    return mealReviews;
  }

  // Get average rating for a meal
  double getAverageRating(String mealTitle) {
    final mealReviews = _reviews.where((r) => r.mealTitle == mealTitle).toList();
    if (mealReviews.isEmpty) return 4.5; // Default rating
    
    final sum = mealReviews.fold<int>(0, (sum, review) => sum + review.rating);
    return sum / mealReviews.length;
  }

  // Get review count for a meal
  int getReviewCount(String mealTitle) {
    return _reviews.where((r) => r.mealTitle == mealTitle).length;
  }

  // Add a new review
  void addReview(Review review) {
    _reviews.add(review);
    notifyListeners();
  }

  // Toggle like on a review
  void toggleLike(String orderId, String mealTitle) {
    final review = _reviews.firstWhere(
      (r) => r.orderId == orderId && r.mealTitle == mealTitle,
      orElse: () => _reviews.first,
    );
    
    review.isLiked = !review.isLiked;
    review.likes += review.isLiked ? 1 : -1;
    notifyListeners();
  }

  // Get rating distribution for a meal (for progress bars)
  Map<int, double> getRatingDistribution(String mealTitle) {
    final mealReviews = _reviews.where((r) => r.mealTitle == mealTitle).toList();
    final total = mealReviews.length;
    
    if (total == 0) {
      return {5: 0.7, 4: 0.2, 3: 0.1, 2: 0.0, 1: 0.0}; // Default distribution
    }
    
    final distribution = <int, double>{};
    for (int i = 1; i <= 5; i++) {
      final count = mealReviews.where((r) => r.rating == i).length;
      distribution[i] = count / total;
    }
    
    return distribution;
  }
}
