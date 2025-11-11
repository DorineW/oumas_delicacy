//lib/models/user.dart
//the user model representing application users
class User {
  final String id;
  final String email;
  final String? name;
  final String? phone;
  final String role; // Make sure this exists!

  User({
    required this.id,
    required this.email,
    this.name,
    this.phone,
    this.role = 'customer', // Default value
  });

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'auth_id': id,
      'email': email,
      'name': name,
      'phone': phone,
      'role': role,
    };
  }

  // Create from JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['auth_id'] as String,
      email: json['email'] as String,
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      role: json['role'] as String? ?? 'customer',
    );
  }

  // Copy with method for updates
  User copyWith({
    String? id,
    String? email,
    String? name,
    String? role,
    String? phone,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      phone: phone ?? this.phone,
    );
  }

  @override
  String toString() {
    return 'User(id: $id, email: $email, name: $name, role: $role, phone: $phone)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
