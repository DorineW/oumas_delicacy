// ------------------------------------------------------------
//  lib/screens/home_screen.dart  (replace entire file)
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

/* ----------------------------------------------------------
   1.  ENTRY POINT (no changes – keeps bottom nav logic)
----------------------------------------------------------- */
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    const _HomeTab(),
    const DashboardScreen(),
    const CartScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final cartQty = context.watch<CartProvider>().totalQuantity;
    return Scaffold(
      extendBody: true,
      body: _screens[_currentIndex],
      bottomNavigationBar: _glassBottomNav(_currentIndex, (i) => setState(() => _currentIndex = i), cartQty),
    );
  }
}

/* ---------- glass nav (unchanged) ---------- */
Widget _glassBottomNav(int idx, ValueChanged<int> onTap, int cartQty) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.white.withOpacity(.82),
            border: Border.all(color: AppColors.white.withOpacity(.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.home, 'Home', 0, idx, onTap),
              _navItem(Icons.dashboard, 'Dashboard', 1, idx, onTap),
              _navItem(
                Icons.shopping_cart,
                'Cart',
                2,
                idx,
                onTap,
                badge: cartQty,
                iconKey: const ValueKey('cartIcon'),   // <-- KEY for target
              ),
              _navItem(Icons.person, 'Profile', 3, idx, onTap),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _navItem(IconData icon, String label, int index, int selected, ValueChanged<int> onTap, {int badge = 0, Key? iconKey}) {
  final isSelected = index == selected;
  return Expanded(
    child: GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        alignment: Alignment.center,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, 
                  key: iconKey,
                  color: isSelected ? AppColors.primary : AppColors.lightGray),
              const SizedBox(height: 2),
              Text(label, 
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: isSelected ? AppColors.primary : AppColors.lightGray))
            ]),
            if (badge > 0)
              Positioned(
                right: -4,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Center(
                      child: Text('$badge',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                ),
              )
          ],
        ),
      ),
    ),
  );
}

/* ----------------------------------------------------------
   HOME TAB  (old look – normal AppBar + drawer + tabs)
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(children: [
          Image.asset('assets/images/app_icon.png', width: 32, height: 32, errorBuilder: (_, __, ___) => const Icon(Icons.restaurant, color: AppColors.primary)),
          const SizedBox(width: 8),
          const Text("Ouma's Delicacy", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText)),
        ]),
        backgroundColor: AppColors.white,
        elevation: 2,
        actions: [
          IconButton(
              onPressed: () async {
                await Provider.of<AuthService>(context, listen: false).logout();
                if (context.mounted) {
                  // Navigate to login screen directly instead of using named route
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
              icon: const Icon(Icons.logout, color: AppColors.darkText))
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
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Image.asset('assets/images/app_icon.png', width: 56, height: 56),
                    const SizedBox(height: 12),
                    const Text('Ouma\'s Delicacy',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText)),
                  ]),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      ListTile(leading: const Icon(Icons.home), title: const Text('Home'), onTap: () => Navigator.pop(context)),
                      ListTile(leading: const Icon(Icons.dashboard), title: const Text('Dashboard'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const DashboardScreen())); }),
                      ListTile(leading: const Icon(Icons.shopping_cart), title: const Text('Cart'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())); }),
                      ListTile(leading: const Icon(Icons.person), title: const Text('Profile'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())); }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 8, offset: const Offset(0, 2))
                ],
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                    hintText: 'Search meals…',
                    prefixIcon: const Icon(Icons.search, color: AppColors.lightGray),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16)),
              ),
            ),
          ),
          // ----  NEW time-aware carousel  ----
          Builder(builder: (context) {
            final now = DateTime.now().hour;
            final closed = now < 7 || now >= 21;

            if (closed) {
              return Column(children: [
                const SizedBox(height: 12),
                _closedCard(),
              ]);
            } else {
              return Column(children: [
                Carousel(
                  height: 150,
                  interval: const Duration(seconds: 4),
                  children: meals.take(4).map((m) => _carouselCard(context, m)).toList(),
                ),
                const SizedBox(height: 12),
              ]);
            }
          }),
          // ------------------------------------
          // category tabs
          Container(
            color: AppColors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.darkText,
              indicatorWeight: 3,
              tabs: cats.map((c) => Tab(text: c)).toList(),
              onTap: (i) => setState(() => _tabIndex = i),
            ),
          ),
          // grid
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: cats.asMap().entries.map((e) {
                final list = e.key == 0 ? filtered : filtered.where((m) => m['category'] == cats[e.key]).toList();
                if (list.isEmpty) return const Center(child: Text('No meals found'));
                return GridView.builder(
                  controller: _controller(e.key),
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                      childAspectRatio: .75,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _ModernMealCard(meal: list[i]),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------  HELPERS  ----------------
  String _timeGreeting() {
    final h = DateTime.now().hour;
    if (h < 7)  return '😴 Closed – opens 7 AM';
    if (h < 10) return '🌅 Early-break';
    if (h < 12) return '☕ Mid-morning bunch';
    if (h < 15) return '🍽️ Lunch o\'clock';
    if (h < 18) return '🍵 Afternoon munch';
    if (h < 21) return '🌆 Evening feast';
    return '😴 Closed – see you tomorrow!';
  }

  Widget _carouselCard(BuildContext context, Map<String,dynamic> m) {
    final greeting = _timeGreeting();
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MealDetailScreen(meal: m)),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(colors: [AppColors.primary, AppColors.accent]),
        ),
        child: Stack(
          children: [
            _floatingDots(),          // behind everything
            // content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  // CIRCULAR plated food (logo style)
                  _circularPlate(context, m),
                  const SizedBox(width: 16),
                  // text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(greeting,
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(m['title'],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Ksh ${m['price']}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 14)),
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
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MealDetailScreen(meal: m)),
      ),
      child: Material(
        elevation: 6,
        color: AppColors.cardBackground,
        shape: const CircleBorder(),
        child: Container(
          width: 90,
          height: 90,
          padding: const EdgeInsets.all(6),
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child: ClipOval(
            child: Image.asset(
              m['image'],
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.fastfood, size: 40, color: AppColors.lightGray),
            ),
          ),
        ),
      ),
    );
  }

  // ----------  dots background (behind text) ----------
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
    margin: const EdgeInsets.symmetric(horizontal: 24),
    height: 120,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      color: AppColors.lightGray.withOpacity(.15),
    ),
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.watch_later, size: 40, color: AppColors.primary),
          SizedBox(height: 8),
          Text('We\'re asleep 😴', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          Text('Open again at 7 AM', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    ),
  );
}

// ----------  FLY TO CART ANIMATION  ----------
OverlayEntry? _currentOverlay;

void _flyToCart(BuildContext context, Key cartKey, Widget flyingWidget, VoidCallback onEnd) {
  final overlay = Overlay.of(context);
  final renderBox = context.findRenderObject() as RenderBox?;
  
  // Find the cart icon using the key
  RenderBox? cartRenderBox;
  void visitChildren(Element element) {
    if (element.widget.key == cartKey) {
      cartRenderBox = element.renderObject as RenderBox?;
      return;
    }
    element.visitChildren(visitChildren);
  }
  
  if (context.mounted) {
    context.visitChildElements(visitChildren);
  }
  
  if (renderBox == null || cartRenderBox == null) {
    onEnd(); // fallback
    return;
  }

  final start = renderBox.localToGlobal(Offset.zero);
  final end = cartRenderBox!.localToGlobal(Offset.zero) + const Offset(12, 12);

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
   MODERN CARD  (fly-to-cart animation + shadow)
----------------------------------------------------------- */
class _ModernMealCard extends StatefulWidget {
  final Map<String, dynamic> meal;
  const _ModernMealCard({required this.meal});

  @override
  State<_ModernMealCard> createState() => _ModernMealCardState();
}

class _ModernMealCardState extends State<_ModernMealCard>
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

    HapticFeedback.lightImpact(); // 1. vibration

    final cartKey = const ValueKey('cartIcon');
    final cart = context.read<CartProvider>();
    cart.addItem(CartItem(
      id: '${widget.meal['title']}_${DateTime.now().millisecondsSinceEpoch}',
      mealTitle: widget.meal['title'],
      price: (widget.meal['price'] as num).toInt(),
      quantity: _qty,
      mealImage: widget.meal['image'] ?? '',
    ));

    // 2. fly animation
    final flyWidget = ClipOval(
      child: Image.asset(widget.meal['image'] ?? '',
          width: 50, height: 50, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.fastfood, size: 40)),
    );
    _flyToCart(context, cartKey, flyWidget, () {
      // 3. orange snack-bar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$_qty × ${widget.meal['title']} added'),
          backgroundColor: AppColors.accent,
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
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withOpacity(.08),
              blurRadius: 12,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(children: [
        // image
        Expanded(
          flex: 5,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                image: DecorationImage(
                    image: AssetImage(m['image'] ?? ''),
                    fit: BoxFit.cover,
                    onError: (_, __) => const AssetImage(''))),
          ),
        ),
        // info
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: FittedBox(                       // shrink to fit
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        m['title'],
                        style: const TextStyle(
                          fontSize: 14,                     // original desired size
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    Flexible(
                      child: Text('Ksh ${m['price']}',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(8)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: IconButton(
                              padding: EdgeInsets.zero,
                              iconSize: 16,
                              onPressed: () => setState(() => _qty = math.max(0, _qty - 1)),
                              icon: const Icon(Icons.remove)),
                        ),
                        SizedBox(
                          width: 20,
                          child: Center(
                            child: Text('$_qty',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: IconButton(
                              padding: EdgeInsets.zero,
                              iconSize: 16,
                              onPressed: () => setState(() => _qty++),
                              icon: const Icon(Icons.add)),
                        ),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    height: 32,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 1, end: 1.4)
                          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut)),
                      child: ElevatedButton(
                          onPressed: _addToCart,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _qty > 0 ? AppColors.accent : AppColors.lightGray,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Icon(Icons.shopping_cart, color: Colors.white, size: 16)),
                    ),
                  )
                ]),
          ),
        )
      ]),
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