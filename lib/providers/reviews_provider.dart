import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class Review {
  final String id;
  final String userAuthId;
  final String? productId;
  final int rating;
  final String? body;
  final DateTime createdAt;
  int likes;
  bool isLiked;
  String? userName;
  bool isAnonymous;

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

  Map<String, dynamic> toJson() {
    return {
      'user_auth_id': userAuthId,
      'product_id': productId,
      'rating': rating,
      'body': body,
      'is_anonymous': isAnonymous,
    };
  }

  String get displayName {
    if (isAnonymous) {
      return 'Anonymous';
    }
    return userName ?? 'User';
  }

  String get displayComment => body ?? '';
  bool get hasComment => body != null && body!.isNotEmpty;
}

class ReviewsProvider with ChangeNotifier {
  List<Review> _reviews = [];
  bool _isLoading = false;
  String? _error;
  bool _cacheLoaded = false;

  static const String _cacheKey = 'cached_reviews';
  static const String _cacheTimestampKey = 'reviews_cache_timestamp';
  static const Duration _cacheValidDuration = Duration(hours: 24);

  List<Review> get allReviews => _reviews;
  bool get isLoading => _isLoading;
  String? get error => _error;

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
        _reviews = jsonList.map((json) => Review.fromJson(json)).toList();
        _cacheLoaded = true;
        
        debugPrint('📦 Loaded ${_reviews.length} reviews from cache (age: ${(cacheAge / 1000 / 60).toStringAsFixed(0)} minutes, valid: $isCacheValid)');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error loading reviews cache: $e');
    }
  }

  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _reviews.map((review) => {
        'id': review.id,
        'user_auth_id': review.userAuthId,
        'product_id': review.productId,
        'rating': review.rating,
        'body': review.body,
        'created_at': review.createdAt.toIso8601String(),
        'user_name': review.userName,
        'is_anonymous': review.isAnonymous,
      }).toList();
      final jsonString = json.encode(jsonList);
      
      await prefs.setString(_cacheKey, jsonString);
      await prefs.setInt(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
      debugPrint('💾 Cached ${_reviews.length} reviews to local storage');
    } catch (e) {
      debugPrint('❌ Error saving reviews cache: $e');
    }
  }

  Future<void> loadReviews() async {
    if (!_cacheLoaded) {
      await _loadFromCache();
    }
    
    final cachedReviews = List<Review>.from(_reviews);
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('🔄 Starting to load reviews from Supabase...');
      
      final supabase = Supabase.instance.client;
      debugPrint('✅ Supabase client initialized');
      
      final response = await supabase
          .from('reviews')
          .select('id, user_auth_id, product_id, rating, body, created_at, is_anonymous')
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 10));

      debugPrint('✅ Query executed successfully');
      debugPrint('📏 Number of reviews fetched: ${response.length}');

      if (response.isEmpty) {
        debugPrint('⚠️ No reviews found in database');
        _reviews = [];
        _isLoading = false;
        notifyListeners();
        return;
      }

      final reviews = <Review>[];
      for (var i = 0; i < response.length; i++) {
        try {
          final json = response[i];
          final review = Review.fromJson(json);
          
          // Fetch user name from users table ONLY if not anonymous
          try {
            if (!review.isAnonymous) {
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
            } else {
              // For anonymous reviews, ensure userName is null
              review.userName = null;
            }
          } catch (e) {
            debugPrint('⚠️ Could not fetch user name: $e');
          }
          
          reviews.add(review);
        } catch (e, stackTrace) {
          debugPrint('❌ Error parsing review ${i + 1}: $e');
          debugPrint('Stack: $stackTrace');
        }
      }

      _reviews = reviews;
      _error = null;
      debugPrint('🎉 Successfully loaded ${reviews.length} reviews');
      
      await _saveToCache();
      
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading reviews: $e');
      debugPrint('Stack trace: $stackTrace');
      _error = cachedReviews.isEmpty
          ? 'No internet connection. Please check your network.'
          : 'Limited connectivity. Showing cached reviews.';
      _reviews = cachedReviews;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshReviews() async {
    await loadReviews();
  }

  List<Review> getReviewsForProduct(String productId) {
    final productReviews = _reviews.where((r) => r.productId == productId).toList();
    
    productReviews.sort((a, b) {
      if (a.hasComment && !b.hasComment) return -1;
      if (!a.hasComment && b.hasComment) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    
    return productReviews;
  }

  double getAverageRating(String productId) {
    final productReviews = _reviews.where((r) => r.productId == productId).toList();
    if (productReviews.isEmpty) return 4.5;
    
    final sum = productReviews.fold<int>(0, (sum, review) => sum + review.rating);
    return sum / productReviews.length;
  }

  int getReviewCount(String productId) {
    return _reviews.where((r) => r.productId == productId).length;
  }

  Future<bool> addReview(Review review) async {
    try {
      debugPrint('➕ Adding new review for product: ${review.productId}');
      debugPrint('📝 Anonymous: ${review.isAnonymous}');
      
      final response = await Supabase.instance.client
          .from('reviews')
          .insert(review.toJson())
          .select()
          .single();

      debugPrint('✅ Review added: $response');
      await loadReviews();
      return true;
    } catch (e) {
      debugPrint('❌ Error adding review: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void toggleLike(String reviewId) {
    final index = _reviews.indexWhere((r) => r.id == reviewId);
    if (index != -1) {
      _reviews[index].isLiked = !_reviews[index].isLiked;
      _reviews[index].likes += _reviews[index].isLiked ? 1 : -1;
      notifyListeners();
    }
  }

  Map<int, double> getRatingDistribution(String productId) {
    final productReviews = _reviews.where((r) => r.productId == productId).toList();
    final total = productReviews.length;
    
    if (total == 0) {
      return {5: 0.7, 4: 0.2, 3: 0.1, 2: 0.0, 1: 0.0};
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