// lib/screens/meal_detail_screen.dart
// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../constants/colors.dart';
import '../models/cart_item.dart';
import '../models/menu_item.dart'; // ADDED
import '../providers/cart_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/reviews_provider.dart'; // ADDED
import '../services/auth_service.dart'; // ADDED
import '../providers/menu_provider.dart'; // ADDED

class MealDetailScreen extends StatefulWidget {
  final MenuItem meal; // CHANGED: from Map<String, dynamic>

  const MealDetailScreen({
    super.key,
    required this.meal,
  });

  @override
  State<MealDetailScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends State<MealDetailScreen> {
  int quantity = 1;
  bool showDetails = true;

  // UPDATED: Convert to MenuItem objects (or fetch from MenuProvider)
  List<MenuItem> get similarMeals {
    // In a real app, you'd fetch these from MenuProvider based on category
    // For now, we'll return an empty list or create dummy MenuItem objects
    return [];
  }

  @override
  void initState() {
    super.initState();
    // Calculate average rating from reviews
    // REMOVED: Dummy reviews, now using ReviewsProvider
  }

  Widget _buildMealImage(dynamic imageVal) {
    if (imageVal == null) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary.withOpacity(0.1), AppColors.accent.withOpacity(0.1)],
          ),
        ),
        child: Icon(Icons.fastfood, size: 80, color: AppColors.primary.withOpacity(0.3)),
      );
    }

    if (imageVal is Uint8List || imageVal is List<int>) {
      return Image.memory(
        imageVal is Uint8List ? imageVal : Uint8List.fromList(imageVal as List<int>),
        fit: BoxFit.cover,
      );
    }

    final imgPath = imageVal.toString();
    if (imgPath.startsWith('assets/')) {
      return Image.asset(imgPath, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildFallbackImage());
    }
    if (imgPath.startsWith('http')) {
      return Image.network(imgPath, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildFallbackImage());
    }

    if (!kIsWeb) {
      try {
        return Image.file(File(imgPath), fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildFallbackImage());
      } catch (_) {}
    }

    return _buildFallbackImage();
  }

  Widget _buildFallbackImage() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary.withOpacity(0.1), AppColors.accent.withOpacity(0.1)],
        ),
      ),
      child: Icon(Icons.fastfood, size: 80, color: AppColors.primary.withOpacity(0.3)),
    );
  }

  Widget _buildSimilarMealCard(MenuItem meal, BuildContext context) { // CHANGED: Accept MenuItem
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MealDetailScreen(meal: meal), // Already correct type
          ),
        );
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Meal image - FIXED: Reduced height for better proportions
            Container(
              height: 100,
              width: double.infinity,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: _buildMealImage(meal.imageUrl), // FIXED: Use meal.imageUrl
              ),
            ),

            // Content - REMOVED: Quantity controls and cart button
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      meal.title, // FIXED
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.darkText,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // Category
                    Text(
                      meal.category, // FIXED
                      style: TextStyle(
                        color: AppColors.darkText.withOpacity(0.6),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    // Rating and Price row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.star, size: 14, color: Colors.amber),
                            const SizedBox(width: 2),
                            Text(
                              meal.rating.toString(), // FIXED
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Flexible(
                          child: Text(
                            'Ksh ${meal.price}', // FIXED
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final auth = context.watch<AuthService>();
    final favoritesProvider = context.watch<FavoritesProvider>();
    final reviewsProvider = context.watch<ReviewsProvider>();
    final userId = auth.currentUser?.id ?? 'guest';

    // FIXED: Use MenuItem properties directly
    final isFavorite = favoritesProvider.isFavorite(userId, widget.meal.title);
    final reviews = reviewsProvider.getReviewsForMeal(widget.meal.title);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Modern app bar with image
          SliverAppBar(
            expandedHeight: 280.0,
            pinned: true,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Background image with gradient overlay
                  _buildMealImage(widget.meal.imageUrl),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          AppColors.primary.withOpacity(0.9),
                          Colors.transparent,
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              // UPDATED: Use proper favorites provider
              IconButton(
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : Colors.white,
                ),
                onPressed: () {
                  favoritesProvider.toggleFavorite(userId, widget.meal.title);
                  HapticFeedback.lightImpact();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isFavorite 
                            ? 'Removed from favorites' 
                            : 'Added to favorites',
                      ),
                      duration: const Duration(seconds: 1),
                      backgroundColor: isFavorite ? Colors.grey : Colors.red,
                    ),
                  );
                },
              ),
            ],
          ),

          // Content
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and price
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.meal.title, // FIXED
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.darkText,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  widget.meal.category, // FIXED
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "Ksh ${widget.meal.price}", // FIXED
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.star, size: 16, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text(
                                  widget.meal.rating.toString(), // FIXED
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  " (${reviews.length})", // UPDATED: Use actual review count
                                  style: TextStyle(
                                    color: AppColors.darkText.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Modern tab selector
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => showDetails = true),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                decoration: BoxDecoration(
                                  color: showDetails ? AppColors.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    "About",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: showDetails ? Colors.white : AppColors.darkText,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => showDetails = false),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                decoration: BoxDecoration(
                                  color: !showDetails ? AppColors.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    "Reviews",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: !showDetails ? Colors.white : AppColors.darkText,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Content based on tab selection
                    if (showDetails) _buildAboutSection(widget.meal.description ?? ''),
                    if (!showDetails) _buildReviewsSection(widget.meal.title, reviewsProvider), // UPDATED: Pass provider
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      // Modern bottom bar
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Quantity selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 20, color: AppColors.primary),
                      onPressed: () {
                        if (quantity > 1) setState(() => quantity--);
                        HapticFeedback.lightImpact();
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36),
                    ),
                    SizedBox(
                      width: 30,
                      child: Text(
                        '$quantity',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 20, color: AppColors.primary),
                      onPressed: () {
                        setState(() => quantity++);
                        HapticFeedback.lightImpact();
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Add to cart button
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();

                    final cartItem = CartItem(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      mealTitle: widget.meal.title, // FIXED
                      mealImage: widget.meal.imageUrl ?? '', // FIXED
                      price: widget.meal.price, // FIXED
                      quantity: quantity,
                    );

                    bool added = false;
                    try {
                      cart.addItem(cartItem);
                      added = true;
                    } catch (e) {
                      debugPrint('Error adding to cart: $e');
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(added ? "✅ ${widget.meal.title} added to cart" : "❌ Could not add to cart"),
                        backgroundColor: added ? AppColors.success : Colors.red,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_shopping_cart, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Add • Ksh ${widget.meal.price * quantity}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAboutSection(String description) {
    final menuProvider = context.read<MenuProvider>(); // ADDED
    
    // ADDED: Get similar meals from same category
    final sameCategoryMeals = menuProvider.menuItems
        .where((item) => 
            item.category == widget.meal.category && 
            item.title != widget.meal.title &&
            menuProvider.isItemAvailable(item.title))
        .take(5)
        .toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Description
        Text(
          description,
          style: TextStyle(
            fontSize: 16,
            height: 1.6,
            color: AppColors.darkText.withOpacity(0.8),
          ),
        ),
        
        // UPDATED: Only show similar meals section if we have items
        if (sameCategoryMeals.isNotEmpty) ...[
          const SizedBox(height: 32),
          const Row(
            children: [
              Text(
                "Others You Might Like",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                ),
              ),
              Spacer(),
              Text(
                "See all",
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: sameCategoryMeals.length,
              itemBuilder: (context, index) {
                return _buildSimilarMealCard(sameCategoryMeals[index], context);
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReviewsSection(String mealTitle, ReviewsProvider reviewsProvider) { // UPDATED: Accept provider
    final reviews = reviewsProvider.getReviewsForMeal(mealTitle);
    final averageRating = reviewsProvider.getAverageRating(mealTitle);
    final distribution = reviewsProvider.getRatingDistribution(mealTitle);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Average rating summary
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Average rating
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    averageRating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  StarRating(rating: averageRating, size: 20),
                  const SizedBox(height: 4),
                  Text(
                    "${reviews.length} reviews", // UPDATED: Use actual count
                    style: TextStyle(
                      color: AppColors.darkText.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRatingBar(5, distribution[5] ?? 0.0), // UPDATED: Use actual distribution
                    _buildRatingBar(4, distribution[4] ?? 0.0),
                    _buildRatingBar(3, distribution[3] ?? 0.0),
                    _buildRatingBar(2, distribution[2] ?? 0.0),
                    _buildRatingBar(1, distribution[1] ?? 0.0),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // UPDATED: Show real reviews or empty state
        if (reviews.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.rate_review_outlined,
                    size: 60,
                    color: AppColors.darkText.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Reviews Yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkText.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Be the first to review this meal!',
                    style: TextStyle(
                      color: AppColors.darkText.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          // Reviews list
          ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: reviews.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final review = reviews[index];
              return _buildReviewCard(review, mealTitle, reviewsProvider); // UPDATED
            },
          ),
      ],
    );
  }

  Widget _buildRatingBar(int stars, double percentage) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            "$stars",
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.star, size: 16, color: Colors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: AppColors.lightGray,
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "${(percentage * 100).toInt()}%",
            style: TextStyle(fontSize: 12, color: AppColors.darkText.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Review review, String mealTitle, ReviewsProvider reviewsProvider) { // UPDATED
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: review.isAnonymous ? Colors.grey : AppColors.primary, // UPDATED
                child: Icon(
                  review.isAnonymous ? Icons.person_off : Icons.person, // UPDATED
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          review.displayName, // UPDATED: Use displayName
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (review.isAnonymous) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.visibility_off,
                            size: 14,
                            color: AppColors.darkText.withOpacity(0.5),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      _formatReviewTime(review.date), // UPDATED
                      style: TextStyle(
                        color: AppColors.darkText.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              StarRating(rating: review.rating.toDouble(), size: 16), // UPDATED
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              review.comment,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppColors.darkText.withOpacity(0.8),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  reviewsProvider.toggleLike(review.orderId, mealTitle); // UPDATED
                  HapticFeedback.lightImpact();
                },
                child: Row(
                  children: [
                    Icon(
                      review.isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 16,
                      color: review.isLiked ? Colors.red : AppColors.darkText.withOpacity(0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      review.likes.toString(),
                      style: TextStyle(
                        color: AppColors.darkText.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ADDED: Format review time
  String _formatReviewTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes} minutes ago';
      }
      return '${diff.inHours} hours ago';
    }
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class StarRating extends StatelessWidget {
  final double rating;
  final double size;

  const StarRating({super.key, required this.rating, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: size,
        );
      }),
    );
  }
}