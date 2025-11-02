// login_screen.dart
// ignore_for_file: unused_import

import 'dart:async'; // ADDED

import 'package:flutter/material.dart';
import 'package:sign_in_button/sign_in_button.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart'; // add near other imports
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/colors.dart';
import '../services/auth_service.dart';
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

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  // ADDED: OAuth auth state listener subscription
  StreamSubscription? _oauthListener;

  @override
  void initState() {
    super.initState();
    
    // Slogan animation
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-0.2, 0),
      end: const Offset(0.2, 0),
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));

    // ADDED: Handle deep links when app is opened from OAuth redirect
    _oauthListener = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/home');
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _slideController.dispose();
    _oauthListener?.cancel(); // ADDED
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);

    try {
      await Provider.of<AuthService>(context, listen: false).login(
        _emailController.text,
        _passwordController.text,
      );

      if (!mounted) return;

      // UPDATED: Check for admin, rider, or customer
      final auth = Provider.of<AuthService>(context, listen: false);
      final isAdmin = auth.isAdmin;
      final isRider = auth.isRider;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) {
            if (isAdmin) {
              return const AdminDashboardScreen();
            } else if (isRider) {
              return const RiderDashboardScreen();
            } else {
              return const HomeScreen();
            }
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      if (msg.contains('Email not confirmed')) {
        final shouldResend = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Email not confirmed'),
            content: Text(
              'We sent a verification link to ${_emailController.text.trim()}. Resend confirmation email?',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Resend')),
            ],
          ),
        );
        if (shouldResend == true) {
          try {
            await Provider.of<AuthService>(context, listen: false)
                .resendConfirmationEmail(_emailController.text.trim());
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Confirmation email resent. Check your inbox.')),
            );
          } catch (err) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to resend confirmation: $err')),
            );
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ADDED/UPDATED: OAuth handlers with consistent loading and error handling
  Future<void> _signInWithGoogle() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    try {
      setState(() => _isLoading = true);
      await auth.signInWithGoogle(
        redirectTo: 'com.oumasdelicacy.app://login-callback',
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint('Google login error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')), // CHANGED
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithFacebook() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    try {
      setState(() => _isLoading = true);
      await auth.signInWithFacebook(
        redirectTo: 'com.oumasdelicacy.app://login-callback',
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint('Facebook login error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')), // CHANGED
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo at the top
                Image.asset(
                  'assets/images/splash_logo.png',
                  width: 120,
                  height: 120,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.restaurant,
                      size: 120,
                      color: AppColors.primary,
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Sliding slogan
                SlideTransition(
                  position: _slideAnimation,
                  child: const Text(
                    "Make Meals Magical!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontStyle: FontStyle.italic,
                      color: AppColors.darkText,
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // Bike animation
                SizedBox(
                  height: 100,
                  child: BikeAnimation(size: 80),
                ),
                const SizedBox(height: 30),

                // Email field
                TextField(
                  controller: _emailController,
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
                
                // Password field
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    filled: true,
                    fillColor: AppColors.cardBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 24),
                
                // Login button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
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

                const SizedBox(height: 12),

                // ADDED: Email verification hint
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.25)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.mark_email_unread, color: Colors.blue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'New here? After creating an account, check your email for a verification link before logging in.',
                          style: TextStyle(
                            color: AppColors.darkText.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Divider with "or continue with"
                Row(
                  children: [
                    const Expanded(child: Divider(thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        "or continue with",
                        style: TextStyle(color: AppColors.lightGray),
                      ),
                    ),
                    const Expanded(child: Divider(thickness: 1)),
                  ],
                ),
                const SizedBox(height: 16),

                // Social login buttons (using sign_in_button)
                Column(
                  children: [
                    SignInButton(
                      Buttons.facebook,
                      onPressed: () {
                        if (_isLoading) return;
                        _signInWithFacebook();
                      }, // CHANGED
                    ),
                    const SizedBox(height: 10),
                    SignInButton(
                      Buttons.google,
                      onPressed: () {
                        if (_isLoading) return;
                        _signInWithGoogle();
                      }, // CHANGED
                    ),
                    const SizedBox(height: 10),
                    // REMOVED: Apple sign-in button
                    // SignInButton(
                    //   Buttons.apple,
                    //   onPressed: () {
                    //     // TODO: Apple login
                    //   },
                    // ),
                  ],
                ),

                const SizedBox(height: 30),

                // Demo admin login
                if (kDebugMode) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info, color: Colors.blue, size: 18),
                            const SizedBox(width: 8),
                            const Text(
                              'Demo Accounts (Testing Only)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _demoAccountButton(
                          'Rider',
                          'rider@example.com',
                          'rider123',
                          Icons.delivery_dining,
                          Colors.orange,
                        ),
                        const SizedBox(height: 8),
                        _demoAccountButton(
                          'Admin',
                          'admin@example.com',
                          'admin123',
                          Icons.admin_panel_settings,
                          Colors.red,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _demoAccountButton(
    String role,
    String email,
    String password,
    IconData icon,
    Color color,
  ) {
    return ElevatedButton.icon(
      onPressed: () async {
        // set demo credentials and trigger the login flow (debug only)
        _emailController.text = email;
        _passwordController.text = password;

        // call the same login function you already use
        await _login();
      },
      icon: Icon(icon, size: 20, color: Colors.white),
      label: Text(
        'Login as $role',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}