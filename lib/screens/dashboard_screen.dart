import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:like_button/like_button.dart';
import 'package:shimmer/shimmer.dart';
import '../constants/colors.dart';
import '../constants/app_decorations.dart';
import '../providers/order_provider.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ----------  single line that makes it reactive  ----------
    final provider = context.watch<OrderProvider>();

    // ----------  compute counts once, automatically  ----------
        final int orderCount  = provider.orders.length;
        final int favCount    = 0;   // placeholder until favoriteItems is implemented
        final int reviewCount = 0;   // OrderProvider has no `reviews` getter, using fallback
    
        return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Dashboard"),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Welcome back, Dorin!",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _DashboardCard(
                  title: 'Orders',
                  count: orderCount.toString(),        // <-- live
                  icon: Icons.shopping_bag,
                ),
                _DashboardCard(
                  title: 'Favorites',
                  count: favCount.toString(),          // <-- live
                  icon: Icons.favorite,
                ),
                _DashboardCard(
                  title: 'Reviews',
                  count: reviewCount.toString(),       // <-- live
                  icon: Icons.star,
                ),
              ],
            ),
            const SizedBox(height: 30),
            const Text(
              "Top Picks",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _CategoryChip(label: 'Chapati'),
                _CategoryChip(label: 'Githeri'),
                _CategoryChip(label: 'Ugali'),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: 6,
                  itemBuilder: (_, __) => Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppDecorations.radius12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final String count;
  final IconData icon;

  const _DashboardCard({
    required this.title,
    required this.count,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () => HapticFeedback.lightImpact(),
        child: Container(
          width: 88,
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: AppDecorations.radius12,
            boxShadow: [AppDecorations.softShadow],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (title == 'Favorites')
                LikeButton(
                  size: 40,
                  circleColor: const CircleColor(start: Color(0xff00ddff), end: Color(0xff0099cc)),
                  bubblesColor: const BubblesColor(dotPrimaryColor: Color(0xff33b5e5), dotSecondaryColor: Color(0xff00aacc), dotLastColor: Color(0xff0099cc)),
                  onTap: (isLiked) async {
                    HapticFeedback.lightImpact();
                    return !isLiked;
                  },
                )
              else
                Icon(
                  icon,
                  size: 40,
                  color: AppColors.primary,
                ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                count,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;

  const _CategoryChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => HapticFeedback.selectionClick(),
      child: Container(
        margin: const EdgeInsets.only(right: 8.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: AppDecorations.radius24,
          boxShadow: [AppDecorations.cardShadow],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ----------  glass-card helper  ----------
Widget glassCard({required Widget child}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.65),
          border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(24),
        ),
        child: child,
      ),
    ),
  );
}