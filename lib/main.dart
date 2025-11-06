// lib/main.dart
// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ADDED: All necessary screen imports
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/order_confirmation_screen.dart';
import 'screens/rider/rider_dashboard_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/order_history_screen.dart'; // ADDED

// ADDED: All necessary service and provider imports
import 'services/auth_service.dart';
import 'providers/cart_provider.dart';
import 'providers/menu_provider.dart';
import 'providers/order_provider.dart';
import 'providers/rider_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/reviews_provider.dart'; // ADDED
import 'providers/favorites_provider.dart'; // ADDED: Import
import 'providers/location_provider.dart'; // ADDED: Import LocationProvider
import 'models/notification_model.dart';
import 'models/cart_item.dart'; // ADDED
import 'models/order.dart'; // ADDED for DeliveryType

import 'constants/colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://hqfixpqwxmwftvhgdrxn.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhxZml4cHF3eG13ZnR2aGdkcnhuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE2Mzc4NTksImV4cCI6MjA3NzIxMzg1OX0.Mjgws9SddAbTYmZotPNRKf-Yz3DmzkzJRxdstXBx6Zs',
    // removed: authCallbackUrl (not supported in supabase_flutter v2)
    // authFlowType: AuthFlowType.pkce, // optional
  );

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
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => MenuProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()), // ADDED: Register LocationProvider
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
      ],
      child: MaterialApp(
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
        initialRoute: '/login',
        routes: {
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomeScreen(),
          '/rider': (context) => const RiderDashboardScreen(),
          '/admin': (context) => const AdminDashboardScreen(),
          '/order-history': (context) => const OrderHistoryScreen(), // ADDED
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/confirmation') {
            final args = settings.arguments as Map<String, dynamic>;
            
            return MaterialPageRoute(
              builder: (context) => OrderConfirmationScreen(
                orderItems: args['items'] as List<CartItem>,
                deliveryType: args['deliveryType'] as DeliveryType,
                totalAmount: args['totalAmount'] as int,
                customerId: args['customerId'] as String,
                customerName: args['customerName'] as String,
                deliveryAddress: args['deliveryAddress'] as String?,
                specialInstructions: args['phoneNumber'] as String?,
              ),
            );
          }
          
          return null;
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
                    Text(
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
      ),
    );
  }
}
