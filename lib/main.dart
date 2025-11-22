// lib/main.dart
// ignore_for_file: unused_import

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ADDED: For orientation lock
import 'package:flutter/foundation.dart'; // ADDED: For kReleaseMode
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // ADDED: Environment variables

// ADDED: All necessary screen imports
import 'screens/auth_wrapper.dart'; // ADDED: For session persistence
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/rider/rider_dashboard_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/order_history_screen.dart'; // ADDED

// ADDED: All necessary service and provider imports
import 'services/auth_service.dart';
import 'services/notification_service.dart'; // ADDED: Import NotificationService
import 'providers/cart_provider.dart';
import 'providers/menu_provider.dart'; // ADDED: Inventory provider import
import 'providers/order_provider.dart';
import 'providers/rider_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/reviews_provider.dart'; // ADDED
import 'providers/favorites_provider.dart'; // ADDED: Import
import 'providers/location_provider.dart'; // ADDED: Import LocationProvider
import 'providers/address_provider.dart'; // ADDED: Import AddressProvider for UserAddresses table
import 'providers/location_management_provider.dart'; // ADDED: Import LocationManagementProvider
import 'providers/connectivity_provider.dart'; // ADDED: Import ConnectivityProvider
import 'providers/store_provider.dart'; // ADDED: Import StoreProvider
import 'providers/inventory_provider.dart'; // ADDED: Import InventoryProvider
import 'providers/mpesa_provider.dart'; // ADDED: Import MpesaProvider
import 'providers/receipt_provider.dart'; // ADDED: Import ReceiptProvider
import 'models/notification_model.dart';
import 'models/cart_item.dart'; // ADDED
import 'models/order.dart'; // ADDED for DeliveryType

import 'constants/colors.dart';

// ADDED: Test function to verify Supabase connection
Future<void> testSupabaseConnection() async {
  try {
    debugPrint('🧪 Testing Supabase connection...');
    debugPrint('📍 Attempting to connect to: ${dotenv.env['SUPABASE_URL']}');
    
    final supabase = Supabase.instance.client;
    
    debugPrint('✅ Supabase client is initialized');
    debugPrint('🔗 Environment: ${kReleaseMode ? 'PRODUCTION' : 'DEVELOPMENT'}');
    
    // ADDED: Test if the server is reachable
    try {
      final response = await supabase
          .from('menu_items')
          .select('*')
          .limit(3)
          .timeout(const Duration(seconds: 5)); // Add timeout
      
      debugPrint('✅ Query successful');
      debugPrint('📊 Fetched ${response.length} items');
      
      if (response.isNotEmpty) {
        debugPrint('📋 First item: ${response.first}');
      } else {
        debugPrint('⚠️ No items found in database');
      }
    } on TimeoutException {
      debugPrint('❌ Connection timeout - Supabase server is not responding');
      debugPrint('💡 Make sure Supabase is running: supabase start');
    }
  } catch (e, stackTrace) {
    debugPrint('❌ Supabase test failed: $e');
    debugPrint('Stack: $stackTrace');
    debugPrint('');
    debugPrint('🔧 Troubleshooting steps:');
    debugPrint('1. Check if Supabase is running: supabase status');
    debugPrint('2. If not running, start it: supabase start');
    debugPrint('3. Verify the URL in .env.dev matches `supabase status` output');
    debugPrint('4. Try using "localhost" instead of "127.0.0.1"');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock app to portrait mode only (standard for food delivery apps)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // TEMPORARY: Use production while debugging local network issues
  debugPrint('🔧 Using PRODUCTION Supabase (network debugging)');
  
  const supabaseUrl = 'https://hqfixpqwxmwftvhgdrxn.supabase.co';
  const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhxZml4cHF3eG13ZnR2aGdkcnhuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE2Mzc4NTksImV4cCI6MjA3NzIxMzg1OX0.Mjgws9SddAbTYmZotPNRKf-Yz3DmzkzJRxdstXBx6Zs';  // FIXED: corrected "role"

  debugPrint('📍 Supabase URL: $supabaseUrl');
  debugPrint('🔑 Anon Key: ${supabaseAnonKey.substring(0, 30)}...');
  debugPrint('📱 Platform: ${defaultTargetPlatform.name}');

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  debugPrint('🔧 Supabase initialized with: PRODUCTION');

  // Test connection after initialization
  await testSupabaseConnection();
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // REMOVED: Can't access providers here - moved to _AppContent
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle (prevent crashes when backgrounded)
    super.didChangeAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()), // ADDED: Global connectivity monitoring
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => NotificationService()), // ADDED: Notification preferences service
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => MenuProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()), // ADDED: Register LocationProvider
        ChangeNotifierProvider(create: (_) => AddressProvider()), // ADDED: Address provider for UserAddresses table
        ChangeNotifierProvider(create: (_) => LocationManagementProvider()), // ADDED: Location management provider
        ChangeNotifierProvider(create: (_) => InventoryProvider(Supabase.instance.client)), // ADDED: Inventory provider for admin inventory management
        ChangeNotifierProvider(create: (_) => MpesaProvider()), // ADDED: M-Pesa payment provider
        ChangeNotifierProvider(create: (_) => ReceiptProvider()), // ADDED: Receipt provider for realtime receipt updates
        ChangeNotifierProxyProvider<NotificationProvider, OrderProvider>(
          create: (context) => OrderProvider(),
          update: (context, notifProvider, orderProvider) {
            orderProvider?.setNotificationProvider(notifProvider);
            return orderProvider ?? OrderProvider();
          },
        ),
        ChangeNotifierProvider(create: (_) => RiderProvider()),
        ChangeNotifierProvider(create: (_) => ReviewsProvider()), // ADDED
        ChangeNotifierProvider(create: (_) => FavoritesProvider()), // ADDED: This line
        ChangeNotifierProvider(create: (context) => StoreProvider(Supabase.instance.client)), // ADDED: StoreProvider
      ],
      child: const _AppContent(), // FIXED: Move MaterialApp to separate widget
    );
  }
}

// ADDED: Separate widget to access providers
class _AppContent extends StatefulWidget {
  const _AppContent();

  @override
  State<_AppContent> createState() => _AppContentState();
}

class _AppContentState extends State<_AppContent> {
  @override
  void initState() {
    super.initState();
    
    // FIXED: Now we can access providers because we're inside MultiProvider
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        // Initialize notification preferences service
        final notificationService = Provider.of<NotificationService>(context, listen: false);
        await notificationService.init();
        
        final menuProvider = Provider.of<MenuProvider>(context, listen: false);
        await menuProvider.loadMenuItems();
        
        // Load reviews for all users (needed for meal detail screens)
        final reviewsProvider = Provider.of<ReviewsProvider>(context, listen: false);
        await reviewsProvider.loadReviews();
        
        // NOTE: Favorites will load per-user after login
        // NOTE: Orders will load per-user after login based on role
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Ouma's Delicacy",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          primaryColor: AppColors.primary,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            primary: AppColors.primary,
          ),
          useMaterial3: true,
        ),
        // FIXED: Use AuthWrapper as home to check for saved session
        home: const AuthWrapper(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomeScreen(),
          '/rider': (context) => const RiderDashboardScreen(),
          '/admin': (context) => const AdminDashboardScreen(),
          '/order-history': (context) {
            // Get current user ID from auth service
            final userId = Supabase.instance.client.auth.currentUser?.id;
            return OrderHistoryScreen(customerId: userId);
          },
        },
        onUnknownRoute: (settings) {
          return MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: const Text('Error'),
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red.withOpacity(0.5)),
                    const SizedBox(height: 16),
                    const Text(
                      'Route not found',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No route defined for ${settings.name}',
                      style: TextStyle(color: AppColors.darkText.withOpacity(0.6)),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                      ),
                      child: const Text('Go to Login'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
  }
}
