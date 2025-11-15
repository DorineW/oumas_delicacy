import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/colors.dart';
import '../services/auth_service.dart' as app;
import '../providers/favorites_provider.dart';
import '../providers/reviews_provider.dart';
import '../providers/order_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/connectivity_provider.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'rider/rider_dashboard_screen.dart';
import '../widgets/bike_animation.dart';
import '../widgets/no_connection_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  StreamSubscription<AuthState>? _authSubscription;
  bool _isInitializing = true;
  bool _isAuthenticated = false;
  String? _initError; // Track initialization errors
  bool _hasSeenOnboarding = false; // Track onboarding status
  bool _checkingOnboarding = true; // Track onboarding check

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

  /// Check if user has seen onboarding before
  Future<bool> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('has_seen_onboarding') ?? false;
  }

  /// Mark onboarding as completed
  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    
    if (mounted) {
      setState(() {
        _hasSeenOnboarding = true;
      });
      
      // Now proceed to auth check
      _initializeAuth();
    }
  }

  /// Helper function for clearer order loading logic
  Future<void> _loadOrdersForUser(app.AuthService auth, OrderProvider orderProvider, String userId) async {
    if (auth.currentUser!.role == 'admin') {
      await orderProvider.loadAllOrders();
      debugPrint('✅ Loaded all orders (admin)');
    } else {
      await orderProvider.loadOrders(userId);
      debugPrint('✅ Loaded orders for user');
    }
  }

  /// Initialize authentication state and listen for changes
  /// Quick check with background data loading
  Future<void> _initializeAuth() async {
    // Check onboarding status first
    final hasSeenOnboarding = await _checkOnboardingStatus();
    
    final auth = context.read<app.AuthService>();
    final session = Supabase.instance.client.auth.currentSession;
    
    // --- STEP 1: Quick Authentication Check ---
    if (session != null) {
      debugPrint('🔐 AuthWrapper: Found existing session, loading cached profile first...');
      
      // CRITICAL: Load cached profile immediately for instant display
      try {
        await auth.refreshProfile().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('⚠️ Profile refresh timed out, using cached data');
          },
        );
      } catch (e) {
        debugPrint('⚠️ Profile refresh failed (continuing anyway): $e');
        // Cached data should already be loaded by refreshProfile
      }
      
      // Always proceed to home screen if session exists
      // Even if profile refresh failed, user might have cached data
      if (mounted) {
        setState(() {
          // Session is non-null in this branch, so user is authenticated
          _isAuthenticated = true;
          _hasSeenOnboarding = hasSeenOnboarding;
          _checkingOnboarding = false;
          _isInitializing = false;
        });
        
        if (auth.currentUser != null) {
          debugPrint('✅ Authentication complete with profile: ${auth.currentUser?.name}, loading data in background...');
          _loadDataInBackground(auth.currentUser!.id, auth);
        } else {
          debugPrint('⚠️ Session exists but no profile loaded - proceeding with session user');
          // Try to load data with session user ID as fallback
          _loadDataInBackground(session.user.id, auth);
        }
      }
    } else {
      // No session - show login screen
      debugPrint('🔓 AuthWrapper: No existing session found.');
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
          _checkingOnboarding = false;
          _isInitializing = false;
        });
      }
    }

    // --- STEP 2: Start Listening for Auth Changes (Background) ---
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) async {
        debugPrint('🔔 AuthWrapper: Auth state changed - ${data.event}');
        
        if (data.event == AuthChangeEvent.signedIn || data.event == AuthChangeEvent.tokenRefreshed) {
          // Defensive profile refresh - don't crash if it fails
          try {
            await auth.refreshProfile();
          } catch (e) {
            debugPrint('⚠️ Profile refresh failed in auth listener: $e');
          }
          
          if (mounted) {
            setState(() {
              _isAuthenticated = auth.currentUser != null || data.session?.user != null;
            });
          }
        } else if (data.event == AuthChangeEvent.signedOut) {
          if (mounted) {
            setState(() {
              _isAuthenticated = false;
            });
          }
        }
      },
      onError: (error) {
        // Suppress background auth errors (token refresh failures when offline)
        debugPrint('⚠️ Auth stream error (suppressed): $error');
      },
    );
  }

  /// Load user data in background after navigation
  void _loadDataInBackground(String userId, app.AuthService auth) {
    // Load favorites
    context.read<FavoritesProvider>().loadFavorites(userId).timeout(
      const Duration(seconds: 5),
    ).catchError((e) {
      debugPrint('⚠️ Failed to load favorites: $e');
    });
    
    // Load reviews
    context.read<ReviewsProvider>().loadReviews().timeout(
      const Duration(seconds: 5),
    ).catchError((e) {
      debugPrint('⚠️ Failed to load reviews: $e');
    });
    
    // Load orders
    _loadOrdersForUser(auth, context.read<OrderProvider>(), userId).timeout(
      const Duration(seconds: 8),
    ).then((_) {
      debugPrint('✅ Background data loading complete');
      context.read<CartProvider>(); // Ensures Cart is ready
    }).catchError((e) {
      debugPrint('⚠️ Failed to load orders: $e');
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch the AuthService for any provider-level changes
    final auth = context.watch<app.AuthService>();
    final connectivity = context.watch<ConnectivityProvider>();

    // 0. CONNECTIVITY CHECK: Show no connection screen if offline
    if (!connectivity.isConnected) {
      return NoConnectionScreen(
        onRetry: () => connectivity.retry(),
        customMessage:
            "You're offline. Please check your internet connection to continue.",
      );
    }

    // 1. BRANDED LOADING STATE: Show while initializing or checking session
    if (_isInitializing || auth.isLoading || _checkingOnboarding) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Enhanced UI sizes from previous step
              const Image(
                image: AssetImage('assets/images/splash_logo.png'),
                width: 250,
                height: 250,
              ),
              const SizedBox(height: 50),
              
              const SizedBox(
                height: 150,
                width: double.infinity,
                child: BikeAnimation(size: 120),
              ),
              const SizedBox(height: 50),

              const CircularProgressIndicator(color: AppColors.primary),
              
              // Show initialization error if any (non-fatal)
              if (_initError != null) ...[
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    _initError!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
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
    
    // 3. ONBOARDING CHECK: Show onboarding if authenticated but haven't seen it yet
    if (!_hasSeenOnboarding) {
      return OnboardingPage(
        onFinish: _completeOnboarding,
      );
    }
    
    // 4. AUTHENTICATED STATE: User found and has seen onboarding, route based on role
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