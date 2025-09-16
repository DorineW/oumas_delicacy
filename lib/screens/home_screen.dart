// lib/screens/home_screen.dart
// ignore_for_file: unused_import

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

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    HomeContentScreen(),
    const DashboardScreen(),
    const CartScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.lightGray,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Cart',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// Extract the home content to a separate widget
class HomeContentScreen extends StatefulWidget {
  @override
  State<HomeContentScreen> createState() => _HomeContentScreenState();
}

class _HomeContentScreenState extends State<HomeContentScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final atBottom = _scrollController.offset >=
          _scrollController.position.maxScrollExtent - 50;
      setState(() {
        _showScrollToTop = atBottom;
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
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

    final Set<String> categorySet = {'All'};
    for (var meal in meals) {
      final cat = meal['category']?.toString();
      if (cat != null && cat.isNotEmpty) categorySet.add(cat);
    }
    final List<String> categories = categorySet.toList();

    final filteredItems = filteredMeals(meals);

    final width = MediaQuery.of(context).size.width;
    final int crossAxisCount = width > 1000 ? 4 : (width > 700 ? 3 : 2);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Ouma's Delicacy"),
        backgroundColor: AppColors.primary,
        elevation: 4,
        iconTheme: const IconThemeData(color: AppColors.white),
        actionsIconTheme: const IconThemeData(color: AppColors.white),
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
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search meals...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: AppColors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppColors.lightGray),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppColors.lightGray),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppColors.primary),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                Container(
                  color: AppColors.white,
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    height: 50,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        final selected = _selectedCategory == category;
                        return FilterChip(
                          label: Text(category),
                          selected: selected,
                          onSelected: (value) {
                            setState(() {
                              _selectedCategory = value ? category : 'All';
                            });
                          },
                          selectedColor: AppColors.primary.withOpacity(0.2),
                          backgroundColor: AppColors.white,
                          labelStyle: TextStyle(
                            color: selected ? AppColors.primary : AppColors.darkText,
                            fontWeight: FontWeight.w600,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: selected ? AppColors.primary : AppColors.lightGray,
                              width: 1,
                            ),
                          ),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemCount: categories.length,
                    ),
                  ),
                ),
              ],
            ),
          ),
          filteredItems.isEmpty
              ? const SliverFillRemaining(
                  child: Center(child: Text("No meals found")),
                )
              : SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final meal = filteredItems[index];
                        return MealCard(meal: meal);
                      },
                      childCount: filteredItems.length,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 0.72,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                  ),
                ),
        ],
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

class MealCard extends StatelessWidget {
  final Map<String, dynamic> meal;

  const MealCard({super.key, required this.meal});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MealDetailScreen(meal: meal),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(meal['image'], fit: BoxFit.cover),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meal['title'],
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text("Ksh ${meal['price'].toString()}",
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}