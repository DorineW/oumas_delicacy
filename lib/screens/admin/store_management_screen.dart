// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// Corrected paths - going up two directories from lib/screens/admin/
import '../../providers/store_provider.dart'; 
import '../../models/store_item.dart';
import '../../models/location.dart'; 

import '../../providers/cart_provider.dart';
import '../../models/cart_item.dart';


// --- Re-using the SmartProductImage widget definition ---
class SmartProductImage extends StatelessWidget {
  final String imageUrl;
  final bool removeBackground;
  final double height;
  final double width;
  final BoxDecoration? containerDecoration;

  const SmartProductImage({
    Key? key,
    required this.imageUrl,
    this.removeBackground = true,
    this.height = 120,
    this.width = 120,
    this.containerDecoration,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: containerDecoration ?? BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          if (removeBackground) ...[
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.8,
                    colors: [
                      Colors.white.withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        
          Center(
            child: ColorFiltered(
              colorFilter: const ColorFilter.matrix([
                1, 0, 0, 0, 0,
                0, 1, 0, 0, 0,
                0, 0, 1, 0, 0,
                0, 0, 0, 0.95, 0,
              ]),
              child: imageUrl.isEmpty
                  ? Container(
                      height: height,
                      width: width,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.shopping_bag_outlined,
                        size: 40,
                        color: Colors.grey[400],
                      ),
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      height: height,
                      width: width,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: height,
                          width: width,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.shopping_bag_outlined,
                            size: 40,
                            color: Colors.grey[400],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Main Store Browsing Screen ---

class StoreScreen extends StatefulWidget {
  const StoreScreen({Key? key}) : super(key: key);

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    // Load store items when the screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StoreProvider>().loadStoreItems();
    });
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🛒 Shop Our Store'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Products',
            onPressed: () => context.read<StoreProvider>().loadStoreItems(),
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            tooltip: 'View Cart',
            onPressed: () {
              // TODO: Navigate to Cart Screen
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Navigating to Cart (Not implemented)')),
                );
              }
            },
          ),
        ],
      ),
      body: Consumer<StoreProvider>(
        builder: (context, storeProvider, child) {
          if (storeProvider.isLoading && storeProvider.storeItems.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (storeProvider.error != null) {
            return _buildErrorState(storeProvider);
          }
          
          // Filter items for the customer view: must be available and have stock > 0
          final customerItems = storeProvider.storeItems
              .where((item) => item.available && (item.currentStock ?? 0) > 0)
              .toList();

          final filteredItems = _filterItems(customerItems);

          return Column(
            children: [
              _buildSearchBar(customerItems),
              Expanded(
                child: filteredItems.isEmpty
                    ? _buildEmptyState(customerItems.isEmpty)
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75, 
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          return _buildItemGridCard(filteredItems[index]);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- Widget Builders ---

  Widget _buildSearchBar(List<StoreItem> allAvailableItems) {
    // Get unique categories only from items available to customers
    final categories = ['All', ...allAvailableItems.map((e) => e.category).where((cat) => cat.isNotEmpty).toSet().toList()];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search for products...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) => setState(() {}),
          ),
          const SizedBox(height: 12),
          // Category Filters
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = _selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = selected ? category : 'All';
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemGridCard(StoreItem item) {
    return GestureDetector(
      onTap: () => _showProductDetailDialog(context, item),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image
              Expanded(
                child: Center(
                  child: SmartProductImage(
                    imageUrl: item.imageUrl ?? '',
                    height: double.infinity,
                    width: double.infinity,
                    containerDecoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Name
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              // Category/Unit
              Text(
                item.unitOfMeasure,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              // Price & Add Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'KSh ${item.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      final cartProvider = context.read<CartProvider>();
                      cartProvider.addItem(CartItem(
                        id: UniqueKey().toString(),
                        menuItemId: item.id,
                        mealTitle: item.name,
                        price: item.price.round(),
                        quantity: 1,
                        mealImage: item.imageUrl ?? '',
                      ));
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Added ${item.name} to cart!')),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.add, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Filtering Logic (Client-side) ---

  List<StoreItem> _filterItems(List<StoreItem> items) {
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

  // --- Utility Widgets and Dialogs ---

  Widget _buildErrorState(StoreProvider storeProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 60, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text('Failed to load products: ${storeProvider.error}', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: storeProvider.loadStoreItems,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isStoreEmpty) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            isStoreEmpty ? 'The store is currently empty.' : 'No products match your filters.',
            style: const TextStyle(fontSize: 18, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  void _showProductDetailDialog(BuildContext context, StoreItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SmartProductImage(
                imageUrl: item.imageUrl ?? '',
                height: 200,
                width: double.infinity,
              ),
              const SizedBox(height: 16),
              Text(
                'KSh ${item.price.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.description,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Divider(),
              Text('Category: ${item.category}'),
              Text('Sold by: ${item.unitOfMeasure}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final cartProvider = context.read<CartProvider>();
              cartProvider.addItem(CartItem(
                id: UniqueKey().toString(),
                menuItemId: item.id,
                mealTitle: item.name,
                price: item.price.round(),
                quantity: 1,
                mealImage: item.imageUrl ?? '',
              ));
              Navigator.of(context).pop();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Added ${item.name} to cart!')),
                );
              }
            },
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Add to Cart'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.removeListener(() {});
    _searchController.dispose();
    super.dispose();
  }
}