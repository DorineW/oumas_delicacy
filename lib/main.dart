// lib/main.dart
// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import './constants/colors.dart';
import './providers/cart_provider.dart';
import './providers/menu_provider.dart';
import './services/auth_service.dart';
import './screens/login_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => MenuProvider()),
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: "Ouma's Kitchen",
        theme: ThemeData(
          primaryColor: AppColors.primary,
          colorScheme: ColorScheme.fromSwatch().copyWith(
            primary: AppColors.primary,
            secondary: AppColors.accent,
          ),
          scaffoldBackgroundColor: AppColors.background,
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.white,
            foregroundColor: AppColors.darkText,
            elevation: 2,
            iconTheme: IconThemeData(color: AppColors.darkText),
          ),
        ),
        home: const LoginWrapper(),
      ),
    );
  }
}

/// Decides whether to show Login or your external navigator
class LoginWrapper extends StatelessWidget {
  const LoginWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    // If logged in -> go to your navigation screen (defined elsewhere)
    return auth.currentUser != null
        ? const Placeholder() 
        : const LoginScreen();
  }
}
