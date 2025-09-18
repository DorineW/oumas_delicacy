// lib/screens/auth_wrapper.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);

    if (auth.currentUser == null) {
      // Not logged in → go to login screen
      return const LoginScreen();
    } else {
      // Logged in → go to landing page (HomeScreen)
      return const HomeScreen();
    }
  }
}
