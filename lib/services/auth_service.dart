// lib/services/auth_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ADDED
import '../models/user.dart' as app;

class AuthService extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  app.User? _currentUser;
  bool _isLoading = false;

  app.User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null || _supabase.auth.currentUser != null;
  bool get isAdmin => _currentUser?.role == 'admin';
  bool get isRider => _currentUser?.role == 'rider';
  bool get isLoading => _isLoading;

  // In-memory cooldown to reduce Supabase 429s (no persistence)
  static const Duration _rateLimitWindow = Duration(seconds: 60);
  final Map<String, DateTime> _lastRequest = {};

  Future<void> _enforceEmailRateLimit(String action, String email) async {
    final key = '${action}:${email.toLowerCase()}';
    final last = _lastRequest[key];
    if (last != null) {
      final elapsed = DateTime.now().difference(last);
      final remaining = _rateLimitWindow - elapsed;
      if (remaining > Duration.zero) {
        throw Exception('Please wait ${remaining.inSeconds}s before trying again.');
      }
    }
  }

  void _recordEmailRequest(String action, String email) {
    final key = '${action}:${email.toLowerCase()}';
    _lastRequest[key] = DateTime.now();
  }

  Future<void> _refreshCurrentUserFromProfile() async {
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) {
        _currentUser = null;
        notifyListeners();
        return;
      }

      final profile = await _supabase
          .from('users')
          .select()
          .eq('auth_id', authUser.id)
          .maybeSingle();

      if (profile != null) {
        _currentUser = app.User(
          id: authUser.id,
          email: (profile['email'] as String?) ?? (authUser.email ?? ''),
          name: (profile['name'] as String?) ?? '',
          role: (profile['role'] as String?) ?? 'customer', // ✅ Role is read here
          phone: profile['phone'] as String?,
        );
      } else {
        _currentUser = app.User(
          id: authUser.id,
          email: authUser.email ?? '',
          name: '',
          role: 'customer',
          phone: null,
        );
      }
      notifyListeners();
    } catch (_) {
      // silent
    }
  }

  /// Sign up with email/password and ensure a users row exists when session is active.
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? name,
    String? phone,
    String role = 'customer',
  }) async {
    await _enforceEmailRateLimit('signup', email);

    int attempt = 0;
    while (true) {
      try {
        final res = await _supabase.auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: oauthRedirectUri,
          // ADDED: Pass metadata so trigger can read it
          data: {
            'name': name ?? '',
            'phone': phone,
            'role': role,
          },
        );

        _recordEmailRequest('signup', email);

        final user = res.user;
        if (user != null && res.session != null) {
          await Future.delayed(const Duration(seconds: 1));
          await createProfileIfNotExists(
            authId: user.id,
            email: email,
            name: name ?? '',
            phone: phone,
            role: role,
          );
          await _refreshCurrentUserFromProfile();
          notifyListeners();
        }
        return res;
      } on AuthException catch (e) {
        final msg = e.message.toLowerCase();

        // Friendly message for Supabase rate limit
        if (e.statusCode == 429 ||
            msg.contains('over_email_send_rate_limit') ||
            msg.contains('for security purposes')) {
          throw Exception('Too many requests. Please wait ~60s and check your email for the confirmation link.');
        }

        // Retry on transient 500 errors from auth ("unexpected_failure", "database error saving new user")
        final isTransient = (e.statusCode == 500) ||
            msg.contains('unexpected_failure') ||
            msg.contains('database error saving new user');

        if (isTransient && attempt < 2) {
          attempt += 1;
          // exponential backoff: 400ms, 800ms
          await Future.delayed(Duration(milliseconds: 400 * (1 << (attempt - 1))));
          continue;
        }

        if (isTransient) {
          throw Exception('Temporary error creating account. Please try again in a moment.');
        }

        // Other auth errors
        rethrow;
      }
    }
  }

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final resp = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      await _refreshCurrentUserFromProfile();
      notifyListeners();
      return resp;
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      // ADDED: Friendly message for unconfirmed email
      if ((e.statusCode == 400) && (msg.contains('email not confirmed'))) {
        throw Exception('Email not confirmed. Please verify your email, then try logging in.');
      }
      rethrow;
    }
  }

  static const String oauthRedirectUri = 'com.oumasdelicacy.app://login-callback';

  Future<void> signInWithGoogle({String? redirectTo}) async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectTo ?? oauthRedirectUri,
      );
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (e.statusCode == 400 || msg.contains('provider is not enabled')) {
        throw Exception('Google sign-in is not enabled in Supabase. Enable the provider and add com.oumasdelicacy.app://login-callback to Redirect URLs.');
      }
      rethrow;
    }
  }

  Future<void> signInWithFacebook({String? redirectTo}) async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.facebook,
        redirectTo: redirectTo ?? oauthRedirectUri,
      );
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (e.statusCode == 400 || msg.contains('provider is not enabled')) {
        throw Exception('Facebook sign-in is not enabled in Supabase. Enable the provider and add com.oumasdelicacy.app://login-callback to Redirect URLs.');
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    // Clear cached profile data on logout
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('name');
    await prefs.remove('email');
    await prefs.remove('phone');
    await prefs.remove('addresses');
    await prefs.remove('defaultAddressIndex');
    await prefs.remove('paymentMethod');
    await prefs.remove('profileImagePath');
    
    // ADDED: Clear order history and cart
    await prefs.remove('orders'); // if you store orders locally
    await prefs.remove('cart_items');
    await prefs.remove('order_history');
    
    await _supabase.auth.signOut();
    _currentUser = null;
    notifyListeners();
  }

  // ADDED: Backwards-compatible alias used across screens
  Future<void> logout() => signOut();

  Future<void> createProfileIfNotExists({
    required String authId,
    required String email,
    required String name,
    String? phone,
    String role = 'customer',
  }) async {
    await _supabase.from('users').upsert({
      'auth_id': authId,
      'email': email,
      'name': name,
      'phone': phone,
      'role': role,
    }, onConflict: 'auth_id', ignoreDuplicates: true);
  }

  Future<Map<String, dynamic>?> getCurrentProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final resp = await _supabase
        .from('users')
        .select()
        .eq('auth_id', user.id)
        .maybeSingle();
    return resp;
  }

  Stream<AuthState> authStateChanges() {
    final controller = StreamController<AuthState>();
    final sub = _supabase.auth.onAuthStateChange.listen((data) async {
      final u = data.session?.user;
      if (u != null) {
        await createProfileIfNotExists(
          authId: u.id,
          email: u.email ?? '',
          name: '',
          phone: null,
          role: 'customer',
        );
        // ADDED: Wait for trigger to complete, then refresh
        await Future.delayed(const Duration(milliseconds: 500));
        await _refreshCurrentUserFromProfile();
      }
      controller.add(AuthState(event: data.event, session: data.session));
      // REMOVED: duplicate refresh here (already done above when u != null)
      notifyListeners();
    });
    controller.onCancel = () => sub.cancel();
    return controller.stream;
  }

  Future<String?> login(String email, String password) async {
    try {
      // FIXED: Use Supabase.instance.client instead of _client
      debugPrint('🔐 Attempting login for: $email');
      
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        debugPrint('✅ Login successful for: ${response.user!.email}');
        // FIXED: Load user profile after login
        final userId = response.user!.id;
        try {
          final userProfile = await Supabase.instance.client
              .from('users')
              .select()
              .eq('auth_id', userId)
              .single();
          
          // Store user data (implement your User model here)
          debugPrint('✅ User profile loaded: ${userProfile['name']}');
        } catch (e) {
          debugPrint('⚠️ Could not load user profile: $e');
        }
        
        notifyListeners();
        return null;
      }

      debugPrint('⚠️ Login returned null user');
      return 'Login failed: No user returned';
    } on AuthException catch (e) {
      debugPrint('❌ Auth error: ${e.message}');
      debugPrint('   Status: ${e.statusCode}');
      return 'Login failed: ${e.message}';
    } catch (e, stackTrace) {
      debugPrint('❌ Unexpected login error: $e');
      debugPrint('Stack: $stackTrace');
      return 'Login failed: $e';
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    await signUpWithEmail(
      email: email,
      password: password,
      name: name,
      phone: phone,
      role: 'customer',
    );
    await _refreshCurrentUserFromProfile();
    notifyListeners();
  }

  Future<void> resetPassword(String email, {String? redirectTo}) async {
    await _enforceEmailRateLimit('reset', email);
    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: redirectTo,
      );
      _recordEmailRequest('reset', email);
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (e.statusCode == 429 ||
          msg.contains('over_email_send_rate_limit') ||
          msg.contains('for security purposes')) {
        throw Exception('Too many requests. Please wait ~60s and check your inbox for the reset email.');
      }
      rethrow;
    }
  }

  Future<void> resendConfirmationEmail(String email) async {
    try {
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: email,
      );
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }
}

class AuthState {
  final AuthChangeEvent? event;
  final Session? session;
  AuthState({this.event, this.session});
}