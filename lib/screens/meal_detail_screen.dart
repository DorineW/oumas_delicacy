// lib/screens/meal_detail_screen.dart
// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../constants/colors.dart';
import '../models/cart_item.dart';
import '../providers/cart_provider.dart';

class MealDetailScreen extends StatefulWidget {
  final Map<String, dynamic> meal;

  const MealDetailScreen({super.key, required this.meal});

  @override
  State<MealDetailScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends State<MealDetailScreen> {
  int quantity = 1;
  bool showDetails = true;
  double averageRating = 4.5;

  // Dummy reviews
  final List<Map<String, String>> dummyReviews = [
    {
      "name": "Alice",
      "comment": "Really tasty and fresh! The beef was perfectly cooked.",
      "rating": "⭐⭐⭐⭐",
      "time": "2 days ago"
    },
    {
      "name": "Brian",
      "comment": "Good portion size, worth the price. Will order again!",
      "rating": "⭐⭐⭐⭐⭐",
      "time": "1 week ago"
    },
    {
      "name": "Cynthia",
      "comment": "Could use a bit more spice, but overall good flavor.",
      "rating": "⭐⭐⭐",
      "time": "3 days ago"
    },
    {
      "name": "David",
      "comment": "Amazing! Best burger I've had in a long time.",
      "rating": "⭐⭐⭐⭐⭐",
      "time": "5 days ago"
    },
  ];

  @override
  void initState() {
    super.initState();
    // Calculate average rating from reviews
    if (dummyReviews.isNotEmpty) {
      averageRating = dummyReviews.fold(0.0, (sum, review) {
        final stars = review['rating']!.replaceAll(RegExp(r'[^⭐]'), '');
        return sum + stars.length;
      }) / dummyReviews.length;
    }
  }

  Widget _buildMealImage(dynamic imageVal) {
    if (imageVal == null) {
      return Container(
        color: AppColors.lightGray,
        child: const Icon(Icons.fastfood, size: 80, color: AppColors.primary),
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
      return Image.asset(imgPath, fit: BoxFit.cover);
    }

    if (imgPath.startsWith('http')) {
      return Image.network(imgPath, fit: BoxFit.cover);
    }

    if (!kIsWeb) {
      try {
        return Image.file(File(imgPath), fit: BoxFit.cover);
      } catch (_) {}
    }

    return Container(
      color: AppColors.lightGray,
      child: const Icon(Icons.fastfood, size: 80, color: AppColors.primary),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meal = widget.meal;
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    final String title = (meal['title'] ?? 'Untitled').toString();
    final int price = (meal['price'] ?? 0) is int
        ? meal['price']
        : int.tryParse(meal['price'].toString()) ?? 0;
    final String category = (meal['category'] ?? '').toString();
    final double rating = (meal['rating'] ?? 4.5).toDouble();
    final String description =
        (meal['description'] ?? 'Delicious and freshly made.').toString();

    return Scaffold(
      backgroundColor: AppColors.cardBackground,
      body: CustomScrollView(
        slivers: [
          // App bar with image
          SliverAppBar(
            expandedHeight: 300.0,
            pinned: true,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Creative background pattern
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary,
                          AppColors.accent,
                        ],
                      ),
                    ),
                    child: Opacity(
                      opacity: 0.1,
                      child: Image.asset(
                        'assets/images/food_pattern.png', // You can add a food pattern asset
                        fit: BoxFit.cover,
                        color: AppColors.white,
                        colorBlendMode: BlendMode.modulate,
                      ),
                    ),
                  ),
                  
                  // Meal image with creative framing
                  Center(
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 15,
                            spreadRadius: 2,
                            offset: const Offset(0, 5),
                          ),
                        ],
                        border: Border.all(
                          color: AppColors.white,
                          width: 4,
                        ),
                      ),
                      child: ClipOval(
                        child: _buildMealImage(meal['image']),
                      ),
                    ),
                  ),
                  
                  // Gradient overlay
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
                  color: AppColors.primary.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.favorite_border, color: Colors.white),
                ),
                onPressed: () {},
              ),
            ],
          ),

          // Content
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and price with creative design
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.darkText,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  "Ksh $price",
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          // Category and rating
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  category,
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(Icons.star, color: Colors.amber, size: 18),
                              const SizedBox(width: 4),
                              Text(
                                rating.toStringAsFixed(1),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "(${dummyReviews.length} reviews)",
                                style: TextStyle(
                                  color: AppColors.darkText.withOpacity(0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Tabs with creative design
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => showDetails = true),
                              borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(16),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: showDetails
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  borderRadius: const BorderRadius.horizontal(
                                    left: Radius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  "Details",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: showDetails
                                        ? Colors.white
                                        : AppColors.darkText,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 24,
                            color: AppColors.lightGray,
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => showDetails = false),
                              borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(16),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: !showDetails
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  borderRadius: const BorderRadius.horizontal(
                                    right: Radius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  "Reviews (${dummyReviews.length})",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: !showDetails
                                        ? Colors.white
                                        : AppColors.darkText,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Content based on tab selection
                    if (showDetails) _buildDetailsSection(description),
                    if (!showDetails) _buildReviewsSection(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      // Fixed bottom bar with creative design
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Quantity control
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 20),
                      color: AppColors.primary,
                      onPressed: () {
                        if (quantity > 1) setState(() => quantity--);
                      },
                    ),
                    Text('$quantity',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(
                      icon: const Icon(Icons.add, size: 20),
                      color: AppColors.primary,
                      onPressed: () => setState(() => quantity++),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Add to cart button
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add_shopping_cart_outlined),
                  label: Text(
                    'Add • Ksh ${price * quantity}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact(); // 1. vibration

                    final cartItem = CartItem(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      mealTitle: title,
                      mealImage: meal['image'],
                      price: price,
                      quantity: quantity,
                    );

                    // Use dynamic invocation so compilation doesn't fail if the provider method name differs.
                    final dynamic cp = cartProvider;
                    var added = false;

                    try {
                      // Try common method names used in various implementations.
                      try {
                        cp.addToCart(cartItem);
                        added = true;
                      } catch (_) {
                        try {
                          cp.addItem(cartItem);
                          added = true;
                        } catch (_) {
                          try {
                            cp.add(cartItem);
                            added = true;
                          } catch (_) {
                            // If provider expects different signature, attempt other plausible variants (non-fatal).
                            try {
                              cp.addItem(cartItem.id, cartItem);
                              added = true;
                            } catch (_) {}
                          }
                        }
                      }
                    } catch (_) {
                      added = false;
                    }

                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(added ? "$title added to cart (x$quantity)" : "Could not add $title to cart"),
                      backgroundColor: added ? AppColors.accent : Colors.redAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsSection(String description) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            description,
            style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
          ),
          const SizedBox(height: 24),

          // Ingredients section
          const Text(
            "What's Included",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildIngredientChip("Beef Patty"),
              _buildIngredientChip("Fresh Buns"),
              _buildIngredientChip("Lettuce"),
              _buildIngredientChip("Tomato"),
              _buildIngredientChip("Onions"),
              _buildIngredientChip("Special Sauce"),
            ],
          ),
          const SizedBox(height: 24),

          // Nutrition info
          const Text(
            "Nutrition Information",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText),
          ),
          const SizedBox(height: 12),
          DataTable(
            columnSpacing: 20,
            columns: const [
              DataColumn(label: Text("Nutrient", style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text("Amount", style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: const [
              DataRow(cells: [
                DataCell(Text("Calories")),
                DataCell(Text("560 kcal")),
              ]),
              DataRow(cells: [
                DataCell(Text("Protein")),
                DataCell(Text("25 g")),
              ]),
              DataRow(cells: [
                DataCell(Text("Carbs")),
                DataCell(Text("45 g")),
              ]),
              DataRow(cells: [
                DataCell(Text("Fat")),
                DataCell(Text("30 g")),
              ]),
            ],
          ),
          const SizedBox(height: 24),

          // Additional notes
          const Text(
            "Notes",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText),
          ),
          const SizedBox(height: 8),
          Text(
            "If you have allergies or special requests, please add them when ordering.",
            style: TextStyle(color: AppColors.darkText.withOpacity(0.8), fontSize: 14),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildIngredientChip(String text) {
    return Chip(
      label: Text(text),
      backgroundColor: AppColors.primary.withOpacity(0.1),
      labelStyle: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildReviewsSection() {
    // Calculate average rating from reviews
    double avgRating = dummyReviews.isNotEmpty
        ? dummyReviews.fold(0.0, (sum, review) {
            final stars = review['rating']!.replaceAll(RegExp(r'[^⭐]'), '');
            return sum + stars.length;
          }) / dummyReviews.length
        : 4.5;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Average rating
          Row(
            children: [
              Text(
                avgRating.toStringAsFixed(1),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StarRating(rating: avgRating, size: 20),
                  const SizedBox(height: 4),
                  Text(
                    "${dummyReviews.length} reviews",
                    style: TextStyle(color: AppColors.darkText.withOpacity(0.6)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Reviews list
          ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: dummyReviews.length,
            separatorBuilder: (context, index) => const Divider(height: 32),
            itemBuilder: (context, index) {
              final review = dummyReviews[index];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.primary,
                          child: Text(
                            review['name']![0],
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                review['name']!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                review['time']!,
                                style: TextStyle(
                                  color: AppColors.darkText.withOpacity(0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(review['rating']!),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      review['comment']!,
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// Helper widget for star rating
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
          index < rating.floor() ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: size,
        );
      }),
    );
  }
}