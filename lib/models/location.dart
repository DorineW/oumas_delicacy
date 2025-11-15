// lib/models/location.dart
class Location {
  final String id;
  final String? ownerAuthId;
  final String name;
  final Map<String, dynamic>? address;
  final double? lat;
  final double? lon;
  final String locationType;
  final bool isActive;
  final DateTime createdAt;
  
  // Delivery settings (Phase 2)
  final double? deliveryRadiusKm;
  final int? deliveryBaseFee;
  final int? deliveryRatePerKm;
  final int? minimumOrderAmount;
  final int? freeDeliveryThreshold;

  Location({
    required this.id,
    this.ownerAuthId,
    required this.name,
    this.address,
    this.lat,
    this.lon,
    required this.locationType,
    required this.isActive,
    required this.createdAt,
    this.deliveryRadiusKm,
    this.deliveryBaseFee,
    this.deliveryRatePerKm,
    this.minimumOrderAmount,
    this.freeDeliveryThreshold,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: json['id'] ?? '',
      ownerAuthId: json['owner_auth_id'],
      name: json['name'] ?? '',
      address: json['address'],
      lat: json['lat'] != null ? double.parse(json['lat'].toString()) : null,
      lon: json['lon'] != null ? double.parse(json['lon'].toString()) : null,
      locationType: json['location_type'] ?? 'Restaurant',
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      deliveryRadiusKm: json['delivery_radius_km'] != null
          ? double.parse(json['delivery_radius_km'].toString())
          : null,
      deliveryBaseFee: json['delivery_base_fee'] as int?,
      deliveryRatePerKm: json['delivery_rate_per_km'] as int?,
      minimumOrderAmount: json['minimum_order_amount'] as int?,
      freeDeliveryThreshold: json['free_delivery_threshold'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_auth_id': ownerAuthId,
      'name': name,
      'address': address,
      'lat': lat,
      'lon': lon,
      'location_type': locationType,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'delivery_radius_km': deliveryRadiusKm,
      'delivery_base_fee': deliveryBaseFee,
      'delivery_rate_per_km': deliveryRatePerKm,
      'minimum_order_amount': minimumOrderAmount,
      'free_delivery_threshold': freeDeliveryThreshold,
    };
  }

  bool get isWarehouse => locationType == 'Warehouse';
  bool get isGeneralStore => locationType == 'General Store';
  bool get isRestaurant => locationType == 'Restaurant';
  
  // Calculate delivery fee for a given distance (in km)
  int calculateDeliveryFee(double distanceKm) {
    if (deliveryRadiusKm != null && distanceKm > deliveryRadiusKm!) {
      return -1; // Outside delivery zone
    }
    
    final baseFee = deliveryBaseFee ?? 0;
    final perKmRate = deliveryRatePerKm ?? 0;
    
    return baseFee + (distanceKm * perKmRate).round();
  }

  // Check if location can deliver to a given distance
  bool canDeliverTo(double distanceKm) {
    if (deliveryRadiusKm == null) return true; // Unlimited delivery
    return distanceKm <= deliveryRadiusKm!;
  }

  // Check if order amount qualifies for free delivery
  bool qualifiesForFreeDelivery(int orderAmount) {
    if (freeDeliveryThreshold == null) return false;
    return orderAmount >= freeDeliveryThreshold!;
  }

  // Check if order meets minimum requirement
  bool meetsMinimumOrder(int orderAmount) {
    final minimum = minimumOrderAmount ?? 0;
    return orderAmount >= minimum;
  }

  String get displayAddress {
    if (address != null && address!['formatted'] != null) {
      return address!['formatted'] as String;
    }
    return 'No address set';
  }

  Location copyWith({
    String? id,
    String? ownerAuthId,
    String? name,
    Map<String, dynamic>? address,
    double? lat,
    double? lon,
    String? locationType,
    bool? isActive,
    DateTime? createdAt,
    double? deliveryRadiusKm,
    int? deliveryBaseFee,
    int? deliveryRatePerKm,
    int? minimumOrderAmount,
    int? freeDeliveryThreshold,
  }) {
    return Location(
      id: id ?? this.id,
      ownerAuthId: ownerAuthId ?? this.ownerAuthId,
      name: name ?? this.name,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      locationType: locationType ?? this.locationType,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      deliveryRadiusKm: deliveryRadiusKm ?? this.deliveryRadiusKm,
      deliveryBaseFee: deliveryBaseFee ?? this.deliveryBaseFee,
      deliveryRatePerKm: deliveryRatePerKm ?? this.deliveryRatePerKm,
      minimumOrderAmount: minimumOrderAmount ?? this.minimumOrderAmount,
      freeDeliveryThreshold: freeDeliveryThreshold ?? this.freeDeliveryThreshold,
    );
  }
}