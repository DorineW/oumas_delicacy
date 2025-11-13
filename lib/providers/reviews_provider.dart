import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Review {
  final String id;
  final String userAuthId;
  final String? productId;
  final int rating;
  final String? body;
  final DateTime createdAt;
  int likes;
  bool isLiked;
  String? userName; // ADDED: Customer name
  bool isAnonymous; // ADDED: Anonymous flag

  Review({
    required this.id,
    required this.userAuthId,
    this.productId,
    required this.rating,
    this.body,
    required this.createdAt,
    this.likes = 0,
    this.isLiked = false,
    this.userName,
    this.isAnonymous = false,
  });

  // ADDED: Parse from Supabase JSON (same pattern as MenuItem)
  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as String,
      userAuthId: json['user_auth_id'] as String,
      productId: json['product_id'] as String?,
      rating: (json['rating'] as int?) ?? 5,
      body: json['body'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      likes: 0,
      isLiked: false,
      userName: json['user_name'] as String?,
      isAnonymous: (json['is_anonymous'] as bool?) ?? false,
    );
  }

  // ADDED: Convert to JSON for Supabase (exclude id and created_at - let DB handle them)
  Map<String, dynamic> toJson() {
    return {
      'user_auth_id': userAuthId,
      'product_id': productId,
      'rating': rating,
      'body': body,
    };
  }

  String get displayComment => body ?? '';
  bool get hasComment => body != null && body!.isNotEmpty;
}

class ReviewsProvider with ChangeNotifier {
  List<Review> _reviews = [];
  bool _isLoading = false;
  String? _error;

  List<Review> get allReviews => _reviews;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // MAIN: Load reviews with detailed debugging (same pattern as MenuProvider)
  Future<void> loadReviews() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('🔄 Starting to load reviews from Supabase...');
      
      final supabase = Supabase.instance.client;
      debugPrint('✅ Supabase client initialized');
      
      // Query with all columns explicitly
      final response = await supabase
          .from('reviews')
          .select('id, user_auth_id, product_id, rating, body, created_at')
          .order('created_at', ascending: false);

      debugPrint('✅ Query executed successfully');
      debugPrint('📊 Response type: ${response.runtimeType}');
      debugPrint('📏 Number of reviews fetched: ${response.length}');

      if (response.isEmpty) {
        debugPrint('⚠️ No reviews found in database');
        _reviews = [];
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Parse each review with error handling
      final reviews = <Review>[];
      for (var i = 0; i < response.length; i++) {
        try {
          final json = response[i];
          debugPrint('--- Parsing review ${i + 1}/${response.length} ---');
          debugPrint('Raw JSON: $json');
          
          final review = Review.fromJson(json);
          
          // Fetch user name from users table
          try {
            final userRow = await supabase
                .from('users')
                .select('name, email')
                .eq('auth_id', review.userAuthId)
                .maybeSingle();
            
            if (userRow != null) {
              review.userName = (userRow['name'] as String?)?.trim();
              if (review.userName == null || review.userName!.isEmpty) {
                review.userName = (userRow['email'] as String?)?.split('@').first;
              }
            }
          } catch (e) {
            debugPrint('⚠️ Could not fetch user name: $e');
          }
          
          reviews.add(review);
          debugPrint('✅ Successfully parsed: Review ${review.id} - Rating ${review.rating}/5');
        } catch (e, stackTrace) {
          debugPrint('❌ Error parsing review ${i + 1}: $e');
          debugPrint('Failed JSON: ${response[i]}');
          debugPrint('Stack: $stackTrace');
        }
      }

      _reviews = reviews;
      _error = null;
      debugPrint('🎉 Successfully loaded ${reviews.length} reviews');
      
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading reviews: $e');
      debugPrint('Stack trace: $stackTrace');
      _error = 'Failed to load reviews: $e';
      _reviews = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Refresh reviews
  Future<void> refreshReviews() async {
    await loadReviews();
  }

  // Get reviews for a specific product
  List<Review> getReviewsForProduct(String productId) {
    final productReviews = _reviews.where((r) => r.productId == productId).toList();
    
    // Sort: comments first, then by date (newest first)
    productReviews.sort((a, b) {
      if (a.hasComment && !b.hasComment) return -1;
      if (!a.hasComment && b.hasComment) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    
    return productReviews;
  }

  // Get average rating for a product
  double getAverageRating(String productId) {
    final productReviews = _reviews.where((r) => r.productId == productId).toList();
    if (productReviews.isEmpty) return 4.5; // Default rating
    
    final sum = productReviews.fold<int>(0, (sum, review) => sum + review.rating);
    return sum / productReviews.length;
  }

  // Get review count for a product
  int getReviewCount(String productId) {
    return _reviews.where((r) => r.productId == productId).length;
  }

  // Add a new review
  Future<bool> addReview(Review review) async {
    try {
      debugPrint('➕ Adding new review for product: ${review.productId}');
      
      final response = await Supabase.instance.client
          .from('reviews')
          .insert(review.toJson())
          .select()
          .single();

      debugPrint('✅ Review added: $response');
      await loadReviews(); // Reload to get fresh data
      return true;
    } catch (e) {
      debugPrint('❌ Error adding review: $e');
      _error = 'Failed to add review: $e';
      notifyListeners();
      return false;
    }
  }

  // Toggle like on a review
  void toggleLike(String reviewId) {
    final index = _reviews.indexWhere((r) => r.id == reviewId);
    if (index != -1) {
      _reviews[index].isLiked = !_reviews[index].isLiked;
      _reviews[index].likes += _reviews[index].isLiked ? 1 : -1;
      notifyListeners();
    }
  }

  // Get rating distribution for a product (for progress bars)
  Map<int, double> getRatingDistribution(String productId) {
    final productReviews = _reviews.where((r) => r.productId == productId).toList();
    final total = productReviews.length;
    
    if (total == 0) {
      return {5: 0.7, 4: 0.2, 3: 0.1, 2: 0.0, 1: 0.0}; // Default distribution
    }
    
    final distribution = <int, double>{};
    for (int i = 1; i <= 5; i++) {
      final count = productReviews.where((r) => r.rating == i).length;
      distribution[i] = count / total;
    }
    
    return distribution;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
