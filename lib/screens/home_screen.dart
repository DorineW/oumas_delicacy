// ignore_for_file: unused_import, deprecated_member_use

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';

import '../constants/colors.dart';
import '../models/cart_item.dart';
import '../models/menu_item.dart'; 
import '../providers/cart_provider.dart';
import '../providers/menu_provider.dart';
import '../providers/favorites_provider.dart' as favorites;
import '../providers/reviews_provider.dart';
import '../providers/location_provider.dart';
import '../providers/location_management_provider.dart';
import '../providers/address_provider.dart';
import '../models/user_address.dart';
import '../services/auth_service.dart';
import 'location.dart';
import 'dashboard_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';
import '../screens/login_screen.dart';
import '../utils/responsive_helper.dart';
import 'store_screen.dart';

// Define red color scheme
class RedColors {
  static const Color primary = Color(0xFFD32F2F);
  static const Color primaryDark = Color(0xFFB71C1C);
  static const Color primaryLight = Color(0xFFFF6659);
  static const Color background = Color(0xFFFAFAFA);
  static const Color white = Color(0xFFFFFFFF);
  static const Color darkText = Color(0xFF212121);
  static const Color lightGray = Color(0xFFE0E0E0);
  static const Color accent = Color(0xFFFF5252);
}



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
    DashboardScreen(),
    const StoreScreen(),
    const CartScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
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
        bottomNavigationBar: SalomonBottomBar(
          currentIndex: _currentIndex,
          selectedItemColor: RedColors.primary,
          unselectedItemColor: Colors.grey.shade600,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: [
            SalomonBottomBarItem(
              icon: const Icon(Icons.home),
              title: const Text("Home"),
              selectedColor: RedColors.primary,
            ),
            SalomonBottomBarItem(
              icon: const Icon(Icons.dashboard),
              title: const Text("Dashboard"),
              selectedColor: RedColors.primary,
            ),
            SalomonBottomBarItem(
              icon: const Icon(Icons.store),
              title: const Text("Store"),
              selectedColor: RedColors.primary,
            ),
            SalomonBottomBarItem(
              icon: Consumer<CartProvider>(
                builder: (context, cartProvider, child) {
                  final itemCount = cartProvider.totalQuantity;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.shopping_cart),
                      if (itemCount > 0)
                        Positioned(
                          right: -8,
                          top: -8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: RedColors.accent,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            child: Text(
                              itemCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              title: const Text("Cart"),
              selectedColor: RedColors.primary,
            ),
            SalomonBottomBarItem(
              icon: const Icon(Icons.person),
              title: const Text("Profile"),
              selectedColor: RedColors.primary,
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
    PageController? _promoPageController;
    Timer? _promoTimer;
  final _searchCtrl = TextEditingController();
  String _search = '';
  int _tabIndex = 0;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _popularKey = GlobalKey();

  TabController? _tabController;
  final Map<int, ScrollController> _scrollControllers = {};

  // Get trimmed location from AddressProvider (default address)
  String get _shortLocation {
    final addressProvider = Provider.of<AddressProvider>(context, listen: true);
    final defaultAddress = addressProvider.addresses.where((addr) => addr.isDefault).isEmpty 
        ? null 
        : addressProvider.addresses.where((addr) => addr.isDefault).first;
    
    if (defaultAddress != null) {
      final loc = defaultAddress.shortDisplay;
      // Trim: show only first 30 chars, add ... if longer
      if (loc.length > 30) {
        return '${loc.substring(0, 30)}...';
      }
      return loc;
    }
    
    // Fallback to LocationProvider if no address saved
    final locationProvider = Provider.of<LocationProvider>(context, listen: true);
    final loc = locationProvider.deliveryAddress ?? '';
    if (loc.length > 30) {
      return '${loc.substring(0, 30)}...';
    }
    return loc.isEmpty ? 'Set location' : loc;
  }

  // ADDED: Helper to load active location for delivery fee display
  Future<void> _loadActiveLocation(LocationProvider locationProvider, LocationManagementProvider locationManagementProvider) async {
    try {
      if (locationManagementProvider.locations.isEmpty) {
        await locationManagementProvider.loadLocations();
      }
      
      final activeLocations = locationManagementProvider.activeLocations;
      if (activeLocations.isNotEmpty) {
        locationProvider.setActiveLocation(activeLocations.first);
        debugPrint('📍 Home: Active location loaded: ${activeLocations.first.name}');
      }
    } catch (e) {
      debugPrint('❌ Home: Error loading active location: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final menuProvider = context.read<MenuProvider>();
      final addressProvider = context.read<AddressProvider>();
      final locationProvider = context.read<LocationProvider>();
      final locationManagementProvider = context.read<LocationManagementProvider>();
      
      // Load menu items, saved addresses, and active location in parallel
      Future.wait([
        menuProvider.loadMenuItems(),
        addressProvider.loadAddresses(), // Load saved addresses
        _loadActiveLocation(locationProvider, locationManagementProvider), // Load active location for delivery fee display
      ]).then((_) {
        if (mounted) {
          final cats = ['All', ...menuProvider.menuItems.map((e) => e.category).toSet()];
          
          _tabController = TabController(length: cats.length, vsync: this);
          
          debugPrint('✅ Home: Loaded ${menuProvider.menuItems.length} menu items and ${addressProvider.addresses.length} saved addresses');
          
          if (mounted) {
            setState(() {});
          }
        }
      }).catchError((error) {
        debugPrint('❌ Home: Error loading data: $error');
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    _tabController?.dispose();
    _promoTimer?.cancel();
    _promoPageController?.dispose();
    for (final c in _scrollControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  ScrollController _controller(int index) =>
      _scrollControllers.putIfAbsent(index, () => ScrollController());

  // ========== LANDING PAGE SECTIONS ==========

  // Enhanced Promotional Carousel
  Widget _buildPromotionalCarousel(List<MenuItem> meals, MenuProvider menuProvider) {
    final now = DateTime.now().hour;
    final closed = now < 7 || now >= 21;

    // Setup auto-scroll for carousel
    final carouselMeals = _getTimeBasedMeals(meals, now, menuProvider);
    final itemCount = carouselMeals.take(6).length;
    if (_promoPageController == null) {
      _promoPageController = PageController(viewportFraction: 0.93);
    }
    _promoTimer?.cancel();
    if (itemCount > 1) {
      _promoTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
        if (_promoPageController != null && _promoPageController!.hasClients) {
          final nextPage = (_promoPageController!.page?.round() ?? 0) + 1;
          _promoPageController!.animateToPage(
            nextPage % itemCount,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
        }
      });
    }

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
              color: RedColors.darkText,
            ),
          ),
        ),
        Builder(builder: (context) {
          if (closed) {
            return _closedCard();
          } else if (carouselMeals.isEmpty) {
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
                      style: TextStyle(color: RedColors.darkText.withOpacity(0.7)),
                    ),
                  ),
                ],
              ),
            );
          }

          // Colors for the cards
          final bannerColors = [
            RedColors.primary,
            const Color(0xFF43A047),
            const Color(0xFFFB8C00),
            const Color(0xFF1E88E5),
            const Color(0xFF8E24AA),
          ];

          // Dynamic messages based on time/item
          final List<Map<String, dynamic>> iconMessagePairs = [
            {'icon': Icons.local_offer, 'generator': (MenuItem item, int hour) => '🔥 Perfect ${_getMealPeriodName(hour)} deal!'},
            {'icon': Icons.star, 'generator': (MenuItem item, int hour) => '⭐ Popular ${_getMealPeriodName(hour)} choice!'},
            {'icon': Icons.shopping_basket, 'generator': (MenuItem item, int hour) => '🛒 Ideal ${_getMealPeriodName(hour)} pick!'},
            {'icon': Icons.whatshot, 'generator': (MenuItem item, int hour) => '🌶️ Hot pick for $hour:00!'},
            {'icon': Icons.thumb_up, 'generator': (MenuItem item, int hour) => '👍 Chef Recommended!'},
          ];

          final random = math.Random(DateTime.now().millisecondsSinceEpoch);
          final shuffledPairs = List<Map<String, dynamic>>.from(iconMessagePairs)..shuffle(random);

          return SizedBox(
            height: 200,
            child: PageView.builder(
              controller: _promoPageController,
              itemCount: itemCount,
              padEnds: false,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final item = carouselMeals[index];
                final color = bannerColors[index % bannerColors.length];
                final pair = shuffledPairs[index % shuffledPairs.length];
                final infoText = (pair['generator'] as dynamic Function(MenuItem, int))(item, now);

                return GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => MealDetailSheet(meal: item),
                    );
                  },
                  child: Container(
                    margin: EdgeInsets.only(
                      left: index == 0 ? 16 : 6,
                      right: index == itemCount - 1 ? 16 : 6,
                      bottom: 16,
                      top: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [color, color.withOpacity(0.85)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          right: -20, top: -40,
                          child: CircleAvatar(radius: 90, backgroundColor: Colors.white.withOpacity(0.1)),
                        ),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(20, 20, 0, 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(20)),
                                      child: Text(infoText, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(item.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, height: 1.1), maxLines: 2, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 6),
                                    Text('KSh ${item.price}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
                                      child: Text('Order Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: Container(
                                  height: 130, width: 130,
                                  margin: const EdgeInsets.only(right: 10),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.2),
                                    border: Border.all(color: Colors.white.withOpacity(0.6), width: 2),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 6))],
                                  ),
                                  child: ClipOval(
                                    child: Padding(
                                      padding: const EdgeInsets.all(10.0),
                                      child: _buildCarouselImage(item.imageUrl ?? ''),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        }),
      ],
    );
  }

  // --- HELPER: Time Logic ---
  String _getMealPeriodName(int hour) {
    if (hour >= 6 && hour < 11) return 'Breakfast';
    if (hour >= 11 && hour < 16) return 'Lunch';
    if (hour >= 16 && hour < 23) return 'Dinner';
    return 'Late Night';
  }

  // --- HELPER: Filter Meals by Time ---
  List<MenuItem> _getTimeBasedMeals(List<MenuItem> meals, int hour, MenuProvider menuProvider) {
    String preferredWeight;
    if (hour >= 7 && hour < 10) preferredWeight = 'Light';
    else if (hour >= 10 && hour < 12) preferredWeight = 'Medium';
    else if (hour >= 12 && hour < 16) preferredWeight = 'Heavy';
    else preferredWeight = 'Heavy';

    // Get meals that match the preferred weight and are available
    final preferredMeals = meals.where((m) => (m.mealWeight.name == preferredWeight) && menuProvider.isItemAvailable(m.title)).toList();
    
    if (preferredMeals.length >= 4) {
      preferredMeals.shuffle();
      return preferredMeals.take(6).toList();
    }
    
    // Fill with other meals if we don't have enough preferred ones
    final otherMeals = meals.where((m) => (m.mealWeight.name != preferredWeight) && menuProvider.isItemAvailable(m.title)).toList();
    final combined = [...preferredMeals, ...otherMeals];
    combined.shuffle();
    return combined.take(6).toList();
  }

  // --- HELPER: Card when Shop is Closed ---
  Widget _closedCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [RedColors.primary, RedColors.primaryLight]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: RedColors.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.schedule, color: Colors.white, size: 32)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Currently Closed', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Open daily: 7:00 AM - 9:00 PM', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPER: Image Builder ---
  Widget _buildCarouselImage(String imageUrl) {
    Widget errorWidget = const Icon(Icons.fastfood, size: 50, color: Colors.white);
    if (imageUrl.isEmpty) return errorWidget;
    if (imageUrl.startsWith('assets/')) {
      return Image.asset(imageUrl, fit: BoxFit.cover, errorBuilder: (_,__,___)=>errorWidget);
    }
    return Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_,__,___)=>errorWidget);
  }

  @override
  Widget build(BuildContext context) {
    final menuProvider = context.watch<MenuProvider>();
    final meals = menuProvider.menuItems;
    final isLoading = menuProvider.isLoading;
    final cats = ['All', ...meals.map((e) => e.category).toSet()];
    final filtered = meals.where((m) {
      final t = m.title.toLowerCase();
      final s = _search.toLowerCase();
      final c = _tabIndex == 0 ? true : m.category == cats[_tabIndex];
      return t.contains(s) && c;
    }).toList();
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: RedColors.background,
      body: SafeArea(
        child: NestedScrollView(
          controller: _scrollController,
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Location display
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, isLandscape ? 16 : 20, 16, 0),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () async {
                          final updated = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => LocationScreen()),
                          );
                          if (updated == true && mounted) setState(() {});
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.location_on, color: RedColors.primary, size: 22),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _shortLocation,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: RedColors.darkText,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    maxLines: 1,
                                  ),
                                ),
                                const Icon(Icons.chevron_right, color: RedColors.primary, size: 18),
                              ],
                            ),
                            // Delivery fee display with bike icon
                            Consumer<LocationProvider>(
                              builder: (context, locationProvider, _) {
                                final activeLocation = locationProvider.activeLocation;
                                
                                // Don't show anything if no active location loaded
                                if (activeLocation == null) {
                                  return const SizedBox.shrink();
                                }
                                
                                final hasUserLocation = locationProvider.latitude != null && 
                                                       locationProvider.longitude != null;
                                
                                String displayText;
                                Color textColor = RedColors.lightGray;
                                
                                if (!hasUserLocation) {
                                  // Show base fee when user hasn't set location
                                  final baseFee = activeLocation.deliveryBaseFee ?? 50;
                                  displayText = 'Delivery from KES $baseFee';
                                } else {
                                  final fee = locationProvider.deliveryFee;
                                  
                                  if (fee > 0) {
                                    displayText = 'Delivery: KES $fee';
                                  } else {
                                    displayText = 'Outside delivery area';
                                    textColor = Colors.orange;
                                  }
                                }
                                
                                return Padding(
                                  padding: const EdgeInsets.only(left: 28, top: 4),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.pedal_bike, color: RedColors.lightGray, size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        displayText,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: textColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Search bar
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, isLandscape ? 8 : 12, 16, 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: RedColors.white,
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
                            prefixIcon: Icon(Icons.search, color: RedColors.lightGray),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          ),
                        ),
                      ),
                    ),
                    // Promotional Carousel
                    _buildPromotionalCarousel(meals, menuProvider),
                    // Popular Items Section
                    Container(
                      key: _popularKey,
                      child: PopularItemsSection(
                        popularItems: menuProvider.popularItems
                            .where((item) => item.isAvailable) // Filter out unavailable items
                            .map((item) => PopularItem(
                              itemName: item.title,
                              productId: item.productId ?? '',
                              orderCount: 0,
                              avgUnitPrice: item.price.toDouble(),
                              avgRating: 0.0,
                              menuItem: item,
                            )).toList(),
                        isLoading: isLoading,
                        onNavigateToCart: () {
                          // Navigate to cart tab (index 3)
                          final homeScreenState = context.findAncestorStateOfType<_HomeScreenState>();
                          if (homeScreenState != null) {
                            homeScreenState._currentIndex = 3;
                            homeScreenState.setState(() {});
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // Sticky Category Tabs
              if (_tabController != null)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyTabBarDelegate(
                    TabBar(
                      controller: _tabController!,
                      isScrollable: true,
                      indicatorColor: RedColors.primary,
                      labelColor: RedColors.primary,
                      unselectedLabelColor: RedColors.darkText,
                      indicatorWeight: 3,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
                      tabs: cats.map((c) => Tab(text: c)).toList(),
                      onTap: (i) => setState(() => _tabIndex = i),
                    ),
                  ),
                ),
            ];
          },
          body: _tabController == null
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
                              color: RedColors.darkText.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No Meals Found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: RedColors.darkText.withOpacity(0.5),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _search.isEmpty 
                                  ? 'No meals in this category'
                                  : 'Try adjusting your search',
                              style: TextStyle(
                                color: RedColors.darkText.withOpacity(0.4),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return GridView.builder(
                      controller: _controller(e.key),
                      padding: EdgeInsets.fromLTRB(16, isLandscape ? 8 : 16, 16, 16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: ResponsiveHelper.getGridCrossAxisCount(context),
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _RiderStyleMealCard(meal: list[i]),
                    );
                  }).toList(),
                ),
        ),
      ),
    );
  }
}

// ========== STICKY TAB BAR DELEGATE ==========

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _StickyTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: RedColors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) {
    return false;
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

    final addedQuantity = 1;

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
          errorBuilder: (_, __, ___) => const Icon(Icons.fastfood, size: 40, color: RedColors.primary),
        ),
      );
    } else if (imageUrl != null) {
      flyWidget = ClipOval(
        child: Image.network(
          imageUrl,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.fastfood, size: 40, color: RedColors.primary),
        ),
      );
    } else {
      flyWidget = const Icon(Icons.fastfood, size: 40, color: RedColors.primary);
    }
    
    _flyToCart(context, homeScreenState._cartIconKey, flyWidget, () {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$addedQuantity × ${widget.meal.title} added to cart'),
          backgroundColor: RedColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }

  Widget _buildImageWidget(String? imageUrl) {
    Widget errorWidget = const Icon(Icons.fastfood, size: 60, color: RedColors.primary);
    
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
    
    // Sizing for 2-column layout
    final double cardPadding = isLandscape ? 8.0 : 12.0;
    final double titleFontSize = isLandscape ? 13.0 : 15.0;
    final double priceFontSize = isLandscape ? 13.0 : 15.0;
    final double buttonIconSize = isLandscape ? 18.0 : 20.0;
    
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => MealDetailSheet(meal: m),
        );
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = constraints.maxWidth;
          final imageHeight = cardWidth * 0.85; // Slightly reduced portrait
          
          return Container(
            decoration: BoxDecoration(
              color: RedColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: imageHeight,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    color: RedColors.white,
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: SizedBox.expand(
                          child: _buildImageWidget(m.imageUrl),
                        ),
                      ),
                      // Out of Stock Badge
                      if (!isAvailable)
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
                      // Add button at bottom right of image
                      if (isAvailable)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Material(
                            color: RedColors.primary,
                            shape: const CircleBorder(),
                            elevation: 2,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => _addToCart(),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: buttonIconSize,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(cardPadding * 0.7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        m.title,
                        style: TextStyle(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                          color: RedColors.darkText,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 2),
                          Text(
                            '4.5',
                            style: TextStyle(
                              fontSize: 12,
                              color: isAvailable ? RedColors.darkText : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ksh ${m.price}',
                        style: TextStyle(
                          fontSize: priceFontSize,
                          fontWeight: FontWeight.bold,
                          color: isAvailable ? RedColors.primary : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ========== ANIMATED DOT ==========

class AnimatedDot extends StatefulWidget {
  final int index;
  final Color color;
  const AnimatedDot({super.key, required this.index, required this.color});

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
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}

// --- POPULAR ITEMS SECTION ---

// MODEL FOR AGGREGATED POPULAR DATA
class PopularItem {
  final String itemName;
  final String productId;
  final int orderCount;
  final double avgUnitPrice;
  final double avgRating;

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

// POPULAR ITEMS SECTION WIDGET
class PopularItemsSection extends StatelessWidget {
  final List<PopularItem> popularItems;
  final bool isLoading;
  final VoidCallback? onNavigateToCart;

  const PopularItemsSection({
    super.key,
    required this.popularItems,
    this.isLoading = false,
    this.onNavigateToCart,
  });

  Widget _buildHorizontalList(BuildContext context) {
    final isDataLoading = isLoading && popularItems.isEmpty;
    final listCount = isDataLoading ? 5 : popularItems.length;

    if (!isDataLoading && popularItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 250,
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
              ? const _PopularItemSkeletonCard()
              : _PopularItemCard(
                  item: popularItems[index],
                  onNavigateToCart: onNavigateToCart,
                ),
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
              color: RedColors.darkText.withOpacity(isDataLoading ? 0.3 : 1.0),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            "Tried and tested favorites from our community.",
            style: TextStyle(
              fontSize: 14,
              color: RedColors.darkText.withOpacity(isDataLoading ? 0.3 : 1.0),
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

// INDIVIDUAL CARD WIDGET
class _PopularItemCard extends StatelessWidget {
  final PopularItem item;
  final VoidCallback? onNavigateToCart;

  const _PopularItemCard({
    required this.item,
    this.onNavigateToCart,
  });

  void _showMenuItemModal(BuildContext context, MenuItem meal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MealDetailSheet(meal: meal),
    );
  }

  void _addToCart(BuildContext context) {
    if (item.menuItem == null) return;
    
    HapticFeedback.lightImpact();
    
    final homeScreenState = context.findAncestorStateOfType<_HomeScreenState>();
    if (homeScreenState == null) return;
    
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final cartItem = CartItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      menuItemId: item.menuItem!.id ?? '',
      mealTitle: item.menuItem!.title,
      price: item.menuItem!.price,
      quantity: 1,
      mealImage: item.menuItem!.imageUrl ?? '',
    );
    
    cartProvider.addItem(cartItem);
    
    // Create flying widget
    final imageUrl = item.menuItem!.imageUrl;
    Widget flyWidget;
    
    if (imageUrl != null && imageUrl.startsWith('assets/')) {
      flyWidget = ClipOval(
        child: Image.asset(
          imageUrl,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.fastfood, size: 40, color: RedColors.primary),
        ),
      );
    } else if (imageUrl != null) {
      flyWidget = ClipOval(
        child: Image.network(
          imageUrl,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.fastfood, size: 40, color: RedColors.primary),
        ),
      );
    } else {
      flyWidget = const Icon(Icons.fastfood, size: 40, color: RedColors.primary);
    }
    
    _flyToCart(context, homeScreenState._cartIconKey, flyWidget, () {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('1 × ${item.menuItem!.title} added to cart'),
          backgroundColor: RedColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.menuItem?.imageUrl;
    final price = item.avgUnitPrice.toStringAsFixed(2);
    final title = item.itemName;
    final rating = item.avgRating.toStringAsFixed(1);
    
    const reduction = 0.80;
    final double cardWidth = 180 * reduction;
    final double titleFontSize = 13.0;
    final double priceFontSize = 13.0;

    return GestureDetector(
      onTap: () {
        if (item.menuItem != null) {
          _showMenuItemModal(context, item.menuItem!);
        }
      },
      child: Container(
        width: cardWidth,
        decoration: BoxDecoration(
          color: RedColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: RedColors.lightGray.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Container(
                    height: cardWidth * 0.85, // Reduced portrait height
                    width: double.infinity,
                    color: RedColors.background,
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => 
                              const Icon(Icons.fastfood, size: 50, color: RedColors.primary),
                          )
                        : const Icon(Icons.restaurant, size: 50, color: RedColors.primary),
                  ),
                ),
                // Popular Tag
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Popular',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: titleFontSize,
                      color: RedColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 10),
                      const SizedBox(width: 2),
                      Text(
                        item.avgRating > 0 ? rating : '4.5',
                        style: const TextStyle(fontSize: 10, color: RedColors.darkText),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ksh $price',
                    style: TextStyle(
                      fontSize: priceFontSize,
                      fontWeight: FontWeight.bold,
                      color: RedColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  SizedBox(
                    width: double.infinity,
                    height: 30,
                    child: OutlinedButton(
                      onPressed: () => _addToCart(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: RedColors.primary,
                        side: const BorderSide(color: RedColors.primary, width: 1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: EdgeInsets.zero
                      ),
                      child: const Text('Add to Cart', style: TextStyle(fontSize: 11)),
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

// SKELETON CARD WIDGET
class _PopularItemSkeletonCard extends StatelessWidget {
  const _PopularItemSkeletonCard();

  @override
  Widget build(BuildContext context) {
    const reduction = 0.80;
    final double cardWidth = 180 * reduction;
    final double imageHeight = 120 * reduction;
    
    return Container(
      width: cardWidth,
      decoration: BoxDecoration(
        color: RedColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: RedColors.lightGray.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: imageHeight,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 120,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 10),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 50,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
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

                Container(
                  width: double.infinity,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
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

// ========== MEAL DETAIL SHEET MODAL ==========

class MealDetailSheet extends StatefulWidget {
  final MenuItem meal;
  
  const MealDetailSheet({super.key, required this.meal});

  @override
  State<MealDetailSheet> createState() => _MealDetailSheetState();
}

class _MealDetailSheetState extends State<MealDetailSheet> {
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    // Favorites will be checked in build method with Provider
  }

  void _addToCart() {
    final menuProvider = Provider.of<MenuProvider>(context, listen: false);
    if (!menuProvider.isItemAvailable(widget.meal.title)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This item is currently unavailable')),
      );
      return;
    }

    HapticFeedback.lightImpact();
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    
    for (int i = 0; i < _quantity; i++) {
      final cartItem = CartItem(
        id: DateTime.now().millisecondsSinceEpoch.toString() + i.toString(),
        menuItemId: widget.meal.id ?? '',
        mealTitle: widget.meal.title,
        price: widget.meal.price,
        quantity: 1,
        mealImage: widget.meal.imageUrl ?? '',
      );
      cartProvider.addItem(cartItem);
    }

    Navigator.pop(context);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$_quantity × ${widget.meal.title} added to cart'),
        backgroundColor: RedColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildImageWidget(String? imageUrl) {
    Widget errorWidget = const Icon(Icons.fastfood, size: 100, color: RedColors.primary);
    
    if (imageUrl == null) return errorWidget;
    
    if (imageUrl.startsWith('assets/')) {
      return Image.asset(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => errorWidget);
    }
    
    return Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => errorWidget);
  }

  Widget _buildReviewsSection(ReviewsProvider reviewsProvider) {
    final reviews = reviewsProvider.getReviewsForProduct(widget.meal.id ?? '');
    final averageRating = reviewsProvider.getAverageRating(widget.meal.id ?? '');
    final distribution = reviewsProvider.getRatingDistribution(widget.meal.id ?? '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reviews',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: RedColors.darkText,
          ),
        ),
        const SizedBox(height: 16),
        
        // Average rating summary - Match meal_detail_screen exactly
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
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
                      color: RedColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (index) {
                      return Icon(
                        index < averageRating.floor() ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 20,
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${reviews.length} reviews',
                    style: TextStyle(
                      fontSize: 12,
                      color: RedColors.darkText.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              // Distribution bars
              Expanded(
                child: Column(
                  children: List.generate(5, (index) {
                    final starNum = 5 - index;
                    final percentage = distribution[starNum] ?? 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Text(
                            '$starNum',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Icon(Icons.star, size: 12, color: Colors.amber),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: percentage / 100,
                                backgroundColor: Colors.grey[200],
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                                minHeight: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 30,
                            child: Text(
                              '${percentage.toInt()}%',
                              style: TextStyle(
                                fontSize: 11,
                                color: RedColors.darkText.withOpacity(0.6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Reviews list
        if (reviews.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.rate_review_outlined, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  Text(
                    'No Reviews Yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: reviews.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final review = reviews[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: RedColors.primary,
                          child: Text(
                            (review.displayName.isNotEmpty ? review.displayName[0] : 'U').toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                review.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _formatTimestamp(review.createdAt),
                          style: TextStyle(
                            color: RedColors.darkText.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(5, (i) {
                        return Icon(
                          i < review.rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 16,
                        );
                      }),
                    ),
                    if (review.hasComment) ...[
                      const SizedBox(height: 12),
                      Text(
                        review.displayComment,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: RedColors.darkText.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSimilarMealsSection(MenuProvider menuProvider) {
    final similarMeals = menuProvider.menuItems
        .where((item) =>
            item.category == widget.meal.category &&
            item.title != widget.meal.title &&
            menuProvider.isItemAvailable(item.title))
        .take(5)
        .toList();

    if (similarMeals.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Others You Might Like',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: RedColors.darkText,
              ),
            ),
            const Text(
              'See all',
              style: TextStyle(
                color: RedColors.primary,
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
            itemCount: similarMeals.length,
            itemBuilder: (context, index) {
              final meal = similarMeals[index];
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => MealDetailSheet(meal: meal),
                  );
                },
                child: Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
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
                      // Image - exactly 100px height like meal_detail_screen
                      Container(
                        height: 100,
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: _buildImageWidget(meal.imageUrl),
                        ),
                      ),
                      // Content
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Title
                              Text(
                                meal.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: RedColors.darkText,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              // Category
                              Text(
                                meal.category,
                                style: TextStyle(
                                  color: RedColors.darkText.withOpacity(0.6),
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
                                        meal.rating.toString(),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Flexible(
                                    child: Text(
                                      'Ksh ${meal.price}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: RedColors.primary,
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
            },
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final menuProvider = context.watch<MenuProvider>();
    final reviewsProvider = context.watch<ReviewsProvider>();
    final favoritesProvider = context.watch<favorites.FavoritesProvider>();
    final authService = context.watch<AuthService>();
    final isAvailable = menuProvider.isItemAvailable(widget.meal.title);
    
    final userId = authService.currentUser?.id ?? 'guest';
    final productId = widget.meal.id ?? '';
    final isFavorite = favoritesProvider.isFavorite(userId, productId, type: favorites.FavoriteItemType.menuItem);
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
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
                  // Image with out-of-stock badge
                  Stack(
                    children: [
                      Container(
                        height: 250,
                        width: double.infinity,
                        color: Colors.white,
                        child: _buildImageWidget(widget.meal.imageUrl),
                      ),
                      if (!isAvailable)
                        Positioned(
                          top: 16,
                          left: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Out of Stock',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  
                  // Product info
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.meal.category,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.meal.title,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: RedColors.darkText,
                                    ),
                                  ),
                                  if (widget.meal.description?.isNotEmpty ?? false) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      widget.meal.description ?? '',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                isFavorite ? Icons.favorite : Icons.favorite_border,
                                color: isFavorite ? Colors.red : Colors.grey,
                              ),
                              onPressed: () async {
                                if (userId != 'guest' && productId.isNotEmpty) {
                                  HapticFeedback.lightImpact();
                                  await favoritesProvider.toggleFavorite(userId, productId, type: favorites.FavoriteItemType.menuItem);
                                }
                              },
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Price and stock
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Ksh ${widget.meal.price}',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: RedColors.primary,
                              ),
                            ),
                            if (isAvailable)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green),
                                ),
                                child: const Text(
                                  'In Stock',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        
                        // Quantity selector (only if in stock)
                        if (isAvailable) ...[
                          const SizedBox(height: 20),
                          const Text(
                            'Quantity',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: RedColors.darkText,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              // Minus button
                              Material(
                                color: _quantity > 1 ? RedColors.primary : Colors.grey[300],
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: _quantity > 1 ? () {
                                    HapticFeedback.lightImpact();
                                    setState(() => _quantity--);
                                  } : null,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    child: const Icon(
                                      Icons.remove,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Text(
                                  '$_quantity',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: RedColors.darkText,
                                  ),
                                ),
                              ),
                              // Plus button
                              Material(
                                color: RedColors.primary,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    setState(() => _quantity++);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    child: const Icon(
                                      Icons.add,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        
                        const SizedBox(height: 24),
                        
                        // Reviews Section
                        _buildReviewsSection(reviewsProvider),
                        
                        const SizedBox(height: 24),
                        
                        // You might also like
                        _buildSimilarMealsSection(menuProvider),
                        
                        const SizedBox(height: 100), // Space for fixed button
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Fixed bottom button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: isAvailable ? _addToCart : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAvailable ? RedColors.primary : Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    isAvailable ? 'Add to Cart' : 'Out of Stock',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}