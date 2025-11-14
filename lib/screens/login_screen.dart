// login_screen.dart
// ignore_for_file: unused_import

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/colors.dart';
import '../services/auth_service.dart';
import '../providers/favorites_provider.dart'; // ADDED: Import FavoritesProvider
import '../providers/reviews_provider.dart'; // ADDED: Import ReviewsProvider
import '../providers/order_provider.dart'; // ADDED: Import OrderProvider
import 'home_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'rider/rider_dashboard_screen.dart';
import '../widgets/bike_animation.dart'; // Import the bike animation
import 'register_screen.dart'; // ADDED: Import register screen
import 'forgot_password_screen.dart'; // ADDED

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ADDED: Form key
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true; // ADDED: Track password visibility

  // ADDED: OAuth auth state listener subscription
  StreamSubscription? _oauthListener;
  bool _deepLinkProcessed = false; // ADDED: Prevent re-processing the same token

  @override
  void initState() {
    super.initState();

    // ADDED: Handle deep links when app is opened from email confirmation
    _oauthListener = Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      if (data.event == AuthChangeEvent.signedIn && !_deepLinkProcessed) {
        _deepLinkProcessed = true;
        if (!mounted) return;
        
        // ADDED: Refresh profile before navigating
        final auth = Provider.of<AuthService>(context, listen: false);
        await Future.delayed(const Duration(milliseconds: 800)); // let trigger finish
        await auth.getCurrentProfile(); // force refresh from DB
        
        if (!mounted) return;
        
        // FIXED: Route based on user role instead of always going to /home
        final user = auth.currentUser;
        if (user?.role == 'admin') {
          Navigator.of(context).pushReplacementNamed('/admin');
        } else if (user?.role == 'rider') {
          Navigator.of(context).pushReplacementNamed('/rider');
        } else {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _oauthListener?.cancel(); // ADDED
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    // FIXED: Prevent auth listener from interfering with manual login navigation
    _deepLinkProcessed = true;

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final error = await auth.login(_emailController.text.trim(), _passwordController.text);

      if (error != null) {
        if (!mounted) return;
        _showErrorDialog(error);
        setState(() => _isLoading = false);
        return;
      }

      // ADDED: Wait for user profile to load completely
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!mounted) return;

      // FIXED: Get fresh user data after login
      final user = auth.currentUser;
      debugPrint('👤 Logged in user: ${user?.email} with role: ${user?.role}');

      if (!mounted) return;

      // ADDED: Load user-specific data after login
      final favoritesProvider = Provider.of<FavoritesProvider>(context, listen: false);
      final reviewsProvider = Provider.of<ReviewsProvider>(context, listen: false);
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);

      if (user?.id != null) {
        // Load favorites for all users
        favoritesProvider.setCurrentUser(user!.id);
        
        // Load reviews for all users
        await reviewsProvider.loadReviews();
        
        // Load orders based on role
        if (user.role == 'admin') {
          debugPrint('📦 Loading all orders for admin');
          await orderProvider.loadAllOrders();
        } else if (user.role != 'rider') {
          // Load customer orders (not for riders - they load separately)
          debugPrint('📦 Loading orders for customer: ${user.id}');
          await orderProvider.loadOrders(user.id);
        }
      }

      // ADDED: Small delay after data loading before routing to ensure UI state is ready
      await Future.delayed(const Duration(milliseconds: 100));

      if (!mounted) return;

      // Route based on role
      if (user?.role == 'admin') {
        debugPrint('🔀 Routing to: /admin');
        Navigator.of(context).pushReplacementNamed('/admin');
      } else if (user?.role == 'rider') {
        debugPrint('🔀 Routing to: /rider');
        Navigator.of(context).pushReplacementNamed('/rider');
      } else {
        debugPrint('🔀 Routing to: /home');
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      debugPrint('❌ Login error: $e');
      if (!mounted) return;
      
      // Parse the error for a user-friendly message
      String errorMessage = 'An unexpected error occurred. Please try again.';
      if (e.toString().contains('SocketException') || e.toString().contains('NetworkException')) {
        errorMessage = 'Network connection error. Please check your internet and try again.';
      } else if (e.toString().contains('TimeoutException')) {
        errorMessage = 'Connection timed out. Please try again.';
      } else if (e.toString().contains('FormatException')) {
        errorMessage = 'Invalid response from server. Please try again later.';
      }
      
      _showErrorDialog(errorMessage);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorDialog(String message) {
    // Parse and format the error message for better UX
    String title = 'Login Failed';
    String formattedMessage = message;
    IconData icon = Icons.error_outline;
    Color iconColor = Colors.red;

    // Handle common error cases
    if (message.toLowerCase().contains('invalid login credentials') || 
        message.toLowerCase().contains('invalid email or password')) {
      title = 'Incorrect Credentials';
      formattedMessage = 'The email or password you entered is incorrect. Please check and try again.';
      icon = Icons.lock_outline;
    } else if (message.toLowerCase().contains('email not confirmed')) {
      title = 'Email Not Verified';
      formattedMessage = 'Please verify your email address. Check your inbox for the verification link.';
      icon = Icons.mail_outline;
      iconColor = Colors.orange;
    } else if (message.toLowerCase().contains('network') || 
               message.toLowerCase().contains('connection')) {
      title = 'Connection Error';
      formattedMessage = 'Unable to connect to the server. Please check your internet connection and try again.';
      icon = Icons.wifi_off;
    } else if (message.toLowerCase().contains('too many requests')) {
      title = 'Too Many Attempts';
      formattedMessage = 'Too many login attempts. Please wait a few minutes and try again.';
      icon = Icons.timer_outlined;
      iconColor = Colors.orange;
    } else if (message.toLowerCase().contains('user not found')) {
      title = 'Account Not Found';
      formattedMessage = 'No account found with this email. Please check the email or sign up.';
      icon = Icons.person_outline;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          formattedMessage,
          style: const TextStyle(fontSize: 15, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey, // ADDED: Wrap body with Form
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo at the top
                  Image.asset(
                    'assets/images/splash_logo.png',
                    width: 120,
                    height: 120,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.restaurant,
                        size: 120,
                        color: AppColors.primary,
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Bike animation
                  const SizedBox(
                    height: 100,
                    child: BikeAnimation(size: 80),
                  ),
                  const SizedBox(height: 30),

                  // Email field
                  TextFormField(
                    controller: _emailController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      // Basic email check
                      if (!value.contains('@') || !value.contains('.')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                    autofillHints: const [AutofillHints.email],
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email),
                      filled: true,
                      fillColor: AppColors.cardBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  
                  // UPDATED: Password field with visibility toggle
                  TextFormField(
                    controller: _passwordController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleLogin(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: AppColors.darkText.withOpacity(0.6),
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                      ),
                      filled: true,
                      fillColor: AppColors.cardBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    obscureText: _obscurePassword, // UPDATED: Use dynamic state
                  ),
                  const SizedBox(height: 24),
                  
                  // Login button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: AppColors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Login',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ADDED: Register button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Create Account',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),

                  // UPDATED: Forgot password - now navigates to forgot password screen
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ForgotPasswordScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        "Forgot Password?",
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ),
                  ),
                ],
                ),
              ),
            ),
          ),
        ),
      );
    }
  }