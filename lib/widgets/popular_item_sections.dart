import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../models/menu_item.dart'; // Assume this exists
// import '../providers/menu_provider.dart'; // Assume this handles fetching full menu details
import '../screens/meal_detail_screen.dart'; // Assume this exists

// NOTE: Since we cannot modify the model files, we define a simple wrapper model
// to hold the combined popular data.

// --- 1. MODEL FOR AGGREGATED POPULAR DATA ---
class PopularItem {
  final String itemName;
  final String productId;
  final int orderCount;
  final double avgUnitPrice;
  final double avgRating; // Calculated from the reviews table

  // Core MenuItem details (to be fetched/attached)
  MenuItem? menuItem; 

  PopularItem({
    required this.itemName,
    required this.productId,
    required this.orderCount,
    required this.avgUnitPrice,
    this.avgRating = 0.0,
    this.menuItem,
  });
}

// --- 2. POPULAR ITEMS SECTION WIDGET ---

class PopularItemsSection extends StatelessWidget {
  final List<PopularItem> popularItems;
  final bool isLoading;

  const PopularItemsSection({
    super.key,
    required this.popularItems,
    this.isLoading = false,
  });

  // Helper method to build the horizontal list of cards/skeletons
  Widget _buildHorizontalList(BuildContext context) {
    // Determine content based on loading state
    final isDataLoading = isLoading && popularItems.isEmpty;
    final listCount = isDataLoading ? 5 : popularItems.length; // Show 5 skeletons

    if (!isDataLoading && popularItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 250, // Fixed height for the horizontal carousel
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemCount: listCount,
        itemBuilder: (context, index) {
          final isLast = index == listCount - 1;
          final padding = isLast ? EdgeInsets.zero : const EdgeInsets.only(right: 16.0);
          
          return Padding(
            padding: padding,
            child: isDataLoading 
              ? const _PopularItemSkeletonCard() // SHOW SKELETON
              : _PopularItemCard(item: popularItems[index]), // SHOW REAL CARD
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDataLoading = isLoading && popularItems.isEmpty;

    if (!isDataLoading && popularItems.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            "🔥 Ouma's Top Sellers",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText.withOpacity(isDataLoading ? 0.3 : 1.0),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            "Tried and tested favorites from our community.",
            style: TextStyle(
              fontSize: 14,
              color: AppColors.darkText.withOpacity(isDataLoading ? 0.3 : 1.0),
            ),
          ),
        ),
        const SizedBox(height: 12),
        
        _buildHorizontalList(context),
        
        const SizedBox(height: 24),
      ],
    );
  }
}

// --- 3. INDIVIDUAL CARD WIDGET ---

class _PopularItemCard extends StatelessWidget {
  final PopularItem item;

  const _PopularItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.menuItem?.imageUrl;
    final price = item.avgUnitPrice.toStringAsFixed(2);
    final title = item.itemName;
    final rating = item.avgRating.toStringAsFixed(1);
    
    // NOTE: Fallback for unattached data is now handled by the caller showing the Skeletonizer.
    // If we reach this point, data should be ready.

    return GestureDetector(
      onTap: () {
        if (item.menuItem != null) {
           Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => MealDetailScreen(meal: item.menuItem!)),
          );
        }
      },
      child: Container(
        width: 180, // Defined card width
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.lightGray.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Container(
                height: 120,
                width: double.infinity,
                color: AppColors.background,
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => 
                          const Icon(Icons.fastfood, size: 50, color: AppColors.primary),
                      )
                    : const Icon(Icons.restaurant, size: 50, color: AppColors.primary),
              ),
            ),
            
            // Details Section
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  
                  // Rating and Price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Rating (Uses a default 4.5 if not available)
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            item.avgRating > 0 ? rating : '4.5',
                            style: const TextStyle(fontSize: 14, color: AppColors.darkText),
                          ),
                        ],
                      ),
                      
                      // Price
                      Text(
                        'Ksh $price',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Quick Add Button (Small)
                  SizedBox(
                    width: double.infinity,
                    height: 30,
                    child: OutlinedButton(
                      onPressed: () {
                        // TODO: Implement quick add to cart functionality (1 item)
                        ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(content: Text('Quick adding 1x $title')),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary, width: 1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: EdgeInsets.zero
                      ),
                      child: const Text('Add to Cart', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// --- 4. SKELETON CARD WIDGET (INTERNAL IMPLEMENTATION) ---

class _PopularItemSkeletonCard extends StatelessWidget {
  const _PopularItemSkeletonCard();

  @override
  Widget build(BuildContext context) {
    // Base container mimicking the final card size and shape
    return Container(
      width: 180, 
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.lightGray.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Skeleton (Mimics the 120px height)
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[300], // Light gray placeholder
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
          
          // Details Skeleton
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title Line 1
                Container(
                  width: double.infinity,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                // Title Line 2 (Shorter)
                Container(
                  width: 120,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 10),
                
                // Rating/Price Row Skeleton
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Rating Block
                    Container(
                      width: 50,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    // Price Block
                    Container(
                      width: 60,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Button Skeleton
                Container(
                  width: double.infinity,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.grey[200], // Lighter color for the button outline space
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!, width: 1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}