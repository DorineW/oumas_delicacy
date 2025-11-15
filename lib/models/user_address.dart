// lib/models/user_address.dart

class UserAddress {
  final String id;
  final String userAuthId;
  final String label;
  final double latitude;
  final double longitude;
  final String descriptiveDirections;
  final String? streetAddress;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserAddress({
    required this.id,
    required this.userAuthId,
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.descriptiveDirections,
    this.streetAddress,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserAddress.fromJson(Map<String, dynamic> json) {
    return UserAddress(
      id: json['id'] as String,
      userAuthId: json['user_auth_id'] as String,
      label: json['label'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      descriptiveDirections: json['descriptive_directions'] as String,
      streetAddress: json['street_address'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_auth_id': userAuthId,
      'label': label,
      'latitude': latitude,
      'longitude': longitude,
      'descriptive_directions': descriptiveDirections,
      'street_address': streetAddress,
      'is_default': isDefault,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Display format for showing in UI
  String get displayAddress {
    if (streetAddress != null && streetAddress!.isNotEmpty) {
      return '$streetAddress\n$descriptiveDirections';
    }
    return descriptiveDirections;
  }

  // Short format for labels
  String get shortDisplay {
    return label.isNotEmpty ? '$label: $descriptiveDirections' : descriptiveDirections;
  }

  UserAddress copyWith({
    String? id,
    String? userAuthId,
    String? label,
    double? latitude,
    double? longitude,
    String? descriptiveDirections,
    String? streetAddress,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserAddress(
      id: id ?? this.id,
      userAuthId: userAuthId ?? this.userAuthId,
      label: label ?? this.label,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      descriptiveDirections: descriptiveDirections ?? this.descriptiveDirections,
      streetAddress: streetAddress ?? this.streetAddress,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
