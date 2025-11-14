import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/colors.dart';
import '../services/auth_service.dart' as app;
import '../providers/favorites_provider.dart';
import '../providers/reviews_provider.dart';
import '../providers/order_provider.dart';
import '../providers/cart_provider.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'rider/rider_dashboard_screen.dart';
import '../widgets/bike_animation.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  StreamSubscription<AuthState>? _authSubscription;
  bool _isInitializing = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  /// Initialize authentication state and listen for changes
  /// This handles both initial session loading and subsequent auth events
  Future<void> _initializeAuth() async {
    final auth = context.read<app.AuthService>();
    
    // Start timer to ensure minimum 3 seconds display
    final startTime = DateTime.now();
    
    // Check for existing session from secure storage (automatic with Supabase)
    final session = Supabase.instance.client.auth.currentSession;
    
    debugPrint('🔍 AuthWrapper._initializeAuth() called');
    debugPrint('📦 Current session: ${session != null ? "EXISTS" : "NULL"}');
    if (session != null) {
      debugPrint('👤 Session user ID: ${session.user.id}');
      debugPrint('📧 Session user email: ${session.user.email}');
      debugPrint('⏰ Session expires at: ${session.expiresAt}');
    }
    
    if (session != null) {
      debugPrint('🔐 AuthWrapper: Found existing session, refreshing profile...');
      // Session exists, load user profile into AuthService
      await auth.refreshProfile();
      
      debugPrint('👤 After refresh - currentUser: ${auth.currentUser?.name ?? "NULL"}');
      debugPrint('🎭 After refresh - role: ${auth.currentUser?.role ?? "NULL"}');
      
      // Load user-specific data after successful authentication
      if (auth.currentUser != null && mounted) {
        debugPrint('📊 Loading user-specific data...');
        final userId = auth.currentUser!.id;
        
        // Load favorites
        final favoritesProvider = context.read<FavoritesProvider>();
        await favoritesProvider.loadFavorites(userId);
        debugPrint('✅ Loaded ${favoritesProvider.allFavorites.length} favorites');
        
        // Load reviews
        final reviewsProvider = context.read<ReviewsProvider>();
        await reviewsProvider.loadReviews();
        debugPrint('✅ Loaded reviews');
        
        // Load orders (role-based)
        final orderProvider = context.read<OrderProvider>();
        if (auth.currentUser!.role == 'admin') {
          await orderProvider.loadAllOrders();
          debugPrint('✅ Loaded all orders (admin)');
        } else {
          // For both riders and customers
          await orderProvider.loadOrders(userId);
          debugPrint('✅ Loaded orders for user');
        }
        
        // Cart loads automatically from SharedPreferences on first access
        final cartProvider = context.read<CartProvider>();
        debugPrint('✅ Cart ready with ${cartProvider.totalQuantity} items');
      }
      
      // Ensure minimum 3 seconds display time
      final elapsed = DateTime.now().difference(startTime);
      final remaining = const Duration(seconds: 3) - elapsed;
      if (remaining > Duration.zero) {
        await Future.delayed(remaining);
      }
      
      if (mounted) {
        setState(() {
          _isAuthenticated = auth.currentUser != null;
          _isInitializing = false;
        });
        debugPrint('✅ Set _isAuthenticated: $_isAuthenticated');
      }
    } else {
      debugPrint('🔓 AuthWrapper: No existing session found.');
      
      // Ensure minimum 3 seconds display time even when no session
      final elapsed = DateTime.now().difference(startTime);
      final remaining = const Duration(seconds: 3) - elapsed;
      if (remaining > Duration.zero) {
        await Future.delayed(remaining);
      }
      
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
          _isInitializing = false;
        });
      }
    }

    // Listen to auth state changes for automatic session refresh
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      debugPrint('🔔 AuthWrapper: Auth state changed - ${data.event}');
      
      if (data.event == AuthChangeEvent.signedIn) {
        // User signed in (either manually or auto-restored from token)
        await auth.refreshProfile();
        if (mounted) {
          setState(() {
            _isAuthenticated = auth.currentUser != null;
          });
        }
      } else if (data.event == AuthChangeEvent.signedOut) {
        // User signed out
        if (mounted) {
          setState(() {
            _isAuthenticated = false;
          });
        }
      } else if (data.event == AuthChangeEvent.tokenRefreshed) {
        // Token was automatically refreshed (background persistence)
        debugPrint('✅ AuthWrapper: Session token refreshed automatically.');
        await auth.refreshProfile();
        if (mounted) {
          setState(() {
            _isAuthenticated = auth.currentUser != null;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch the AuthService for any provider-level changes
    final auth = context.watch<app.AuthService>();

    // 1. BRANDED LOADING STATE: Show while initializing or checking session
    if (_isInitializing || auth.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Image(
                image: AssetImage('assets/images/splash_logo.png'),
                width: 150,
                height: 150,
              ),
              const SizedBox(height: 30),
              
              const SizedBox(
                height: 100,
                width: double.infinity,
                child: BikeAnimation(size: 80), 
              ),
              const SizedBox(height: 30),

              const CircularProgressIndicator(color: AppColors.primary),
            ],
          ),
        ),
      );
    }
    
    // 2. UNAUTHENTICATED STATE: No user found or session expired
    if (!_isAuthenticated || auth.currentUser == null) {
      debugPrint('🔓 AuthWrapper: No authenticated user, showing LoginScreen.');
      return const LoginScreen();
    }
    
    // 3. AUTHENTICATED STATE: User found, route based on role
    final userRole = auth.currentUser!.role;
    final userName = auth.currentUser!.name;
    debugPrint('✅ AuthWrapper: Authenticated user "$userName" with role: $userRole');

    switch (userRole) {
      case 'admin':
        return const AdminDashboardScreen();
      case 'rider':
        return const RiderDashboardScreen();
      default:
        // Default to customer home screen
        return const HomeScreen();
    }
  }
}