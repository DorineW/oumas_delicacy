// ignore_for_file: unused_import, deprecated_member_use

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../widgets/carousel.dart';

import '../constants/colors.dart';
import '../models/cart_item.dart';
import '../models/menu_item.dart'; 
import '../providers/cart_provider.dart';
import '../providers/menu_provider.dart';
import '../providers/favorites_provider.dart'; 
import 'dashboard_screen.dart';
import 'cart_screen.dart';
import 'meal_detail_screen.dart';
import 'profile_screen.dart';
import '../services/auth_service.dart';
import '../screens/login_screen.dart';
import '../utils/responsive_helper.dart';
import '../widgets/popular_item_sections.dart';

/* ----------------------------------------------------------
   1.  ENTRY POINT
----------------------------------------------------------- */
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  final GlobalKey _cartIconKey = GlobalKey();
  
  final List<Widget> _screens = [
    const _HomeTab(),
    const DashboardScreen(),
    const CartScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final cartQty = context.watch<CartProvider>().totalQuantity;
    
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvoked: (didPop) {
        if (!didPop && _currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.darkText.withOpacity(0.6),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Container(
                key: _cartIconKey,
                child: cartQty > 0
                    ? Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.shopping_cart_rounded),
                          Positioned(
                            right: -8,
                            top: -8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              child: Center(
                                child: Text(
                                  cartQty > 99 ? '99+' : '$cartQty',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : const Icon(Icons.shopping_cart_rounded),
              ),
              label: 'Cart',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

/* ----------------------------------------------------------
   UPDATED HOME TAB WITH LANDING PAGE STYLING
----------------------------------------------------------- */
class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  String _search = '';
  int _tabIndex = 0;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _menuKey = GlobalKey();
  final GlobalKey _popularKey = GlobalKey();

  TabController? _tabController;
  final Map<int, ScrollController> _scrollControllers = {};

  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final menuProvider = context.read<MenuProvider>();
      
      menuProvider.loadMenuItems().then((_) {
        if (mounted) {
          final cats = menuProvider.menuItems
                       .map((e) => e.category)
                       .toSet()
                       .toList();
          
          _tabController = TabController(length: cats.length + 1, vsync: this);
          
          if (mounted) {
            setState(() {});
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    _tabController?.dispose();
    for (final c in _scrollControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _scrollToMenu() {
    Scrollable.ensureVisible(
      _menuKey.currentContext!,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _scrollToPopular() {
    Scrollable.ensureVisible(
      _popularKey.currentContext!,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  ScrollController _controller(int index) =>
      _scrollControllers.putIfAbsent(index, () => ScrollController());

  @override
  Widget build(BuildContext context) {
    final menuProvider = context.watch<MenuProvider>();
    final meals = menuProvider.menuItems;
    final popularItems = menuProvider.popularItems.map((item) => PopularItem(
      itemName: item.title,
      productId: item.productId ?? '',
      orderCount: 0,
      avgUnitPrice: item.price.toDouble(),
      avgRating: 0.0,
      menuItem: item,
    )).toList();
    final isLoading = menuProvider.isLoading;
    
    // Show loading state
    if (isLoading && meals.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text(
                'Loading delicious meals...',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.darkText,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Show error state
    if (menuProvider.error != null && meals.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 80,
                  color: AppColors.darkText.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Failed to Load Menu',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  menuProvider.error ?? 'Unknown error',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.darkText.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => menuProvider.loadMenuItems(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // Show empty state
    if (meals.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.restaurant_menu,
                size: 80,
                color: AppColors.darkText.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Menu Items Yet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Menu items will appear here once added',
                style: TextStyle(
                  color: AppColors.darkText.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    final cats = ['All', ...meals.map((e) => e.category).toSet()];
    final filtered = meals.where((m) {
      final t = m.title.toLowerCase();
      final s = _search.toLowerCase();
      final c = _tabIndex == 0 ? true : m.category == cats[_tabIndex];
      return t.contains(s) && c;
    }).toList();
    
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Hero Section
              _buildHeroSection(),
              
              // 2. Features/Stats Section
              _buildFeaturesSection(),
              
              // 3. Operating Hours Banner
              _buildHoursBanner(),
              
              // 4. Quick Action Buttons
              _buildQuickActions(),
              
              // 5. Category Quick Navigation
              _buildCategoryNavigation(),
              
              // Search bar (moved down)
              Padding(
                padding: EdgeInsets.fromLTRB(16, isLandscape ? 8 : 12, 16, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _search = v),
                    decoration: const InputDecoration(
                      hintText: 'Search meals…',
                      prefixIcon: Icon(Icons.search, color: AppColors.lightGray),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    ),
                  ),
                ),
              ),
              
              // 6. Promotional Carousel
              _buildPromotionalCarousel(meals),
              
              // 7. Popular Items Section (with key for scrolling)
              Container(
                key: _popularKey,
                child: PopularItemsSection(
                  popularItems: popularItems,
                  isLoading: isLoading,
                ),
              ),
              
              // 8. Full Menu Section (with key for scrolling)
              Container(
                key: _menuKey,
                child: _buildFullMenuSection(cats, filtered, isLandscape),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========== LANDING PAGE SECTIONS ==========

  // 1. Hero Section
  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
        ),
      ),
      child: Column(
        children: [
          // Logo and branding
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.restaurant, color: Colors.white, size: 32),
              const SizedBox(width: 8),
              Text(
                "Ouma's Delicacy",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Tagline
          Text(
            "Authentic Homemade Meals\nDelivered to Your Doorstep",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          // CTA Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _scrollToMenu,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text('Order Now'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _scrollToPopular,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text('View Specials'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. Features/Stats Section
  Widget _buildFeaturesSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      color: AppColors.background,
      child: Column(
        children: [
          const Text(
            'Why Choose Ouma\'s?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildFeatureItem(Icons.local_shipping, 'Fast Delivery', '30-45 min'),
              _buildFeatureItem(Icons.verified_user, 'Quality Guaranteed', '100% Fresh'),
              _buildFeatureItem(Icons.star, 'Customer Rated', '4.8/5 Stars'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String subtitle) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primary, size: 24),
        ),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  // 3. Operating Hours Banner
  Widget _buildHoursBanner() {
    final now = DateTime.now();
    final isOpen = now.hour >= 7 && now.hour < 21;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOpen ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOpen ? Colors.green.shade100 : Colors.orange.shade100,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isOpen ? Icons.check_circle : Icons.schedule,
            color: isOpen ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOpen ? 'We\'re Open!' : 'Currently Closed',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isOpen ? Colors.green : Colors.orange,
                  ),
                ),
                const Text(
                  'Daily: 7:00 AM - 9:00 PM',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 4. Quick Action Buttons
  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildQuickAction(Icons.timer, 'Express', Colors.blue),
          _buildQuickAction(Icons.local_offer, 'Deals', Colors.orange),
          _buildQuickAction(Icons.favorite, 'Favorites', Colors.red),
          _buildQuickAction(Icons.history, 'Recent', Colors.green),
        ],
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  // 5. Category Quick Navigation
  Widget _buildCategoryNavigation() {
    final categories = ['Breakfast', 'Lunch', 'Dinner', 'Desserts', 'Drinks'];
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Quick Categories',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: categories.map((category) {
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: Chip(
                    label: Text(category),
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    labelStyle: const TextStyle(color: AppColors.primary),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // 6. Enhanced Promotional Carousel
  Widget _buildPromotionalCarousel(List<MenuItem> meals) {
    final now = DateTime.now().hour;
    final closed = now < 7 || now >= 21;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Today\'s Specials',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
            ),
          ),
        ),
        Builder(builder: (context) {
          if (closed) {
            return _closedCard();
          } else {
            final carouselMeals = _getTimeBasedMeals(meals, now);
            if (carouselMeals.isEmpty) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info, color: Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No meals available at this time. Check back soon!',
                        style: TextStyle(
                          color: AppColors.darkText.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            return Column(children: [
              Carousel(
                height: 150,
                interval: const Duration(seconds: 4),
                children: carouselMeals.take(4).map((m) => _carouselCard(context, m, now)).toList(),
              ),
              const SizedBox(height: 12),
            ]);
          }
        }),
      ],
    );
  }

  // 8. Full Menu Section
  Widget _buildFullMenuSection(List<String> cats, List<MenuItem> filtered, bool isLandscape) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Full Menu',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
            ),
          ),
        ),
        
        // Category tabs
        if (_tabController != null)
          Container(
            color: AppColors.white,
            child: TabBar(
              controller: _tabController!,
              isScrollable: true,
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.darkText,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
              tabs: cats.map((c) => Tab(text: c)).toList(),
              onTap: (i) => setState(() => _tabIndex = i),
            ),
          ),
        
        // Grid section
        SizedBox(
          height: 600,
          child: _tabController == null
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController!,
                  children: cats.asMap().entries.map((e) {
                    final list = e.key == 0 ? filtered : filtered.where((m) => m.category == cats[e.key]).toList();
                    if (list.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.fastfood,
                              size: 80,
                              color: AppColors.darkText.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No Meals Found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkText.withOpacity(0.5),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _search.isEmpty 
                                  ? 'No meals in this category'
                                  : 'Try adjusting your search',
                              style: TextStyle(
                                color: AppColors.darkText.withOpacity(0.4),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return LayoutBuilder(
                      builder: (context, gridConstraints) {
                        return SingleChildScrollView(
                          controller: _controller(e.key),
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(16, isLandscape ? 8 : 16, 16, 16),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: gridConstraints.maxHeight,
                            ),
                            child: GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: ResponsiveHelper.getGridCrossAxisCount(context),
                                childAspectRatio: ResponsiveHelper.getGridChildAspectRatio(context),
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: list.length,
                              itemBuilder: (_, i) => _RiderStyleMealCard(meal: list[i]),
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  // ========== HELPER METHODS ==========

  List<MenuItem> _getTimeBasedMeals(List<MenuItem> meals, int hour) {
    String preferredWeight;
    
    if (hour >= 7 && hour < 10) {
      preferredWeight = 'Light';
    } else if (hour >= 10 && hour < 12) {
      preferredWeight = 'Medium';
    } else if (hour >= 12 && hour < 16) {
      preferredWeight = 'Heavy';
    } else {
      preferredWeight = 'Heavy';
    }
    
    final menuProvider = context.read<MenuProvider>();
    
    final preferredMeals = meals.where((m) => 
      (m.mealWeight.name == preferredWeight) && menuProvider.isItemAvailable(m.title)
    ).toList();
    
    if (preferredMeals.length >= 4) {
      preferredMeals.shuffle();
      return preferredMeals.take(4).toList();
    }
    
    final otherMeals = meals.where((m) => 
      (m.mealWeight.name != preferredWeight) && menuProvider.isItemAvailable(m.title)
    ).toList();
    
    final combined = [...preferredMeals, ...otherMeals];
    combined.shuffle();
    return combined.take(4).toList();
  }

  String _getMealPeriodName(int hour) {
    if (hour >= 7 && hour < 10) {
      return 'Breakfast';
    } else if (hour >= 10 && hour < 12) {
      return 'Brunch';
    } else if (hour >= 12 && hour < 16) {
      return 'Lunch';
    } else {
      return 'Dinner';
    }
  }

  Widget _carouselCard(BuildContext context, MenuItem m, int hour) {
    final mealPeriod = _getMealPeriodName(hour);
    
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MealDetailScreen(meal: m)),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            _floatingDots(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  _circularPlate(context, m),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _getMealPeriodIcon(hour),
                              color: AppColors.white.withOpacity(0.9),
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$mealPeriod Special!',
                              style: TextStyle(
                                color: AppColors.white.withOpacity(0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          m.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ksh ${m.price}',
                          style: TextStyle(
                            color: AppColors.white.withOpacity(0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white54),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getMealPeriodIcon(int hour) {
    if (hour >= 7 && hour < 10) {
      return Icons.free_breakfast;
    } else if (hour >= 10 && hour < 12) {
      return Icons.brunch_dining;
    } else if (hour >= 12 && hour < 16) {
      return Icons.lunch_dining;
    } else {
      return Icons.dinner_dining;
    }
  }

  Widget _circularPlate(BuildContext context, MenuItem m) {
    final imageValue = m.imageUrl;
    
    return Material(
      elevation: 6,
      color: AppColors.white,
      shape: const CircleBorder(),
      child: Container(
        width: 80,
        height: 80,
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: ClipOval(
          child: _buildImage(imageValue, 40),
        ),
      ),
    );
  }

  Widget _buildImage(String? imageValue, double iconSize) {
    if (imageValue == null) {
      return Icon(Icons.fastfood, size: iconSize, color: AppColors.primary);
    }
    
    if (imageValue.startsWith('assets/')) {
      return Image.asset(
        imageValue,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(Icons.fastfood, size: iconSize, color: AppColors.primary),
      );
    }
    
    return Image.network(
      imageValue,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Icon(Icons.fastfood, size: iconSize, color: AppColors.primary),
    );
  }

  Widget _floatingDots() {
    return const Positioned.fill(
      child: Stack(
        children: [
          Positioned(top: 20, left: 30, child: AnimatedDot(index: 0)),
          Positioned(top: 60, right: 40, child: AnimatedDot(index: 1)),
          Positioned(bottom: 40, left: 50, child: AnimatedDot(index: 2)),
          Positioned(bottom: 70, right: 60, child: AnimatedDot(index: 3)),
        ],
      ),
    );
  }

  Widget _closedCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.orange.shade700,
            Colors.orange.shade500,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
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
            child: const Icon(
              Icons.schedule,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Currently Closed',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Open daily: 7:00 AM - 9:00 PM',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
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

// ========== FLY TO CART ANIMATION ==========

OverlayEntry? _currentOverlay;

void _flyToCart(BuildContext context, GlobalKey cartKey, Widget flyingWidget, VoidCallback onEnd) {
  final overlay = Overlay.of(context);
  final renderBox = context.findRenderObject() as RenderBox?;
  final cartRenderBox = cartKey.currentContext?.findRenderObject() as RenderBox?;
  
  if (renderBox == null || cartRenderBox == null) {
    debugPrint('Fly-to-cart: Could not find renderBoxes');
    onEnd();
    return;
  }

  final start = renderBox.localToGlobal(Offset.zero);
  final cartSize = cartRenderBox.size;
  final end = cartRenderBox.localToGlobal(Offset(cartSize.width / 2, cartSize.height / 2));

  debugPrint('Fly-to-cart: Starting animation from $start to $end');

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _FlyingWidget(
      start: start,
      end: end,
      child: flyingWidget,
      onEnd: () {
        entry.remove();
        _currentOverlay = null;
        onEnd();
      },
    ),
  );

  _currentOverlay?.remove();
  _currentOverlay = entry;
  overlay.insert(entry);
}

class _FlyingWidget extends StatefulWidget {
  final Offset start;
  final Offset end;
  final Widget child;
  final VoidCallback onEnd;

  const _FlyingWidget({
    required this.start,
    required this.end,
    required this.child,
    required this.onEnd,
  });

  @override
  State<_FlyingWidget> createState() => _FlyingWidgetState();
}

class _FlyingWidgetState extends State<_FlyingWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _position;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _position = Tween<Offset>(begin: widget.start, end: widget.end)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.fastOutSlowIn));
    _scale = Tween<double>(begin: 1, end: .2).animate(_ctrl);
    _fade = Tween<double>(begin: 1, end: 0).animate(_ctrl);

    _ctrl.forward().whenComplete(() => widget.onEnd());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Positioned(
        left: _position.value.dx,
        top: _position.value.dy,
        child: Transform.scale(
          scale: _scale.value,
          child: Opacity(
            opacity: _fade.value,
            child: Material(
              elevation: 0,
              color: Colors.transparent,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

// ========== MEAL CARD ==========

class _RiderStyleMealCard extends StatefulWidget {
  final MenuItem meal;
  const _RiderStyleMealCard({required this.meal});

  @override
  State<_RiderStyleMealCard> createState() => _RiderStyleMealCardState();
}

class _RiderStyleMealCardState extends State<_RiderStyleMealCard>
    with SingleTickerProviderStateMixin {
  int _qty = 0;
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 400), vsync: this);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _addToCart() async {
    if (_qty <= 0) return;

    final menuProvider = context.read<MenuProvider>();
    final isAvailable = menuProvider.isItemAvailable(widget.meal.title);

    if (!isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${widget.meal.title} is currently out of stock'),
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

    HapticFeedback.lightImpact();

    final homeScreenState = context.findAncestorStateOfType<_HomeScreenState>();
    if (homeScreenState == null) {
      debugPrint('Could not find HomeScreen state');
      return;
    }

    final addedQuantity = _qty;

    final cart = context.read<CartProvider>();
    cart.addItem(CartItem(
      id: '${widget.meal.title}_${DateTime.now().millisecondsSinceEpoch}',
      menuItemId: widget.meal.id ?? '',
      mealTitle: widget.meal.title,
      price: widget.meal.price,
      quantity: addedQuantity,
      mealImage: widget.meal.imageUrl ?? '',
    ));

    final imageUrl = widget.meal.imageUrl;
    Widget flyWidget;
    
    if (imageUrl != null && imageUrl.startsWith('assets/')) {
      flyWidget = ClipOval(
        child: Image.asset(
          imageUrl,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.fastfood, size: 40, color: AppColors.primary),
        ),
      );
    } else if (imageUrl != null) {
      flyWidget = ClipOval(
        child: Image.network(
          imageUrl,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.fastfood, size: 40, color: AppColors.primary),
        ),
      );
    } else {
      flyWidget = const Icon(Icons.fastfood, size: 40, color: AppColors.primary);
    }
    
    setState(() => _qty = 0);
    
    _flyToCart(context, homeScreenState._cartIconKey, flyWidget, () {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$addedQuantity × ${widget.meal.title} added to cart'),
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }

  Widget _buildImageWidget(String? imageUrl) {
    Widget errorWidget = const Icon(Icons.fastfood, size: 60, color: AppColors.primary);
    
    if (imageUrl == null) {
      return errorWidget;
    }
    
    if (imageUrl.startsWith('assets/')) {
      return Image.asset(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => errorWidget,
      );
    }
    
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => errorWidget,
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.meal;
    final isLandscape = ResponsiveHelper.isLandscape(context);
    final menuProvider = context.watch<MenuProvider>();
    final isAvailable = menuProvider.isItemAvailable(m.title);
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MealDetailScreen(meal: m),
          ),
        );
      },
      child: Card(
        elevation: 3,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: isAvailable ? null : Colors.grey.shade300,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: isLandscape ? 100 : 120,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                color: AppColors.lightGray.withOpacity(0.3),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: ColorFiltered(
                      colorFilter: isAvailable 
                          ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                          : ColorFilter.mode(Colors.grey.withOpacity(0.5), BlendMode.saturation),
                      child: SizedBox.expand(
                        child: _buildImageWidget(m.imageUrl),
                      ),
                    ),
                  ),
                  if (!isAvailable)
                    Container(
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                        color: Colors.black54,
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.block, color: Colors.white, size: 32),
                            SizedBox(height: 4),
                            Text(
                              'OUT OF STOCK',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(isLandscape ? 6 : 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    m.title,
                    style: TextStyle(
                      fontSize: isLandscape ? 12 : 14,
                      fontWeight: FontWeight.bold,
                      color: isAvailable ? AppColors.darkText : Colors.grey,
                      decoration: isAvailable ? null : TextDecoration.lineThrough,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ksh ${m.price}',
                    style: TextStyle(
                      fontSize: isLandscape ? 12 : 14,
                      fontWeight: FontWeight.bold,
                      color: isAvailable ? AppColors.primary : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Opacity(
                          opacity: isAvailable ? 1.0 : 0.5,
                          child: Container(
                            height: isLandscape ? 26 : 28,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _qtyButton(
                                    Icons.remove, 
                                    isAvailable 
                                        ? () => setState(() => _qty = math.max(0, _qty - 1))
                                        : () {},
                                  ),
                                ),
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      '$_qty',
                                      style: TextStyle(
                                        fontSize: isLandscape ? 10 : 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: _qtyButton(
                                    Icons.add, 
                                    isAvailable 
                                        ? () => setState(() => _qty++)
                                        : () {},
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 5,
                        child: SizedBox(
                          height: isLandscape ? 26 : 28,
                          child: ElevatedButton(
                            onPressed: (isAvailable && _qty > 0) ? _addToCart : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: (isAvailable && _qty > 0) 
                                  ? AppColors.primary 
                                  : AppColors.lightGray,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: Icon(
                              Icons.shopping_cart,
                              color: Colors.white,
                              size: isLandscape ? 13 : 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    final isLandscape = ResponsiveHelper.isLandscape(context);
    return IconButton(
      padding: EdgeInsets.zero,
      iconSize: isLandscape ? 13 : 14,
      onPressed: onTap,
      icon: Icon(icon, color: AppColors.primary),
    );
  }
}

// ========== ANIMATED DOT ==========

class AnimatedDot extends StatefulWidget {
  final int index;
  const AnimatedDot({super.key, required this.index});

  @override
  State<AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<AnimatedDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _offsetAnim;
  late final Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    final period = Duration(milliseconds: 1200 + (widget.index * 100));
    _controller = AnimationController(vsync: this, duration: period);
    _offsetAnim = Tween<double>(begin: 0, end: -8).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _opacityAnim = Tween<double>(begin: 0.6, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _offsetAnim.value),
          child: Opacity(
            opacity: _opacityAnim.value,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}