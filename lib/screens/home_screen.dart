// ------------------------------------------------------------
//  lib/screens/home_screen.dart  
// ------------------------------------------------------------
// ignore_for_file: unused_import, deprecated_member_use

import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../widgets/carousel.dart';

import '../constants/colors.dart';
import '../models/cart_item.dart';
import '../providers/cart_provider.dart';
import '../providers/menu_provider.dart';
import 'dashboard_screen.dart';
import 'cart_screen.dart';
import 'meal_detail_screen.dart';
import 'profile_screen.dart';
import '../services/auth_service.dart';
import '../screens/login_screen.dart'; // Add this import
import '../utils/responsive_helper.dart';

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
  // ADDED: GlobalKey for cart icon
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
              // FIXED: Use Container with GlobalKey wrapper
              icon: Container(
                key: _cartIconKey, // ADDED: GlobalKey here!
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
   UPDATED HOME TAB WITH RIDER APP STYLING
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

  late TabController _tabController;
  final Map<int, ScrollController> _scrollControllers = {};

  @override
  void initState() {
    super.initState();
    final cats = context.read<MenuProvider>().menuItems
                   .map((e) => e['category'])
                   .toSet()
                   .toList();
    _tabController = TabController(length: cats.length + 1, vsync: this);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabController.dispose();
    for (final c in _scrollControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  ScrollController _controller(int index) =>
      _scrollControllers.putIfAbsent(index, () => ScrollController());

  @override
  Widget build(BuildContext context) {
    final meals = context.watch<MenuProvider>().menuItems;
    final cats = ['All', ...meals.map((e) => e['category']).toSet()];
    final filtered = meals.where((m) {
      final t = m['title'].toString().toLowerCase();
      final s = _search.toLowerCase();
      final c = _tabIndex == 0 ? true : m['category'] == cats[_tabIndex];
      return t.contains(s) && c;
    }).toList();
    
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: AppColors.background,
      // UPDATED APP BAR TO MATCH RIDER APP
      appBar: AppBar(
        title: const Text("Ouma's Delicacy"),
        backgroundColor: AppColors.primary,
        elevation: 4,
        iconTheme: const IconThemeData(color: AppColors.white),
        titleTextStyle: const TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await Provider.of<AuthService>(context, listen: false).logout();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      // UPDATED DRAWER TO MATCH RIDER APP STYLING
      drawer: Drawer(
        child: SafeArea(
          child: Container(
            color: AppColors.background,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withOpacity(0.8),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/images/app_icon.png', width: 64, height: 64),
                      const SizedBox(height: 12),
                      const Text('Ouma\'s Delicacy',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.white)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _drawerItem(Icons.home, 'Home', () => Navigator.pop(context)),
                      _drawerItem(Icons.dashboard, 'Dashboard', () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
                      }),
                      _drawerItem(Icons.shopping_cart, 'Cart', () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
                      }),
                      _drawerItem(Icons.person, 'Profile', () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              // UPDATED SEARCH BAR TO MATCH RIDER APP STYLING
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
              // UPDATED CAROUSEL SECTION
              Builder(builder: (context) {
                final now = DateTime.now().hour;
                final closed = now < 7 || now >= 21;

                if (closed) {
                  return _closedCard();
                } else {
                  return Column(children: [
                    Carousel(
                      height: isLandscape ? 120 : 150,
                      interval: const Duration(seconds: 4),
                      children: meals.take(4).map((m) => _carouselCard(context, m)).toList(),
                    ),
                    SizedBox(height: isLandscape ? 8 : 12),
                  ]);
                }
              }),
              // UPDATED CATEGORY TABS TO MATCH RIDER APP
              Container(
                color: AppColors.white,
                child: TabBar(
                  controller: _tabController,
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
              // UPDATED GRID WITH BOTTOM PADDING
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: cats.asMap().entries.map((e) {
                    final list = e.key == 0 ? filtered : filtered.where((m) => m['category'] == cats[e.key]).toList();
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
                    return GridView.builder(
                      controller: _controller(e.key),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: ResponsiveHelper.getGridCrossAxisCount(context),
                        childAspectRatio: ResponsiveHelper.getGridChildAspectRatio(context),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _RiderStyleMealCard(meal: list[i]),
                    );
                  }).toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // UPDATED DRAWER ITEM
  Widget _drawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: const TextStyle(color: AppColors.darkText)),
      onTap: onTap,
    );
  }

  // UPDATED CAROUSEL CARD
  Widget _carouselCard(BuildContext context, Map<String,dynamic> m) {
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
                        Text(
                          'Special Offer!',
                          style: TextStyle(
                            color: AppColors.white.withOpacity(0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          m['title'],
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
                          'Ksh ${m['price']}',
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

  Widget _circularPlate(BuildContext context, Map<String,dynamic> m) {
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
          child: Image.asset(
            m['image'],
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.fastfood, size: 40, color: AppColors.primary),
          ),
        ),
      ),
    );
  }

  Widget _floatingDots() {
    return SizedBox.expand(
      child: Stack(
        children: List.generate(
          5,
          (i) => Positioned(
            left: 20.0 + i * (MediaQuery.of(context).size.width * 0.15),
            bottom: 12,
            child: AnimatedDot(
              key: ValueKey('dot$i'), // new key every page → forces re-animation
              index: i,
            ),
          ),
        ),
      ),
    );
  }

  Widget _closedCard() => Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.all(20),
    height: 120,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      color: AppColors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.1),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'We\'re Closed',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Open again at 7 AM',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.darkText,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.watch_later,
            size: 30,
            color: AppColors.primary,
          ),
        ),
      ],
    ),
  );
}

// ----------  FLY TO CART ANIMATION  ----------
OverlayEntry? _currentOverlay;

void _flyToCart(BuildContext context, GlobalKey cartKey, Widget flyingWidget, VoidCallback onEnd) {
  final overlay = Overlay.of(context);
  final renderBox = context.findRenderObject() as RenderBox?;
  
  // FIXED: Use GlobalKey to find cart icon directly
  final cartRenderBox = cartKey.currentContext?.findRenderObject() as RenderBox?;
  
  if (renderBox == null || cartRenderBox == null) {
    debugPrint('❌ Fly-to-cart: Could not find renderBoxes');
    onEnd(); // fallback
    return;
  }

  final start = renderBox.localToGlobal(Offset.zero);
  final cartSize = cartRenderBox.size;
  // Aim for center of cart icon
  final end = cartRenderBox.localToGlobal(Offset(cartSize.width / 2, cartSize.height / 2));

  debugPrint('✅ Fly-to-cart: Starting animation from $start to $end');

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

/* ----------------------------------------------------------
   UPDATED MEAL CARD WITH RIDER APP STYLING
----------------------------------------------------------- */
class _RiderStyleMealCard extends StatefulWidget {
  final Map<String, dynamic> meal;
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

    HapticFeedback.lightImpact();

    // FIXED: Get the GlobalKey from HomeScreen
    final homeScreenState = context.findAncestorStateOfType<_HomeScreenState>();
    if (homeScreenState == null) {
      debugPrint('❌ Could not find HomeScreen state');
      return;
    }

    final cart = context.read<CartProvider>();
    cart.addItem(CartItem(
      id: '${widget.meal['title']}_${DateTime.now().millisecondsSinceEpoch}',
      mealTitle: widget.meal['title'],
      price: (widget.meal['price'] as num).toInt(),
      quantity: _qty,
      mealImage: widget.meal['image'] ?? '',
    ));

    final flyWidget = ClipOval(
      child: Image.asset(
        widget.meal['image'] ?? '',
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.fastfood, size: 40, color: AppColors.primary),
      ),
    );
    
    // FIXED: Pass GlobalKey instead of ValueKey
    _flyToCart(context, homeScreenState._cartIconKey, flyWidget, () {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$_qty × ${widget.meal['title']} added to cart'),
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    });

    setState(() => _qty = 0);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.meal;
    final isLandscape = ResponsiveHelper.isLandscape(context);
    
    return Card(
      elevation: 3,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image - FIXED: Use Flexible with proper sizing
          Flexible(
            flex: isLandscape ? 4 : 5,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                image: DecorationImage(
                  image: AssetImage(m['image'] ?? ''),
                  fit: BoxFit.cover,
                  onError: (_, __) => const AssetImage(''),
                ),
              ),
            ),
          ),
          // Content - FIXED: Better space distribution
          Flexible(
            flex: isLandscape ? 4 : 3,
            child: Padding(
              padding: EdgeInsets.all(isLandscape ? 8 : 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availableHeight = constraints.maxHeight;
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title - FIXED: Constrained height
                      Container(
                        height: math.min(availableHeight * 0.3, 36),
                        child: Text(
                          m['title'],
                          style: TextStyle(
                            fontSize: isLandscape ? 12 : 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkText,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Price - FIXED: Single line
                      Text(
                        'Ksh ${m['price']}',
                        style: TextStyle(
                          fontSize: isLandscape ? 12 : 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      // Quantity and Cart - FIXED: Compact layout
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Quantity selector - FIXED: Smaller in landscape
                          Flexible(
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: isLandscape ? 24 : 28,
                                    height: isLandscape ? 24 : 28,
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      iconSize: isLandscape ? 14 : 16,
                                      onPressed: () => setState(() => _qty = math.max(0, _qty - 1)),
                                      icon: const Icon(Icons.remove, color: AppColors.primary),
                                    ),
                                  ),
                                  SizedBox(
                                    width: isLandscape ? 16 : 20,
                                    child: Center(
                                      child: Text(
                                        '$_qty',
                                        style: TextStyle(
                                          fontSize: isLandscape ? 11 : 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: isLandscape ? 24 : 28,
                                    height: isLandscape ? 24 : 28,
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      iconSize: isLandscape ? 14 : 16,
                                      onPressed: () => setState(() => _qty++),
                                      icon: const Icon(Icons.add, color: AppColors.primary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Add to cart button - FIXED: Flexible sizing
                          Flexible(
                            child: SizedBox(
                              width: isLandscape ? 70 : 80,
                              height: isLandscape ? 28 : 32,
                              child: ScaleTransition(
                                scale: Tween<double>(begin: 1, end: 1.4)
                                    .animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut)),
                                child: ElevatedButton(
                                  onPressed: _qty > 0 ? _addToCart : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _qty > 0 ? AppColors.primary : AppColors.lightGray,
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  child: Icon(
                                    Icons.shopping_cart,
                                    color: Colors.white,
                                    size: isLandscape ? 14 : 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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

/// Simple animated dot used in the carousel background.
/// Keeps the file-local implementation to resolve the undefined symbol.
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