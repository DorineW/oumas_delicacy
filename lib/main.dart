// lib/main.dart
// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'providers/cart_provider.dart';
import 'providers/menu_provider.dart';
import 'constants/colors.dart';

void main() {
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
        // add other providers HomeScreen/AdminDashboard need
      ],
      child: MaterialApp(
        title: "Ouma's Delicacy",
        theme: ThemeData(primaryColor: AppColors.primary),
        home: const LoginScreen(),
      ),
    );
  }
}
