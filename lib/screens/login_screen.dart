// login_screen.dart
// ignore_for_file: unused_import

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
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
  bool _deepLinkProcessed = false; // ADDED: Prevent re-processing the same token

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

  // ADDED: Demo continue helper
  Future<void> _continueAs(String role) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    await auth.demoLogin(role: role);
    if (!mounted) return;
    Widget next;
    if (role == 'admin') {
      next = const AdminDashboardScreen();
    } else if (role == 'rider') {
      next = const RiderDashboardScreen();
    } else {
      next = const HomeScreen();
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => next));
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
                          'After creating an account, open the verification link sent to your email. The app will sign you in automatically.',
                          style: TextStyle(
                            color: AppColors.darkText.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ADDED: Demo shortcuts (no credentials required)
                if (AuthService.demoMode) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withOpacity(0.25)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.play_circle_fill, color: Colors.green),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Demo mode is ON. Continue without signing in:',
                            style: TextStyle(
                              color: AppColors.darkText.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : () => _continueAs('customer'),
                          child: const Text('Continue as Customer'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : () => _continueAs('rider'),
                          child: const Text('Continue as Rider'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : () => _continueAs('admin'),
                          child: const Text('Continue as Admin'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                ],
              ),
            ),
          ),
        ),
      );
    }
  }