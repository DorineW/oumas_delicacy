// lib/services/auth_service.dart
import 'package:flutter/foundation.dart';

class User {
  final String id;
  final String name;
  final String email;
  final String role;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });
}

class AuthService extends ChangeNotifier {
  User? _currentUser;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.role == 'admin'; // ADDED: isAdmin getter
  bool get isRider => _currentUser?.role == 'rider'; // ADDED: isRider getter

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