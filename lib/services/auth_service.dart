// lib/services/auth_service.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ADDED

class User {
  final String id;
  final String email;
  final String name;
  final String role;
  final String? phone; // ADDED

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.phone, // ADDED
  });
}

class AuthService extends ChangeNotifier {
  User? _currentUser;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.role == 'admin'; // ADDED: isAdmin getter
  bool get isRider => _currentUser?.role == 'rider'; // ADDED: isRider getter

  // ADDED: Load user profile data
  Future<void> loadUserProfile() async {
    if (_currentUser != null) {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('name') ?? _currentUser!.name;
      final phone = prefs.getString('phone') ?? '';
      
      // Update current user with saved profile data
      _currentUser = User(
        id: _currentUser!.id,
        email: _currentUser!.email,
        name: name,
        role: _currentUser!.role,
        phone: phone.isNotEmpty ? phone : null,
      );
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));
    
    // Determine role based on email
    String role = 'customer';
    String name = 'Regular User';
    String id = '2';
    
    if (email.contains('admin')) {
      role = 'admin';
      name = 'Admin User';
      id = '1';
    } else if (email.contains('rider')) {
      role = 'rider';
      name = 'Rider User';
      id = '3';
    }
    
    _currentUser = User(
      id: id,
      name: name,
      email: email,
      role: role,
    );
    notifyListeners();

    // ADDED: Load user profile after login
    await loadUserProfile();
  }

  Future<void> logout() async {
    _currentUser = null;
    notifyListeners();
  }

  void setUser(User user) {
    _currentUser = user;
    notifyListeners();
  }
}