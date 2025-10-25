// lib/main.dart
// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
// If you ran `flutterfire configure`, this file will exist:
import 'firebase_options.dart' show DefaultFirebaseOptions;

// ADDED: All necessary screen imports
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/order_confirmation_screen.dart';
import 'screens/rider/rider_dashboard_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';

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

  // TEMP: show exception text in UI during debugging (remove in production)
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Scaffold(
      appBar: AppBar(title: const Text('Build error')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(details.exceptionAsString(), style: const TextStyle(color: Colors.red)),
      ),
    );
  };

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    await Firebase.initializeApp();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
