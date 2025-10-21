// login_screen.dart
import 'package:flutter/material.dart';
import 'package:sign_in_button/sign_in_button.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart'; // add near other imports
import '../constants/colors.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'rider/rider_dashboard_screen.dart';
import '../widgets/bike_animation.dart'; // Import the bike animation

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
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _slideController.dispose();
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

      final isAdmin = Provider.of<AuthService>(context, listen: false).isAdmin;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              isAdmin ? const AdminDashboardScreen() : const HomeScreen(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
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
                // App Logo
                Image.asset(
                  "assets/images/app_icon.png",
                  height: 120,
                ),
                const SizedBox(height: 20),

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
                    filled: true,
                    fillColor: AppColors.cardBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 24),
                
                // Customer Login button
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
                            'Login as Customer',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Rider Login button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RiderDashboardScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.delivery_dining, size: 20),
                    label: const Text(
                      'Login as Rider',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      side: BorderSide(color: AppColors.accent, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),

                // Forgot password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      // TODO: Implement forgot password logic
                    },
                    child: const Text(
                      "Forgot Password?",
                      style: TextStyle(color: AppColors.primary),
                    ),
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
                        // TODO: Facebook login
                      },
                    ),
                    const SizedBox(height: 10),
                    SignInButton(
                      Buttons.google,
                      onPressed: () {
                        // TODO: Google login
                      },
                    ),
                    const SizedBox(height: 10),
                    SignInButton(
                      Buttons.apple,
                      onPressed: () {
                        // TODO: Apple login
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // Demo admin login
                TextButton(
                  onPressed: kDebugMode
                      ? () async {
                          // set demo credentials and trigger the login flow (debug only)
                          _emailController.text = 'admin@example.com';
                          _passwordController.text = 'admin123';

                          // call the same login function you already use
                          await _login();
                        }
                      : null, // disabled in release builds
                  child: Text(
                    'Use admin credentials (demo)',
                    style: TextStyle(color: AppColors.lightGray),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}