// lib/screens/home_screen.dart
// ignore_for_file: unused_import, deprecated_member_use

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/colors.dart';
import '../models/cart_item.dart';
import '../providers/cart_provider.dart';
import '../providers/menu_provider.dart';

// Add your navigation screens imports
import 'dashboard_screen.dart';
import 'cart_screen.dart';
import 'meal_detail_screen.dart';
import 'profile_screen.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    HomeContentScreen(),
    const DashboardScreen(),
    const CartScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final cartCount = Provider.of<CartProvider>(context).items
        .fold<int>(0, (sum, it) => sum + it.quantity);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.lightGray,
          backgroundColor: AppColors.white,
          elevation: 0,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.shopping_cart),
                  // badge
                  if (cartCount > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.white, width: 1.5),
                        ),
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        child: Center(
                          child: Text(
                            '$cartCount',
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              label: 'Cart',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// Extract the home content to a separate widget
// ignore: use_key_in_widget_constructors
class HomeContentScreen extends StatefulWidget {
  @override
  State<HomeContentScreen> createState() => _HomeContentScreenState();
}

class _HomeContentScreenState extends State<HomeContentScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  final Map<int, ScrollController> _scrollControllers = {};
  bool _showScrollToTop = false;
  TabController? _tabController;

  // ensure we dispose/create the tab controller when categories change
  void _ensureTabController(List<String> categories) {
    // if controller already matches required length, keep it
    if (_tabController != null && _tabController!.length == categories.length) return;

    // dispose previous controller if any
    _tabController?.removeListener(_handleTabChange);
    _tabController?.dispose();

    // create new controller and attach a single listener
    _tabController = TabController(length: categories.length, vsync: this);
    _tabController!.addListener(_handleTabChange);

    // sync selected category index with controller
    final idx = categories.indexOf(_selectedCategory);
    if (idx >= 0 && idx < _tabController!.length) {
      _tabController!.index = idx;
    } else {
      _selectedCategory = categories.isNotEmpty ? categories[0] : 'All';
    }
  }

  void _handleTabChange() {
    if (!mounted || _tabController == null) return;
    if (_tabController!.indexIsChanging) {
      setState(() {
        // categories must be read from build scope; we update selectedCategory by index
        // we'll clamp index defensively in build after categories are computed
        _selectedCategory = _tabController!.index.toString(); // placeholder, replaced in build below
      });
    }
  }

  @override
  void dispose() {
    for (final sc in _scrollControllers.values) sc.dispose();
    _tabController?.removeListener(_handleTabChange);
    _tabController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    final currentIndex = _tabController?.index ?? 0;
    final sc = _ensureControllerForIndex(currentIndex);
    if (!sc.hasClients) return;
    sc.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _scrollToBottom() {
    final currentIndex = _tabController?.index ?? 0;
    final sc = _ensureControllerForIndex(currentIndex);
    if (!sc.hasClients) return;
    sc.animateTo(
      sc.position.maxScrollExtent,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  // ensure a ScrollController exists for the given tab index and attach a listener
  // that updates the floating action button state (_showScrollToTop)
  ScrollController _ensureControllerForIndex(int index) {
    // return existing controller if present
    if (_scrollControllers.containsKey(index)) return _scrollControllers[index]!;

    // create, register and attach listener
    final sc = ScrollController();
    sc.addListener(() {
      if (!mounted) return;
      final shouldShow = sc.hasClients && sc.offset > 200;
      if (shouldShow != _showScrollToTop) {
        setState(() => _showScrollToTop = shouldShow);
      }
    });

    _scrollControllers[index] = sc;
    return sc;
  }

  // Dummy menu items based on the provided menu
  final List<Map<String, dynamic>> dummyMenuItems = [
    {
      'title': 'Ugali Nyama Choma',
      'price': 210,
      'category': 'Ugali Dishes',
      'description': 'Traditional Kenyan maize meal with grilled meat',
      'rating': 4.8,
      'image': 'assets/images/ugali_nyama.jpg',
    },
    {
      'title': 'Pilau Liver',
      'price': 230,
      'category': 'Rice Dishes',
      'description': 'Spiced rice with tender liver pieces',
      'rating': 4.5,
      'image': 'assets/images/pilau.jpg',
    },
    {
      'title': 'Ugali Samaki',
      'price': 300,
      'category': 'Ugali Dishes',
      'description': 'Maize meal served with fried fish',
      'rating': 4.7,
      'image': 'assets/images/ugali_fish.jpg',
    },
    {
      'title': 'Githeri',
      'price': 120,
      'category': 'Traditional',
      'description': 'Boiled maize and beans mixture',
      'rating': 4.3,
      'image': 'assets/images/Githeri.jpg',
    },
    {
      'title': 'Chapati',
      'price': 20,
      'category': 'Breakfast',
      'description': 'Soft, flaky flatbread',
      'rating': 4.6,
      'image': 'assets/images/Chapati.jpg',
    },
    {
      'title': 'Matoke Beef',
      'price': 230,
      'category': 'Traditional',
      'description': 'Steamed bananas with beef stew',
      'rating': 4.4,
      'image': 'assets/images/matoke.jpg',
    },
    {
      'title': 'Chips Beef',
      'price': 210,
      'category': 'Fast Food',
      'description': 'Crispy fries with beef stew',
      'rating': 4.2,
      'image': 'assets/images/chips_beef.jpg',
    },
    {
      'title': 'Beef Burger',
      'price': 130,
      'category': 'Fast Food',
      'description': 'Juicy beef patty in a bun with veggies',
      'rating': 4.1,
      'image': 'assets/images/burger.jpg',
    },
    {
      'title': 'Tea',
      'price': 30,
      'category': 'Beverages',
      'description': 'Hot Kenyan tea with milk',
      'rating': 4.5,
      'image': 'assets/images/tea.jpg',
    },
    {
      'title': 'Samosa',
      'price': 20,
      'category': 'Snacks',
      'description': 'Crispy pastry filled with spiced meat',
      'rating': 4.7,
      'image': 'assets/images/samosa.jpg',
    },
    {
      'title': 'Pilau Beef Fry',
      'price': 180,
      'category': 'Rice Dishes',
      'description': 'Spiced rice with fried beef',
      'rating': 4.6,
      'image': 'assets/images/pilau_beef.jpg',
    },
    {
      'title': 'Kuku Ugali',
      'price': 220,
      'category': 'Ugali Dishes',
      'description': 'Maize meal with chicken stew',
      'rating': 4.5,
      'image': 'assets/images/kuku_ugali.jpg',
    },
  ];

  // Filter meals based on search and category
  List<Map<String, dynamic>> filteredMeals(List<Map<String, dynamic>> meals) {
    return meals.where((meal) {
      final title = (meal['title'] ?? '').toString().toLowerCase();
      final matchesSearch = title.contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'All' ||
          (meal['category'] ?? '') == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final menuProvider = Provider.of<MenuProvider>(context);
    final List<Map<String, dynamic>> meals =
        menuProvider.menuItems.isNotEmpty
            ? List<Map<String, dynamic>>.from(menuProvider.menuItems)
            : dummyMenuItems;

    final Set<String> cats = {};
    for (var meal in meals) {
      final cat = meal['category']?.toString();
      if (cat != null && cat.isNotEmpty) cats.add(cat);
    }
    final List<String> categories = ['All'] + cats.toList()..sort();

    // create/update controller safely and provide a proper listener closure that captures categories
    _ensureTabController(categories);
    // replace the placeholder listener behavior: update selected category by index
    _tabController?.removeListener(_handleTabChange);
    _tabController?.addListener(() {
      if (_tabController!.indexIsChanging) {
        final idx = _tabController!.index.clamp(0, categories.length - 1);
        setState(() => _selectedCategory = categories[idx]);
      }
    });

    final width = MediaQuery.of(context).size.width;
    final int crossAxisCount = width > 1000 ? 4 : (width > 700 ? 3 : 2);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            // small logo image; falls back to an Icon if asset missing
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: AppColors.primary.withOpacity(0.1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/app_icon.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.restaurant,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              "Ouma's Delicacy",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.white,
        elevation: 2,
        iconTheme: IconThemeData(color: AppColors.darkText),
        actionsIconTheme: IconThemeData(color: AppColors.darkText),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              Provider.of<AuthService>(context, listen: false).logout();
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Container(
            color: AppColors.cardBackground,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DrawerHeader(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // App icon without background
                      Image.asset(
                        'assets/images/app_icon.png', 
                        width: 56,
                        height: 56,
                      ),
                      const SizedBox(height: 12),
                      Text('Ouma\'s Delicacy',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkText)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.home),
                        title: const Text('Home'),
                        onTap: () {
                          Navigator.pop(context);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.dashboard),
                        title: const Text('Dashboard'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const DashboardScreen()),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.shopping_cart),
                        title: const Text('Cart'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const CartScreen()),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.person),
                        title: const Text('Profile'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const ProfileScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar - now separate from app bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Container(
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
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search meals...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.lightGray),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    hintStyle: TextStyle(color: AppColors.lightGray),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  // promo carousel - now larger
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: PromoCarousel(
                      promoItems: [
                        {
                          'image': 'assets/images/promo1.jpg',
                          'title': 'Ramadan Offers',
                          'subtitle': 'Get 25% off',
                          'cta': 'Grab Offer'
                        },
                        {
                          'image': 'assets/images/promo2.jpg',
                          'title': 'Free Delivery',
                          'subtitle': 'On orders over Ksh 500',
                          'cta': 'Order Now'
                        },
                        {
                          'image': 'assets/images/promo3.jpg',
                          'title': 'New: Ugali Specials',
                          'subtitle': 'From Ksh 150',
                          'cta': 'See Menu'
                        },
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      indicatorColor: AppColors.primary,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.darkText,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicatorWeight: 3,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.normal,
                        fontSize: 14,
                      ),
                      tabs: categories.map((cat) => Tab(text: cat)).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: categories.asMap().entries.map((entry) {
                        final tabIndex = entry.key;
                        final cat = entry.value;
                        final mealsByCategory = cat == 'All'
                            ? filteredMeals(meals)
                            : filteredMeals(meals)
                                .where((m) => m['category'] == cat)
                                .toList();
                        if (mealsByCategory.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 64,
                                  color: AppColors.lightGray,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "No meals found",
                                  style: TextStyle(
                                    color: AppColors.lightGray,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return GridView.builder(
                          controller: _ensureControllerForIndex(tabIndex),
                          padding: const EdgeInsets.all(16),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            childAspectRatio: 0.75,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: mealsByCategory.length,
                          itemBuilder: (context, index) =>
                              MealCard(meal: mealsByCategory[index]),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: _showScrollToTop ? _scrollToTop : _scrollToBottom,
        child: Icon(
          _showScrollToTop ? Icons.arrow_upward : Icons.arrow_downward,
          color: AppColors.white,
        ),
      ),
    );
  }
}

class MealCard extends StatefulWidget {
  final Map<String, dynamic> meal;

  const MealCard({super.key, required this.meal});

  @override
  State<MealCard> createState() => _MealCardState();
}

class _MealCardState extends State<MealCard> {
  int _quantity = 0;

  void _increment() => setState(() => _quantity++);
  void _decrement() {
    if (_quantity > 0) setState(() => _quantity--);
  }

  void _addToCart() {
    if (_quantity <= 0) return;
    final dynamic cartProvider = Provider.of<CartProvider>(context, listen: false);
    final price = (widget.meal['price'] is num) ? (widget.meal['price'] as num).toDouble() : 0.0;
    cartProvider.addItem(CartItem(
      id: '${widget.meal['title']}_${DateTime.now().millisecondsSinceEpoch}',
      mealTitle: widget.meal['title']?.toString() ?? 'Item',
      price: price.toInt(),
      quantity: _quantity,
      mealImage: widget.meal['image']?.toString() ?? '',
    ));

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$_quantity ${widget.meal['title']} added to cart'),
      duration: const Duration(seconds: 2),
    ));
    setState(() => _quantity = 0);
  }

  @override
  Widget build(BuildContext context) {
    final meal = widget.meal;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => MealDetailScreen(meal: meal)),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // compute a responsive image height based on available card height
            final double cardMaxH = constraints.maxHeight.isFinite ? constraints.maxHeight : 220.0;
            final double imageHeight = (cardMaxH * 0.45).clamp(80.0, 140.0);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image section (height constrained)
                SizedBox(
                  height: imageHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      color: AppColors.cardBackground,
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: Image.asset(
                        meal['image'] ?? '',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: AppColors.lightGray.withOpacity(0.3),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.fastfood,
                              color: AppColors.lightGray,
                              size: 40,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // Remaining content uses the leftover space
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meal['title']?.toString() ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Ksh ${meal['price']?.toString() ?? '0'}",
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        // Compact quantity controls + cart button
                        Row(
                          children: [
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  backgroundColor: _quantity > 0 ? AppColors.primary : AppColors.lightGray,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                onPressed: _decrement,
                                child: const Icon(Icons.remove, size: 16, color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('$_quantity', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkText)),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  backgroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                onPressed: _increment,
                                child: const Icon(Icons.add, size: 16, color: Colors.white),
                              ),
                            ),
                            const Spacer(),
                            SizedBox(
                              width: 44,
                              height: 36,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _quantity > 0 ? AppColors.accent : AppColors.lightGray,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: _quantity > 0 ? _addToCart : null,
                                child: const Icon(Icons.shopping_cart, size: 18, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class PromoCarousel extends StatelessWidget {
  final List<Map<String, dynamic>> promoItems;

  const PromoCarousel({super.key, required this.promoItems});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140, // slightly reduced to give more room to tabs on small screens
      margin: const EdgeInsets.symmetric(horizontal: 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: PageView.builder(
          itemCount: promoItems.length,
          itemBuilder: (context, index) {
            final item = promoItems[index];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withOpacity(0.95),
                    AppColors.accent.withOpacity(0.85),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Background pattern (safe: won't throw if asset missing)
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.06,
                      child: Image.asset(
                        'assets/images/pattern.png',
                        repeat: ImageRepeat.repeat,
                        fit: BoxFit.none,
                        errorBuilder: (ctx, err, st) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  // Content — compact column with tuned spacing
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title'] ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item['subtitle'] ?? '',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          Material(
                            color: Colors.transparent,
                            child: ElevatedButton(
                              onPressed: () {
                                // Handle CTA button press
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.primary,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                minimumSize: const Size(0, 34),
                              ),
                              child: Text(
                                (item['cta'] ?? '').toString(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}