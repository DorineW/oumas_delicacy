// lib/services/auth_service.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthService extends ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.role == 'admin';
  bool get isRider => _currentUser?.role == 'rider';
  bool get isLoading => _isLoading;

  // ADDED: Demo accounts for admin and rider only
  final Map<String, Map<String, dynamic>> _demoAccounts = {
    'admin@example.com': {
      'id': 'admin_001',
      'email': 'admin@example.com',
      'password': 'admin123',
      'name': 'Admin User',
      'role': 'admin',
      'phone': '+254712345678',
    },
    'rider@example.com': {
      'id': 'rider_001',
      'email': 'rider@example.com',
      'password': 'rider123',
      'name': 'John Rider',
      'role': 'rider',
      'phone': '+254712345679',
    },
  };

  AuthService() {
    _loadUserFromPrefs();
  }

  Future<void> _loadUserFromPrefs() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final email = prefs.getString('user_email');
      final name = prefs.getString('user_name') ?? prefs.getString('name');
      final role = prefs.getString('user_role');
      final phone = prefs.getString('user_phone') ?? prefs.getString('phone');

      if (userId != null && email != null && role != null) {
        _currentUser = User(
          id: userId,
          email: email,
          name: name ?? 'Guest',
          role: role,
          phone: phone,
        );
        debugPrint('✅ Loaded user from prefs: ${_currentUser!.email} (${_currentUser!.role})');
      } else {
        debugPrint('❌ No saved user found in prefs');
      }
    } catch (e) {
      debugPrint('❌ Error loading user from prefs: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // UPDATED: Login with proper data cleanup for new users
  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      await Future.delayed(const Duration(seconds: 1));

      final trimmedEmail = email.trim().toLowerCase();
      final trimmedPassword = password.trim();

      debugPrint('🔐 Login attempt: $trimmedEmail');

      // Check demo accounts first (admin/rider)
      if (_demoAccounts.containsKey(trimmedEmail)) {
        final userData = _demoAccounts[trimmedEmail]!;
        
        if (userData['password'] != trimmedPassword) {
          throw Exception('Incorrect password. Please try again.');
        }

        _currentUser = User(
          id: userData['id'] as String,
          email: userData['email'] as String,
          name: userData['name'] as String,
          role: userData['role'] as String,
          phone: userData['phone'] as String?,
        );
      } else {
        // Check registered customers
        final prefs = await SharedPreferences.getInstance();
        final registeredUsers = prefs.getStringList('registered_users') ?? [];
        
        bool found = false;
        for (final userJson in registeredUsers) {
          final parts = userJson.split('|');
          if (parts.length >= 5) {
            final storedEmail = parts[1];
            final storedPassword = parts[2];
            
            if (storedEmail == trimmedEmail) {
              found = true;
              
              if (storedPassword != trimmedPassword) {
                throw Exception('Incorrect password. Please try again.');
              }

              _currentUser = User(
                id: parts[0],
                email: parts[1],
                name: parts[3],
                role: 'customer',
                phone: parts[4],
              );
              break;
            }
          }
        }

        if (!found) {
          throw Exception('Account not found. Please register first.');
        }
      }

      // UPDATED: Clear old profile data before saving new session
      final prefs = await SharedPreferences.getInstance();
      
      // Only clear profile image if it's a different user
      final oldUserId = prefs.getString('user_id');
      if (oldUserId != _currentUser!.id) {
        await prefs.remove('profileImagePath'); // Clear old profile image
        debugPrint('🧹 Cleared old profile image for new user session');
      }
      
      // Save current session to SharedPreferences
      await prefs.setString('user_id', _currentUser!.id);
      await prefs.setString('user_email', _currentUser!.email);
      await prefs.setString('user_name', _currentUser!.name);
      await prefs.setString('user_role', _currentUser!.role);
      await prefs.setString('name', _currentUser!.name);
      await prefs.setString('email', _currentUser!.email);
      
      if (_currentUser!.phone != null) {
        await prefs.setString('user_phone', _currentUser!.phone!);
        await prefs.setString('phone', _currentUser!.phone!);
      }

      debugPrint('✅ Login successful: ${_currentUser!.email} (${_currentUser!.role})');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Login failed: $e');
      _currentUser = null;
      _isLoading = false;
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ADDED: Logout method
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.remove('user_id');
      await prefs.remove('user_email');
      await prefs.remove('user_name');
      await prefs.remove('user_role');
      await prefs.remove('user_phone');

      _currentUser = null;
      debugPrint('✅ Logout successful');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Logout error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ADDED: Load user profile method
  Future<void> loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (_currentUser != null) {
      final name = prefs.getString('name');
      if (name != null && name != _currentUser!.name) {
        _currentUser = User(
          id: _currentUser!.id,
          email: _currentUser!.email,
          name: name,
          role: _currentUser!.role,
          phone: prefs.getString('phone'),
        );
        
        await prefs.setString('user_name', name);
        notifyListeners();
      }
    }
  }

  // FIXED: Reset password method with proper try-catch
  Future<void> resetPassword(String email) async {
    _isLoading = true;
    notifyListeners();

    try {
      await Future.delayed(const Duration(seconds: 1)); // Simulate API delay

      final trimmedEmail = email.trim().toLowerCase();

      debugPrint('🔐 Password reset request for: $trimmedEmail');

      // Check if email exists in demo accounts
      if (_demoAccounts.containsKey(trimmedEmail)) {
        debugPrint('✅ Demo account found - simulating password reset email');
        return;
      }

      // Check if email exists in registered customers
      final prefs = await SharedPreferences.getInstance();
      final registeredUsers = prefs.getStringList('registered_users') ?? [];
      
      bool found = false;
      for (final userJson in registeredUsers) {
        final parts = userJson.split('|');
        if (parts.length >= 2 && parts[1] == trimmedEmail) {
          found = true;
          break;
        }
      }

      if (!found) {
        throw Exception('No account found with this email address');
      }

      debugPrint('✅ Customer account found - simulating password reset email');
      
    } catch (e) {
      debugPrint('❌ Password reset failed: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ADDED: Verify reset code (for future implementation)
  Future<bool> verifyResetCode(String email, String code) async {
    // TODO: Implement verification logic
    await Future.delayed(const Duration(seconds: 1));
    return code == '123456'; // Demo implementation
  }

  // ADDED: Update password after reset
  Future<void> updatePassword(String email, String newPassword) async {
    _isLoading = true;
    notifyListeners();

    try {
      await Future.delayed(const Duration(seconds: 1));

      final trimmedEmail = email.trim().toLowerCase();
      
      // Check if it's a demo account
      if (_demoAccounts.containsKey(trimmedEmail)) {
        // Demo accounts can't change password
        throw Exception('Demo accounts cannot change passwords');
      }

      // Update password for registered customers
      final prefs = await SharedPreferences.getInstance();
      final registeredUsers = prefs.getStringList('registered_users') ?? [];
      
      for (int i = 0; i < registeredUsers.length; i++) {
        final parts = registeredUsers[i].split('|');
        if (parts.length >= 2 && parts[1] == trimmedEmail) {
          // Update the password field
          parts[2] = newPassword;
          
          // Rebuild the user string
          registeredUsers[i] = parts.join('|');
          break;
        }
      }

      await prefs.setStringList('registered_users', registeredUsers);

      debugPrint('✅ Password updated successfully');
    } catch (e) {
      debugPrint('❌ Password update failed: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ADDED: Register new customer account
  Future<void> register({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await Future.delayed(const Duration(seconds: 1));

      final trimmedEmail = email.trim().toLowerCase();
      final trimmedPassword = password.trim();
      final trimmedName = name.trim();
      final trimmedPhone = phone.trim();

      debugPrint('📝 Registration attempt: $trimmedEmail');

      // Validate input
      if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
        throw Exception('Please enter a valid email address');
      }

      if (trimmedPassword.length < 6) {
        throw Exception('Password must be at least 6 characters');
      }

      if (trimmedName.isEmpty) {
        throw Exception('Please enter your name');
      }

      if (trimmedPhone.isEmpty) {
        throw Exception('Please enter your phone number');
      }

      // Check if email already exists (demo accounts)
      if (_demoAccounts.containsKey(trimmedEmail)) {
        throw Exception('Email already registered. Please login.');
      }

      // Check if email already exists (registered customers)
      final prefs = await SharedPreferences.getInstance();
      final registeredUsers = prefs.getStringList('registered_users') ?? [];
      
      for (final userJson in registeredUsers) {
        final parts = userJson.split('|');
        if (parts.length >= 2 && parts[1] == trimmedEmail) {
          throw Exception('Email already registered. Please login.');
        }
      }

      // Create new customer account
      final userId = 'customer_${DateTime.now().millisecondsSinceEpoch}';
      final userString = '$userId|$trimmedEmail|$trimmedPassword|$trimmedName|$trimmedPhone';
      
      registeredUsers.add(userString);
      await prefs.setStringList('registered_users', registeredUsers);

      debugPrint('✅ Registration successful: $trimmedEmail');

      // Clear old profile data before setting new user data
      await prefs.remove('profileImagePath');
      await prefs.remove('name');
      await prefs.remove('email');
      await prefs.remove('phone');

      // Auto-login after registration
      _currentUser = User(
        id: userId,
        email: trimmedEmail,
        name: trimmedName,
        role: 'customer',
        phone: trimmedPhone,
      );

      // Save new user to SharedPreferences
      await prefs.setString('user_id', _currentUser!.id);
      await prefs.setString('user_email', _currentUser!.email);
      await prefs.setString('user_name', _currentUser!.name);
      await prefs.setString('user_role', _currentUser!.role);
      await prefs.setString('name', _currentUser!.name);
      await prefs.setString('email', _currentUser!.email);
      await prefs.setString('user_phone', _currentUser!.phone!);
      await prefs.setString('phone', _currentUser!.phone!);

      debugPrint('✅ New user data saved to SharedPreferences');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Registration failed: $e');
      _isLoading = false;
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}