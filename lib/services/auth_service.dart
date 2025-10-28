// lib/services/auth_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart' as app;

class AuthService extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  // ADDED: Compatibility with previous API
  app.User? _currentUser;
  bool _isLoading = false;

  app.User? get currentUser => _currentUser;
  bool get isLoggedIn => _supabase.auth.currentUser != null;
  bool get isAdmin => _currentUser?.role == 'admin';
  bool get isRider => _currentUser?.role == 'rider';
  bool get isLoading => _isLoading;

  // ADDED: Refresh cached User model from profiles table
  Future<void> _refreshCurrentUserFromProfile() async {
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) {
        _currentUser = null;
        notifyListeners();
        return;
      }
      final profile = await _supabase
          .from('profiles')
          .select()
          .eq('auth_id', authUser.id)
          .maybeSingle();

      if (profile != null) {
        _currentUser = app.User(
          id: authUser.id,
          email: (profile['email'] as String?) ?? (authUser.email ?? ''),
          name: (profile['name'] as String?) ?? '',
          role: (profile['role'] as String?) ?? 'customer',
          phone: profile['phone'] as String?,
        );
      } else {
        // Fallback to minimal info from auth
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
      // Keep silent; UI can still rely on session
    }
  }

  /// Sign up with email/password and ensures a profiles row exists.
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? name,
    String? phone,
    String role = 'customer',
  }) async {
    final res = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'name': name, 'phone': phone, 'role': role}, // CHANGED
    );

    final user = res.user;
    if (user != null) {
      await createProfileIfNotExists(
        authId: user.id,
        email: email,
        name: name ?? '',
        phone: phone,
        role: role,
      );
      await _refreshCurrentUserFromProfile(); // ADDED
      notifyListeners();
    }

    return res;
  }

  /// Sign in with email/password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final resp = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    await _refreshCurrentUserFromProfile(); // ADDED
    notifyListeners();
    return resp;
  }

  /// Sign in with Google (opens browser for OAuth)
  Future<void> signInWithGoogle({required String redirectTo}) async {
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.google, // CHANGED
      redirectTo: redirectTo,
    );
    // OAuth flow notifies via onAuthStateChange; consumers should listen to the stream.
  }

  /// Sign in with Facebook
  Future<void> signInWithFacebook({required String redirectTo}) async {
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.facebook, // CHANGED
      redirectTo: redirectTo,
    );
  }

  /// Sign out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
    _currentUser = null; // ADDED
    notifyListeners();
  }

  // ADDED: Backwards-compatible alias
  Future<void> logout() => signOut();

  /// Create a profiles entry if not already present
  Future<void> createProfileIfNotExists({
    required String authId,
    required String email,
    required String name,
    String? phone,
    String role = 'customer',
  }) async {
    final p = await _supabase
        .from('profiles')
        .select('id')
        .eq('auth_id', authId)
        .maybeSingle();

    if (p == null) {
      await _supabase.from('profiles').insert({
        'auth_id': authId,
        'email': email,
        'name': name,
        'phone': phone,
        'role': role,
      });
    }
  }

  /// Fetch current user's profile (null if no session / profile)
  Future<Map<String, dynamic>?> getCurrentProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final resp = await _supabase
        .from('profiles')
        .select()
        .eq('auth_id', user.id)
        .maybeSingle();
    return resp;
  }

  /// Listen to auth state changes (UI can subscribe)
  Stream<AuthState> authStateChanges() {
    final controller = StreamController<AuthState>();
    final sub = _supabase.auth.onAuthStateChange.listen((data) async {
      controller.add(AuthState(event: data.event, session: data.session));
      await _refreshCurrentUserFromProfile(); // ADDED
      notifyListeners();
    });
    controller.onCancel = () => sub.cancel();
    return controller.stream;
  }

  /// Backwards-compatible login wrapper
  Future<void> login(String email, String password) async {
    await signInWithEmail(email: email, password: password);
    await _refreshCurrentUserFromProfile();
    notifyListeners();
  }

  /// Backwards-compatible register wrapper
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

  /// Backwards-compatible reset password wrapper
  Future<void> resetPassword(String email, {String? redirectTo}) async {
    await _supabase.auth.resetPasswordForEmail(
      email,
      redirectTo: redirectTo,
    );
  }
}

class AuthState {
  final AuthChangeEvent? event;
  final Session? session;
  AuthState({this.event, this.session});
}