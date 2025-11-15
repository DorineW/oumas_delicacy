import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../providers/order_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/menu_provider.dart';
import '../models/order.dart';
import '../services/auth_service.dart';
import '../providers/reviews_provider.dart';
import 'order_history_screen.dart';
import 'meal_detail_screen.dart';
import '../utils/responsive_helper.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with AutomaticKeepAliveClientMixin {
  bool _showFavoritesSection = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = context.watch<OrderProvider>();
    final favoritesProvider = context.watch<FavoritesProvider>();
    final menuProvider = context.watch<MenuProvider>();
    final auth = context.watch<AuthService>();
    final userId = auth.currentUser?.id ?? 'guest';
    
    final fullName = auth.currentUser?.name ?? 'Guest';
    final firstName = fullName.split(' ').first;
    
    final orders = provider.orders;

    final int orderCount = orders.length;
    final int favCount = favoritesProvider.getCountForUser(userId);
    final int reviewCount = orders.fold<int>(
      0,
      (sum, order) => sum + order.items.where((item) => item.rating != null).length,
    );

    final completedOrders = orders.where((o) => o.status == OrderStatus.delivered).length;
    final isLandscape = ResponsiveHelper.isLandscape(context);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Dashboard"),
        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.white),
        titleTextStyle: const TextStyle(
          color: AppColors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, isLandscape ? 12 : 16, 16, 100),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 100,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Error/Offline Banner for Orders
                    if (provider.error != null)
                      _buildErrorBanner(provider.error!),
                      
                    // Welcome Card
                    _buildWelcomeCard(firstName, isLandscape),
                    SizedBox(height: isLandscape ? 16 : 24),

                    // Stats Cards
                    _buildStatsSection(
                      isLandscape, 
                      orderCount, 
                      favCount, 
                      completedOrders, 
                      reviewCount, 
                      userId
                    ),
                    SizedBox(height: isLandscape ? 16 : 24),

                    // Quick Stats Summary
                    _buildQuickStatsSummary(orderCount, completedOrders, reviewCount),

                    // Favorites dropdown section
                    _buildFavoritesSection(userId, favoritesProvider, menuProvider),

                    // Recent Orders Section
                    _buildRecentOrdersSection(orders, userId),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // EXTRACTED: Error Banner Widget
  Widget _buildErrorBanner(String error) {
    final isCachedError = error.contains('cached') || error.contains('Limited');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCachedError ? Colors.orange.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCachedError ? Colors.orange.shade300 : Colors.red.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isCachedError ? Icons.wifi_off : Icons.error_outline,
            color: isCachedError ? Colors.orange.shade700 : Colors.red.shade700,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: TextStyle(
                color: isCachedError ? Colors.orange.shade900 : Colors.red.shade900,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // EXTRACTED: Welcome Card
  Widget _buildWelcomeCard(String firstName, bool isLandscape) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isLandscape ? 16 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.waving_hand,
              color: AppColors.white,
              size: isLandscape ? 28 : 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              "Welcome back, $firstName!",
              style: TextStyle(
                fontSize: isLandscape ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // EXTRACTED: Stats Section
  Widget _buildStatsSection(
    bool isLandscape, 
    int orderCount, 
    int favCount, 
    int completedOrders, 
    int reviewCount, 
    String userId
  ) {
    if (isLandscape) {
      return IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Orders',
                count: orderCount.toString(),
                icon: Icons.shopping_bag,
                color: AppColors.primary,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderHistoryScreen(customerId: userId),
                    ),
                  );
                },
                semanticLabel: '$orderCount orders, double tap to view order history',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                title: 'Favorites',
                count: favCount.toString(),
                icon: Icons.favorite,
                color: Colors.red,
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _showFavoritesSection = !_showFavoritesSection;
                  });
                },
                semanticLabel: '$favCount favorite meals, double tap to toggle favorites view',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                title: 'Completed',
                count: completedOrders.toString(),
                icon: Icons.check_circle,
                color: AppColors.success,
                onTap: () => HapticFeedback.lightImpact(),
                semanticLabel: '$completedOrders completed orders',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                title: 'Reviews',
                count: reviewCount.toString(),
                icon: Icons.star,
                color: Colors.amber,
                onTap: () => HapticFeedback.lightImpact(),
                semanticLabel: '$reviewCount reviews submitted',
              ),
            ),
          ],
        ),
      );
    } else {
      return Column(
        children: [
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Orders',
                    count: orderCount.toString(),
                    icon: Icons.shopping_bag,
                    color: AppColors.primary,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrderHistoryScreen(customerId: userId),
                        ),
                      );
                    },
                    semanticLabel: '$orderCount orders, double tap to view order history',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    title: 'Favorites',
                    count: favCount.toString(),
                    icon: Icons.favorite,
                    color: Colors.red,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _showFavoritesSection = !_showFavoritesSection;
                      });
                    },
                    semanticLabel: '$favCount favorite meals, double tap to toggle favorites view',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Completed',
                    count: completedOrders.toString(),
                    icon: Icons.check_circle,
                    color: AppColors.success,
                    onTap: () => HapticFeedback.lightImpact(),
                    semanticLabel: '$completedOrders completed orders',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    title: 'Reviews',
                    count: reviewCount.toString(),
                    icon: Icons.star,
                    color: Colors.amber,
                    onTap: () => HapticFeedback.lightImpact(),
                    semanticLabel: '$reviewCount reviews submitted',
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
  }

  // ADDED: Quick Stats Summary
  Widget _buildQuickStatsSummary(int orderCount, int completedOrders, int reviewCount) {
    if (orderCount == 0 && completedOrders == 0 && reviewCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildQuickStatItem('Total Orders', orderCount),
          _buildQuickStatItem('Completed', completedOrders),
          _buildQuickStatItem('Rated Items', reviewCount),
        ],
      ),
    );
  }

  // ADDED: Quick Stat Item
  Widget _buildQuickStatItem(String label, int value) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.darkText.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  // Favorites dropdown section
  Widget _buildFavoritesSection(String userId, FavoritesProvider favoritesProvider, MenuProvider menuProvider) {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 300),
      crossFadeState: _showFavoritesSection 
          ? CrossFadeState.showFirst 
          : CrossFadeState.showSecond,
      firstChild: _buildFavoritesContent(userId, favoritesProvider, menuProvider),
      secondChild: const SizedBox.shrink(),
    );
  }

  // EXTRACTED: Favorites Content
  Widget _buildFavoritesContent(String userId, FavoritesProvider favoritesProvider, MenuProvider menuProvider) {
    try {
      final favoriteIds = favoritesProvider.getFavoritesForUser(userId);
      final favoriteMeals = menuProvider.menuItems.where((meal) => 
        favoriteIds.contains(meal.id) && menuProvider.isItemAvailable(meal.title)
      ).toList();

      if (favoriteMeals.isEmpty) {
        return _buildEmptyFavoritesState();
      }

      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.favorite, color: Colors.red, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'My Favorites',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.red,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${favoriteMeals.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Favorite meals list
            ...favoriteMeals.map((meal) => Container(
              key: ValueKey('favorite-${meal.id}'),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MealDetailScreen(meal: meal),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        // Meal image
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppColors.lightGray,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _buildMealImage(meal.imageUrl),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Meal details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                meal.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    'Ksh ${meal.price}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.star, size: 12, color: Colors.amber),
                                  const SizedBox(width: 2),
                                  Text(
                                    meal.rating.toString(),
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Actions
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                favoritesProvider.isFavorite(userId, meal.id ?? '')
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: Colors.red,
                                size: 20,
                              ),
                              onPressed: () {
                                favoritesProvider.toggleFavorite(userId, meal.id ?? '');
                                HapticFeedback.lightImpact();
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: AppColors.darkText.withOpacity(0.5),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )),
          ],
        ),
      );
    } catch (error) {
      return _buildErrorState('Failed to load favorites');
    }
  }

  // ADDED: Empty Favorites State
  Widget _buildEmptyFavoritesState() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite_border, color: Colors.red, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No Favorites Yet',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap the heart icon on meals you love to add them here!',
                  style: TextStyle(
                    color: AppColors.darkText.withOpacity(0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // EXTRACTED: Recent Orders Section
  Widget _buildRecentOrdersSection(List<Order> orders, String userId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Orders',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
              ),
            ),
            if (orders.isNotEmpty)
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderHistoryScreen(customerId: userId),
                    ),
                  );
                },
                child: const Text('View All'),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Recent Orders List - grouped by date (show ALL orders)
        orders.isEmpty
            ? const _EmptyState()
            : _buildGroupedOrders(orders),
      ],
    );
  }

  // Build grouped orders by date
  Widget _buildGroupedOrders(List<Order> orders) {
    // Sort orders by date (newest first)
    final sortedOrders = List<Order>.from(orders)
      ..sort((a, b) => b.date.compareTo(a.date));
    
    // Group orders by date
    final Map<String, List<Order>> groupedOrders = {};
    for (final order in sortedOrders.take(10)) {
      final dateKey = _getDateKey(order.date);
      groupedOrders.putIfAbsent(dateKey, () => []).add(order);
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groupedOrders.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 8, bottom: 8),
              child: Text(
                entry.key,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText.withOpacity(0.7),
                ),
              ),
            ),
            // Orders for this date
            ...entry.value.map((order) => _RecentOrderCard(
              key: ValueKey('order-${order.id}'),
              order: order,
            )),
          ],
        );
      }).toList(),
    );
  }

  // Get date key for grouping
  String _getDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final orderDate = DateTime(date.year, date.month, date.day);
    
    if (orderDate == today) {
      return 'Today';
    } else if (orderDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    }
  }

  // FIXED: Helper method to build meal images with proper type
  Widget _buildMealImage(String? imageUrl) {
    Widget errorWidget = const Icon(Icons.fastfood, size: 24, color: AppColors.primary);
    
    if (imageUrl == null || imageUrl.isEmpty) {
      return errorWidget;
    }
    
    if (imageUrl.startsWith('assets/')) {
      return Image.asset(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => errorWidget,
      );
    }
    
    // Assume network image
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => errorWidget,
    );
  }

  // ADDED: Generic Error State
  Widget _buildErrorState(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

// UPDATED: Stat Card Widget
class _StatCard extends StatelessWidget {
  final String title;
  final String count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String semanticLabel;

  const _StatCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.onTap,
    this.semanticLabel = '',
  });

  @override
  Widget build(BuildContext context) {
    final isFavorites = title == 'Favorites';
    
    return Semantics(
      label: semanticLabel.isNotEmpty ? semanticLabel : '$count $title',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          count,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isFavorites) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.visibility,
                          size: 14,
                          color: color,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.darkText.withOpacity(0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// UPDATED: Recent Order Card with const constructor
class _RecentOrderCard extends StatelessWidget {
  final Order order;

  const _RecentOrderCard({super.key, required this.order});

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.preparing:
        return Colors.purple;
      case OrderStatus.outForDelivery:
        return Colors.indigo;
      case OrderStatus.delivered:
        return AppColors.success;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.confirmed:
        return 'CONFIRMED';
      case OrderStatus.preparing:
        return 'PREPARING';
      case OrderStatus.outForDelivery:
        return 'OUT FOR DELIVERY';
      case OrderStatus.delivered:
        return 'DELIVERED';
      case OrderStatus.cancelled:
        return 'CANCELLED';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if all items have been rated
    final allItemsRated = order.items.every((item) => item.rating != null && item.rating! > 0);
    
    return Semantics(
      label: 'Order from ${_formatTime(order.date)}',
      value: '${order.items.length} items, total KES ${order.totalAmount}',
      button: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: AppColors.darkText.withOpacity(0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(order.date),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkText.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getStatusColor(order.status)),
                  ),
                  child: Text(
                    _getStatusText(order.status),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(order.status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              order.items.map((item) => '${item.quantity}x ${item.title}').join(', '),
              style: TextStyle(
                fontSize: 13,
                color: AppColors.darkText.withOpacity(0.8),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'KES ${order.totalAmount}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Receipt button
                    IconButton(
                      onPressed: () => _showPaymentReceipt(context, order),
                      icon: const Icon(Icons.receipt_long),
                      iconSize: 20,
                      color: AppColors.primary,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'View Receipt',
                    ),
                  ],
                ),
                // Hide rate button if already rated
                if (order.status == OrderStatus.delivered && !allItemsRated)
                  TextButton.icon(
                    onPressed: () => _showRatingDialog(context, order),
                    icon: const Icon(Icons.star, size: 16),
                    label: const Text('Rate', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.amber,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  )
                else if (allItemsRated)
                  // Show rated indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Rated',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Format time
  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _showRatingDialog(BuildContext context, Order order) {
    showDialog(
      context: context,
      builder: (context) => _RatingDialog(order: order),
    );
  }

  void _showPaymentReceipt(BuildContext context, Order order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('Payment Receipt'),
          ],
        ),
        content: SingleChildScrollView(
          child: Container(
            width: double.maxFinite,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.success.withOpacity(0.3), width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Payment Successful',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Ouma\'s Delicacy',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.darkText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 32, color: AppColors.success),
                _buildReceiptRow('Order Number', order.orderNumber),
                const SizedBox(height: 12),
                _buildReceiptRow('Date', '${order.date.day}/${order.date.month}/${order.date.year}'),
                const SizedBox(height: 12),
                _buildReceiptRow('Time', '${order.date.hour.toString().padLeft(2, '0')}:${order.date.minute.toString().padLeft(2, '0')}'),
                const SizedBox(height: 12),
                _buildReceiptRow('Payment Method', 'M-Pesa'),
                const Divider(height: 32, color: AppColors.success),
                const Text(
                  'Order Items',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 8),
                ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${item.title} x${item.quantity}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Text(
                        'KSh ${(item.price * item.quantity).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )),
                const Divider(height: 24, color: AppColors.success),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Amount',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                      ),
                    ),
                    Text(
                      'KSh ${order.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order.status),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Icon(_getStatusIcon(order.status), color: Colors.white, size: 28),
                      const SizedBox(height: 8),
                      Text(
                        'Status: ${_getStatusText(order.status)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.confirmed:
        return Icons.check_circle;
      case OrderStatus.preparing:
        return Icons.restaurant;
      case OrderStatus.outForDelivery:
        return Icons.delivery_dining;
      case OrderStatus.delivered:
        return Icons.done_all;
      case OrderStatus.cancelled:
        return Icons.cancel;
    }
  }

  Widget _buildReceiptRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

// UPDATED: Rating Dialog Widget with anonymous option
class _RatingDialog extends StatefulWidget {
  final Order order;

  const _RatingDialog({required this.order});

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  final Map<String, int> _ratings = {};
  final Map<String, TextEditingController> _commentControllers = {};
  bool _submitAsAnonymous = false;

  @override
  void initState() {
    super.initState();
    // Initialize ratings and controllers for each item
    for (var item in widget.order.items) {
      _ratings[item.id] = item.rating ?? 0;
      _commentControllers[item.id] = TextEditingController(text: item.review ?? '');
    }
  }

  @override
  void dispose() {
    for (var controller in _commentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.star, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Rate Your Order',
                style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
      titlePadding: EdgeInsets.zero,
      contentPadding: const EdgeInsets.all(20),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.receipt, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Your Order',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Rate each item separately
              ...widget.order.items.map((item) => _buildItemRating(item)),
              
              // Anonymous submission option
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _submitAsAnonymous ? Icons.visibility_off : Icons.visibility,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Submit Anonymously',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            _submitAsAnonymous 
                                ? 'Your name will be hidden'
                                : 'Your name will be visible',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.darkText.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _submitAsAnonymous,
                      onChanged: (value) {
                        setState(() {
                          _submitAsAnonymous = value;
                        });
                      },
                      activeColor: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: AppColors.darkText.withOpacity(0.6)),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: () => _submitRatings(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _submitAsAnonymous ? Icons.visibility_off : Icons.check_circle,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  _submitAsAnonymous ? 'Submit Anonymously' : 'Submit Ratings',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemRating(OrderItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.restaurant, size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Star rating
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Wrap(
              spacing: 6,
              children: List.generate(5, (index) {
                final isSelected = index < (_ratings[item.id] ?? 0);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _ratings[item.id] = index + 1;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? Colors.amber.withOpacity(0.2) 
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      isSelected ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 28,
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),
          // Comment field
          TextField(
            controller: _commentControllers[item.id],
            decoration: InputDecoration(
              hintText: 'Share your thoughts... (optional)',
              hintStyle: TextStyle(fontSize: 12, color: AppColors.darkText.withOpacity(0.4)),
              prefixIcon: Icon(Icons.comment, size: 18, color: AppColors.primary.withOpacity(0.6)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.lightGray.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.lightGray.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
              filled: true,
              fillColor: AppColors.background,
            ),
            maxLines: 3,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _submitRatings(BuildContext context) async {
    try {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      final reviewsProvider = Provider.of<ReviewsProvider>(context, listen: false);
      final auth = Provider.of<AuthService>(context, listen: false);
      
      // Update each item's rating and review
      for (var item in widget.order.items) {
        final rating = _ratings[item.id] ?? 0;
        final review = _commentControllers[item.id]?.text.trim() ?? '';
        
        if (rating > 0) {
          orderProvider.rateOrderItem(widget.order.id, item.id, rating, review);
          
          // Add to reviews provider for meal detail screen
          final userId = auth.currentUser?.id ?? '';
          final reviewObj = Review(
            id: UniqueKey().toString(),
            userAuthId: userId,
            productId: item.id,
            rating: rating,
            body: review.isNotEmpty ? review : null,
            createdAt: DateTime.now(),
            userName: auth.currentUser?.name,
            isAnonymous: _submitAsAnonymous,
          );
          reviewsProvider.addReview(reviewObj);
        }
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Thank you for your feedback!',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _submitAsAnonymous 
                            ? 'Your review was submitted anonymously'
                            : 'Your review helps others make better choices',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (error) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Failed to submit rating: $error')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// UPDATED: Empty State Widget with key parameter
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 80,
            color: AppColors.darkText.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Orders Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start ordering to see your history here',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.darkText.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          // Quick action button
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to menu screen - adjust based on your app structure
              // Example: context.read<AppState>().selectedIndex = 1;
            },
            icon: const Icon(Icons.restaurant_menu, size: 18),
            label: const Text('Browse Menu'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}