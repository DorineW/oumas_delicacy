// auth_service.dart
import 'package:flutter/foundation.dart';

enum UserRole { customer, admin }

class User {
  final String id;
  final String email;
  final String name;
  final UserRole role;
  
  User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
  });
}

class AuthService with ChangeNotifier {
  User? _currentUser;
  
  User? get currentUser => _currentUser;
  bool get isAdmin => _currentUser?.role == UserRole.admin;
  
  Future<void> login(String email, String password) async {
    // Here you would call your backend API
    // For demo purposes, we'll use mock data
    if (email == 'admin@example.com') {
      _currentUser = User(
        id: '1',
        email: email,
        name: 'Admin User',
        role: UserRole.admin,
      );
    } else {
      _currentUser = User(
        id: '2',
        email: email,
        name: 'Regular User',
        role: UserRole.customer,
      );
    }
    notifyListeners();
  }
  
  Future<void> logout() async {
    _currentUser = null;
    notifyListeners();
  }
}