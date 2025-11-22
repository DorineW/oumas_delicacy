
  import 'package:flutter/material.dart';
  import 'dart:async';
  import 'dart:math';
  import 'package:flutter/services.dart';
  import 'package:provider/provider.dart';
  import '../providers/store_provider.dart';
  import '../providers/cart_provider.dart';
  import '../providers/favorites_provider.dart';
  import '../services/auth_service.dart';
  import '../models/store_item.dart';
  import '../models/cart_item.dart';
  import '../widgets/smart_product_image.dart';
  import '../widgets/carousel.dart';
  import '../constants/colors.dart';

  // Helper to get the most accessible product (lowest price, highest stock, or most favorites)
  StoreItem? _getMostAccessibleItem(List<StoreItem> items) {
    if (items.isEmpty) return null;
    // Prioritize: available, lowest price, highest stock
    final availableItems = items.where((item) => item.available).toList();
    if (availableItems.isEmpty) return items.reduce((a, b) => a.price < b.price ? a : b);
    // If stock info is available, pick highest stock
    final withStock = availableItems.where((item) => item.trackInventory && item.currentStock != null).toList();
    if (withStock.isNotEmpty) {
      return withStock.reduce((a, b) => (a.currentStock ?? 0) > (b.currentStock ?? 0) ? a : b);
    }
    // Otherwise, pick lowest price
    return availableItems.reduce((a, b) => a.price < b.price ? a : b);
  }

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String? _selectedLocationId;
  final PageController _pageController = PageController(viewportFraction: 0.9);
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final storeProvider = context.read<StoreProvider>();
      storeProvider.loadStoreItems();
      // Auto-select first location if available
      if (storeProvider.locations.isNotEmpty && _selectedLocationId == null) {
        setState(() {
          _selectedLocationId = storeProvider.locations.first.id;
        });
        storeProvider.setSelectedLocation(_selectedLocationId);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    _bannerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Store'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Location Selector
          _buildLocationSelector(),
          
          // Search Bar
          _buildSearchBar(),
          
          // Categories
          _buildCategoryFilter(),
          
          // Featured Products or Promotional Banner
          _buildFeaturedBanner(),
          
          // Products Grid
          Expanded(
            child: _buildProductGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSelector() {
    return Consumer<StoreProvider>(
      builder: (context, storeProvider, child) {
        if (storeProvider.locations.isEmpty) return const SizedBox.shrink();
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.05),
            border: Border(
              bottom: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Shopping at:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.darkText,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedLocationId,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  items: storeProvider.locations.map((location) {
                    return DropdownMenuItem(
                      value: location.id,
                      child: Text(
                        location.name,
                        style: const TextStyle(fontSize: 14),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedLocationId = value;
                    });
                    storeProvider.setSelectedLocation(value);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search products…',
            hintStyle: TextStyle(color: Colors.grey[400]),
            prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
          onChanged: (value) {
            setState(() {});
          },
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Consumer<StoreProvider>(
      builder: (context, storeProvider, child) {
        final categories = ['All', ...storeProvider.availableItems.map((e) => e.category).toSet().toList()]..sort();
        
        return Container(
          height: 50,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final isSelected = _selectedCategory == category;
              
              return Padding(
                padding: EdgeInsets.only(
                  right: index == categories.length - 1 ? 0 : 8,
                ),
                child: FilterChip(
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory = category;
                    });
                  },
                  backgroundColor: Colors.white,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[700],
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: isSelected 
                          ? AppColors.primary 
                          : Colors.grey[300]!,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  elevation: isSelected ? 2 : 0,
                  pressElevation: 4,
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildFeaturedBanner() {
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    final random = Random(DateTime.now().millisecondsSinceEpoch);
    final allItems = List<StoreItem>.from(storeProvider.availableItems);
    allItems.shuffle(random);
    final featuredItems = allItems.take(3).toList();
    final bannerColors = [
      AppColors.primary,
      const Color(0xFF43A047),
      const Color(0xFFFB8C00),
    ];
    // Pair each infoTextGenerator with a matching icon
    final List<Map<String, dynamic>> iconMessagePairs = [
      { 'icon': Icons.local_offer, 'generator': (StoreItem item) => item.price < 500 ? '🔥 Great deal for budget shoppers!' : '💰 Save your money, shop smart!' },
      { 'icon': Icons.star, 'generator': (StoreItem item) => item.price > 1000 ? '💎 Premium pick for you!' : '⭐ Popular choice this week!' },
      { 'icon': Icons.shopping_basket, 'generator': (StoreItem item) => item.trackInventory && (item.currentStock ?? 0) < 5 ? '⏳ Only a few left!' : '🛒 Add to your cart now!' },
      { 'icon': Icons.trending_up, 'generator': (StoreItem item) => '🎉 Special offer just for you!' },
      { 'icon': Icons.emoji_events, 'generator': (StoreItem item) => '🌟 Trending now in store!' },
      { 'icon': Icons.emoji_events, 'generator': (StoreItem item) => '🥇 Top rated by customers!' },
      { 'icon': Icons.trending_up, 'generator': (StoreItem item) => '🚀 Fast moving item!' },
      { 'icon': Icons.local_offer, 'generator': (StoreItem item) => '🍀 Lucky find!' },
      { 'icon': Icons.local_offer, 'generator': (StoreItem item) => '🤑 Unbeatable price!' },
      { 'icon': Icons.lightbulb, 'generator': (StoreItem item) => '💡 Smart buy!' },
      { 'icon': Icons.check_circle, 'generator': (StoreItem item) {
        final storeProvider = Provider.of<StoreProvider>(context, listen: false);
        final accessible = _getMostAccessibleItem(storeProvider.availableItems);
        if (accessible != null && accessible.id == item.id) {
          return '✅ Most accessible: easy to buy!';
        }
        return '👍 Easy to get!';
      }},
    ];
    if (featuredItems.isEmpty) return const SizedBox.shrink();

    // Shuffle the pairs and assign one per featured item
    final shuffledPairs = List<Map<String, dynamic>>.from(iconMessagePairs)..shuffle(random);

    return Carousel(
      height: 165,
      interval: const Duration(seconds: 4),
      viewport: 0.9,
      children: List.generate(featuredItems.length, (index) {
        final item = featuredItems[index];
        final color = bannerColors[index % bannerColors.length];
        final pair = shuffledPairs[index % shuffledPairs.length];
        final icon = pair['icon'] as IconData;
        final infoText = (pair['generator'] as String Function(StoreItem))(item);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                bottom: -20,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                right: 20,
                top: 20,
                child: Icon(
                  icon,
                  size: 80,
                  color: Colors.white.withOpacity(0.18),
                ),
              ),
              Positioned(
                left: -10,
                bottom: -10,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withOpacity(0.8),
                      width: 3,
                    ),
                  ),
                  child: ClipOval(
                    child: SmartProductImage(
                      imageUrl: item.imageUrl ?? '',
                      height: 110,
                      width: 110,
                      removeBackground: false,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(110, 20, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'KSh ${item.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.yellow,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      infoText,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      elevation: 2,
                      child: InkWell(
                        onTap: () => _showProductDetails(context, item),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            'View Details',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildProductGrid() {
    return Consumer<StoreProvider>(
      builder: (context, storeProvider, child) {
        if (storeProvider.isLoading && storeProvider.availableItems.isEmpty) {
          return _buildLoadingGrid();
        }

        if (storeProvider.error != null) {
          return _buildErrorState(storeProvider);
        }

        final filteredItems = _filterProducts(storeProvider.availableItems);

        if (filteredItems.isEmpty) {
          return _buildEmptyState();
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.75,
          ),
          itemCount: filteredItems.length,
          itemBuilder: (context, index) {
            return _buildProductCard(filteredItems[index], storeProvider);
          },
        );
      },
    );
  }

  Widget _buildProductCard(StoreItem item, StoreProvider storeProvider) {
    // Only show as out of stock if item tracks inventory AND stock is 0
    final isOutOfStock = item.trackInventory && 
        (item.currentStock == null || item.currentStock == 0);
    
    return GestureDetector(
      onTap: () {
        _showProductDetails(context, item);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    color: Colors.grey[100],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    child: SmartProductImage(
                      imageUrl: item.imageUrl ?? '',
                      height: 120,
                      width: double.infinity,
                      removeBackground: true,
                    ),
                  ),
                ),
                
                // Product Info
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.category,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (item.unitDescription != null && item.unitDescription!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.unitDescription!,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        'KSh ${item.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // Stock Status Badge
            if (isOutOfStock)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Out of Stock',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            
            // Add to Cart Button - positioned at bottom right of image like menu items
            if (!isOutOfStock)
              Positioned(
                top: 100, // Position at bottom of 120px image
                right: 8,
                child: Material(
                  color: AppColors.primary,
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _addToCart(item, storeProvider),
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 18,
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

  Widget _buildLoadingGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 16,
                      width: 100,
                      color: Colors.grey[200],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 60,
                      color: Colors.grey[200],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 14,
                      width: 80,
                      color: Colors.grey[200],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorState(StoreProvider storeProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            storeProvider.error ?? 'Unknown error',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: storeProvider.loadStoreItems,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No products found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filter',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Future<void> _addToCart(StoreItem item, StoreProvider storeProvider) async {
    // Items without inventory tracking are always available
    // Items with tracking need stock > 0
    final isAvailable = item.available && 
        (!item.trackInventory || (item.currentStock != null && item.currentStock! > 0));
    
    debugPrint('🛒 Add to cart check for ${item.name}:');
    debugPrint('   available: ${item.available}');
    debugPrint('   trackInventory: ${item.trackInventory}');
    debugPrint('   currentStock: ${item.currentStock}');
    debugPrint('   isAvailable: $isAvailable');

    if (!isAvailable) {
      debugPrint('❌ Item not available, showing error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${item.name} is currently out of stock'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    debugPrint('✅ Item is available, proceeding to add to cart');
    
    try {
      HapticFeedback.lightImpact();
      debugPrint('🔍 Getting CartProvider...');

      final cart = context.read<CartProvider>();
      debugPrint('🔍 CartProvider obtained, creating CartItem...');
      
      final cartItem = CartItem(
        id: '${item.name}_${DateTime.now().millisecondsSinceEpoch}',
        menuItemId: item.productId,
        mealTitle: item.name,
        price: item.price.toInt(),
        quantity: 1,
        mealImage: item.imageUrl ?? '',
      );
      
      debugPrint('🔍 Adding item to cart: ${cartItem.mealTitle}');
      cart.addItem(cartItem);
      debugPrint('✅ Item successfully added to cart!');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('1 × ${item.name} added to cart'),
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ ERROR adding to cart: $e');
      debugPrint('Stack trace: $stackTrace');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding ${item.name} to cart'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<StoreItem> _filterProducts(List<StoreItem> items) {
    var filtered = items;

    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((item) =>
          item.name.toLowerCase().contains(query) ||
          item.description.toLowerCase().contains(query) ||
          item.category.toLowerCase().contains(query)).toList();
    }

    // Apply category filter
    if (_selectedCategory != 'All') {
      filtered = filtered.where((item) => item.category == _selectedCategory).toList();
    }

    return filtered;
  }

  void _showProductDetails(BuildContext context, StoreItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ProductDetailSheet(item: item);
      },
    );
  }
}

// Product Detail Bottom Sheet
class ProductDetailSheet extends StatefulWidget {
  final StoreItem item;

  const ProductDetailSheet({super.key, required this.item});

  @override
  State<ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends State<ProductDetailSheet> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    // Only consider out of stock if item tracks inventory AND stock is 0
    final isOutOfStock = widget.item.trackInventory && 
        (widget.item.currentStock == null || widget.item.currentStock == 0);
    
    final favoritesProvider = context.watch<FavoritesProvider>();
    final auth = context.watch<AuthService>();
    final userId = auth.currentUser?.id ?? 'guest';
    final isFavorite = favoritesProvider.isFavorite(userId, widget.item.id, type: FavoriteItemType.storeItem);
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Image
                  Container(
                    height: 250,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: SmartProductImage(
                            imageUrl: widget.item.imageUrl ?? '',
                            height: 200,
                            width: 200,
                            removeBackground: true,
                          ),
                        ),
                        Positioned(
                          top: 16,
                          right: 16,
                          child: IconButton(
                            icon: Icon(
                              isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: isFavorite ? Colors.red : Colors.grey[600],
                              size: 28,
                            ),
                            onPressed: () async {
                              if (userId != 'guest') {
                                HapticFeedback.lightImpact();
                                await favoritesProvider.toggleFavorite(
                                  userId, 
                                  widget.item.id, 
                                  type: FavoriteItemType.storeItem,
                                );
                                
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isFavorite 
                                            ? 'Removed from favorites' 
                                            : 'Added to favorites',
                                      ),
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Product Info
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.category,
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.item.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.item.description,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Price and Stock
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'KSh ${widget.item.price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            if (!isOutOfStock && widget.item.currentStock != null)
                              Text(
                                '${widget.item.currentStock} in stock',
                                style: TextStyle(
                                  color: Colors.green[600],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Quantity Selector
                        if (!isOutOfStock) ...[
                          Text(
                            'Quantity',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove),
                                  onPressed: _quantity > 1 ? () {
                                    setState(() {
                                      _quantity--;
                                    });
                                  } : null,
                                ),
                                SizedBox(
                                  width: 40,
                                  child: Text(
                                    _quantity.toString(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: () {
                                    setState(() {
                                      _quantity++;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 80), // Space for the button
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Add to Cart Button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                if (!isOutOfStock) ...[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Add to cart
                        final cart = context.read<CartProvider>();
                        cart.addItem(CartItem(
                          id: '${widget.item.name}_${DateTime.now().millisecondsSinceEpoch}',
                          menuItemId: widget.item.productId,
                          mealTitle: widget.item.name,
                          price: widget.item.price.toInt(),
                          quantity: _quantity,
                          mealImage: widget.item.imageUrl ?? '',
                        ));
                        
                        Navigator.pop(context);
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$_quantity × ${widget.item.name} added to cart'),
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Add to Cart',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        disabledBackgroundColor: Colors.grey[300],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Out of Stock',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}