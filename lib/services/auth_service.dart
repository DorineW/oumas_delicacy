// lib/services/auth_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ADDED
import '../models/user.dart' as app;
import '../utils/phone_utils.dart';

class AuthService extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  app.User? _currentUser;
  final bool _isLoading = false;

  app.User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null || _supabase.auth.currentUser != null;
  bool get isAdmin => _currentUser?.role == 'admin';
  bool get isRider => _currentUser?.role == 'rider';
  bool get isLoading => _isLoading;

  // In-memory cooldown to reduce Supabase 429s (no persistence)
  static const Duration _rateLimitWindow = Duration(seconds: 60);
  final Map<String, DateTime> _lastRequest = {};

  Future<void> _enforceEmailRateLimit(String action, String email) async {
    final key = '$action:${email.toLowerCase()}';
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
    final key = '$action:${email.toLowerCase()}';
    _lastRequest[key] = DateTime.now();
  }

  // Cache keys for persistent profile storage
  static const String _cacheKeyUserId = 'cached_user_id';
  static const String _cacheKeyUserEmail = 'cached_user_email';
  static const String _cacheKeyUserName = 'cached_user_name';
  static const String _cacheKeyUserRole = 'cached_user_role';
  static const String _cacheKeyUserPhone = 'cached_user_phone';

  /// Load cached user profile from SharedPreferences
  Future<void> _loadUserFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedId = prefs.getString(_cacheKeyUserId);
      final cachedEmail = prefs.getString(_cacheKeyUserEmail);
      final cachedName = prefs.getString(_cacheKeyUserName);
      final cachedRole = prefs.getString(_cacheKeyUserRole);
      final cachedPhone = prefs.getString(_cacheKeyUserPhone);
      
      if (cachedId != null && cachedEmail != null) {
        _currentUser = app.User(
          id: cachedId,
          email: cachedEmail,
          name: cachedName,
          role: cachedRole ?? 'customer',
          phone: cachedPhone,
        );
        debugPrint('📦 Loaded user profile from cache: ${_currentUser?.name}');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error loading user cache: $e');
    }
  }

  /// Save user profile to SharedPreferences cache
  Future<void> _saveUserToCache(app.User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKeyUserId, user.id);
      await prefs.setString(_cacheKeyUserEmail, user.email);
      if (user.name != null) await prefs.setString(_cacheKeyUserName, user.name!);
      await prefs.setString(_cacheKeyUserRole, user.role);
      if (user.phone != null) await prefs.setString(_cacheKeyUserPhone, user.phone!);
      
      debugPrint('💾 Saved user profile to cache');
    } catch (e) {
      debugPrint('❌ Error saving user cache: $e');
    }
  }

  Future<void> _refreshCurrentUserFromProfile() async {
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) {
        debugPrint('⚠️ No auth user found, clearing current user');
        _currentUser = null;
        notifyListeners();
        return;
      }

      // Load from cache first if no current user
      if (_currentUser == null) {
        await _loadUserFromCache();
      }

      debugPrint('🔄 Refreshing user profile from Supabase...');
      debugPrint('🔑 User auth_id: ${authUser.id}');
      debugPrint('📧 User email: ${authUser.email}');
      
      Map<String, dynamic>? profile;
      try {
        profile = await _supabase
            .from('users')
            .select('auth_id, email, name, phone, role, addresses, default_address_index, created_at, updated_at')
            .eq('auth_id', authUser.id)
            .maybeSingle()
            .timeout(const Duration(seconds: 10));
        debugPrint('✅ Query executed successfully');
        debugPrint('📊 Response: $profile');
      } catch (e) {
        debugPrint('⚠️ Failed to fetch profile from database: $e');
        profile = null;
      }
      
      if (profile != null) {
        debugPrint('📋 Raw user profile from DB: $profile');
        
        _currentUser = app.User(
          id: authUser.id,
          email: (profile['email'] as String?) ?? (authUser.email ?? ''),
          name: (profile['name'] as String?) ?? '',
          role: (profile['role'] as String?) ?? 'customer',
          phone: profile['phone'] as String?,
        );
        
        // Save fresh profile to cache
        await _saveUserToCache(_currentUser!);
        
        debugPrint('✅ User profile refreshed: ${_currentUser?.name} (Role: ${_currentUser?.role})');
        debugPrint('🔑 Role checks:');
        debugPrint('   - Is Admin: ${_currentUser?.role == 'admin'}');
        debugPrint('   - Is Rider: ${_currentUser?.role == 'rider'}');
        debugPrint('   - Is Customer: ${_currentUser?.role == 'customer'}');
      } else {
        // IMPORTANT: Keep existing profile if network call fails, otherwise create default
        if (_currentUser == null) {
          debugPrint('⚠️ No profile found and no cached profile, using default customer role');
          _currentUser = app.User(
            id: authUser.id,
            email: authUser.email ?? '',
            name: '',
            role: 'customer',
            phone: null,
          );
          await _saveUserToCache(_currentUser!);
          debugPrint('✅ Created default user profile for: ${authUser.email}');
        } else {
          debugPrint('ℹ️ Network call failed but keeping existing cached profile: ${_currentUser?.name}');
        }
      }
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('❌ Error refreshing user profile: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      // CRITICAL: Preserve existing user or set basic profile so auth doesn't completely fail
      final authUser = _supabase.auth.currentUser;
      if (authUser != null && _currentUser == null) {
        _currentUser = app.User(
          id: authUser.id,
          email: authUser.email ?? '',
          name: '',
          role: 'customer',
          phone: null,
        );
        await _saveUserToCache(_currentUser!);
        debugPrint('⚠️ Using fallback user profile due to error');
        notifyListeners();
      } else if (_currentUser != null) {
        debugPrint('ℹ️ Keeping existing user profile despite error: ${_currentUser?.name}');
      }
    }
  }

  /// Public method to refresh the current user profile from database
  Future<void> refreshProfile() async {
    await _refreshCurrentUserFromProfile();
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
        final normalizedPhone = (phone == null || phone.trim().isEmpty)
            ? null
            : PhoneUtils.normalizeKenyan(phone);

        final res = await _supabase.auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: oauthRedirectUri,
          // ADDED: Pass metadata so trigger can read it
          data: {
            'name': name ?? '',
            'phone': normalizedPhone,
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
            phone: normalizedPhone,
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
      // ADDED: Clear any existing session first to avoid stale token issues
      final currentSession = _supabase.auth.currentSession;
      if (currentSession != null) {
        debugPrint('⚠️ Clearing existing session before new login');
        try {
          await _supabase.auth.signOut(scope: SignOutScope.local);
        } catch (e) {
          debugPrint('⚠️ Error clearing session (continuing anyway): $e');
        }
      }
      
      debugPrint('🔐 Attempting login for: $email');
      final resp = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      ).timeout(const Duration(seconds: 15));
      
      debugPrint('✅ Login successful');
      await _refreshCurrentUserFromProfile();
      notifyListeners();
      return resp;
    } on AuthException catch (e) {
      debugPrint('❌ Login failed: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('❌ Login error: $e');
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
    debugPrint('🚪 Signing out user...');
    
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
    
    // ADDED: Clear user profile cache
    await prefs.remove(_cacheKeyUserId);
    await prefs.remove(_cacheKeyUserEmail);
    await prefs.remove(_cacheKeyUserName);
    await prefs.remove(_cacheKeyUserRole);
    await prefs.remove(_cacheKeyUserPhone);
    
    // Sign out from Supabase (clears both local and global sessions)
    try {
      await _supabase.auth.signOut(scope: SignOutScope.global);
      debugPrint('✅ Signed out successfully');
    } catch (e) {
      debugPrint('⚠️ Error during sign out: $e');
      // Try local signout as fallback
      try {
        await _supabase.auth.signOut(scope: SignOutScope.local);
      } catch (e2) {
        debugPrint('⚠️ Local sign out also failed: $e2');
      }
    }
    
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
    final normalizedPhone = (phone == null || phone.trim().isEmpty)
        ? null
        : PhoneUtils.normalizeKenyan(phone);

    await _supabase.from('users').upsert({
      'auth_id': authId,
      'email': email,
      'name': name,
      'phone': normalizedPhone,
      'role': role,
    }, onConflict: 'auth_id', ignoreDuplicates: true);
  }

  Future<Map<String, dynamic>?> getCurrentProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      debugPrint('⚠️ No current auth user');
      return null;
    }

    debugPrint('🔄 Fetching current user profile...');
    debugPrint('🔑 User auth_id: ${user.id}');
    
    final resp = await _supabase
        .from('users')
        .select('auth_id, email, name, phone, role, addresses, default_address_index, created_at, updated_at')
        .eq('auth_id', user.id)
        .maybeSingle();
    
    if (resp != null) {
      debugPrint('✅ Profile fetched successfully');
      debugPrint('📋 Profile data: $resp');
    } else {
      debugPrint('⚠️ No profile found for user ${user.id}');
    }
    
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
      debugPrint('🔐 Attempting login for: $email');
      
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        debugPrint('✅ Login successful for: ${response.user!.email}');
        
        // Load user profile to get role (same pattern as MenuProvider)
        final userId = response.user!.id;
        try {
          debugPrint('🔄 Starting to load user profile from Supabase...');
          debugPrint('🔑 User auth_id: $userId');
          
          final userProfile = await Supabase.instance.client
              .from('users')
              .select('auth_id, email, name, phone, role, addresses, default_address_index, created_at, updated_at')
              .eq('auth_id', userId)
              .single();
          
          debugPrint('✅ Query executed successfully');
          debugPrint('📊 Response type: ${userProfile.runtimeType}');
          debugPrint('📋 Raw user profile from DB: $userProfile');
          
          // Parse user data
          _currentUser = app.User(
            id: userId,
            email: response.user!.email!,
            name: userProfile['name'] as String?,
            phone: userProfile['phone'] as String?,
            role: userProfile['role'] as String? ?? 'customer',
          );
          
          debugPrint('✅ User profile loaded: ${_currentUser?.name} (Role: ${_currentUser?.role})');
          debugPrint('🔑 Role checks:');
          debugPrint('   - Is Admin: ${_currentUser?.role == 'admin'}');
          debugPrint('   - Is Rider: ${_currentUser?.role == 'rider'}');
          debugPrint('   - Is Customer: ${_currentUser?.role == 'customer'}');
          debugPrint('🎉 Login complete for user: ${_currentUser?.email}');
          
        } catch (e, stackTrace) {
          debugPrint('❌ Error loading user profile: $e');
          debugPrint('⚠️ Error type: ${e.runtimeType}');
          debugPrint('Stack: $stackTrace');
          
          // Fallback: create user without profile data
          _currentUser = app.User(
            id: userId,
            email: response.user!.email!,
            role: 'customer', // Default role
          );
          debugPrint('⚠️ Using fallback user with customer role');
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
    final normalizedPhone = PhoneUtils.normalizeKenyan(phone);
    await signUpWithEmail(
      email: email,
      password: password,
      name: name,
      phone: normalizedPhone,
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