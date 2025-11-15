// lib/providers/location_management_provider.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/location.dart';
import 'dart:math' show cos, sqrt, asin;

class LocationManagementProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  
  List<Location> _locations = [];
  bool _isLoading = false;
  String? _error;

  List<Location> get locations => _locations;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Location> get activeLocations => _locations.where((l) => l.isActive).toList();
  List<Location> get restaurants => _locations.where((l) => l.isRestaurant).toList();
  List<Location> get stores => _locations.where((l) => l.isGeneralStore).toList();

  /// Load all locations from database
  Future<void> loadLocations() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('locations')
          .select()
          .order('created_at', ascending: false);

      _locations = (response as List)
          .map((json) => Location.fromJson(json))
          .toList();
      
      debugPrint('✅ Loaded ${_locations.length} locations');
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error loading locations: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add a new location
  Future<Location?> addLocation({
    required String name,
    required String locationType,
    double? lat,
    double? lon,
    Map<String, dynamic>? address,
    double? deliveryRadiusKm,
    int? deliveryBaseFee,
    int? deliveryRatePerKm,
    int? minimumOrderAmount,
    int? freeDeliveryThreshold,
  }) async {
    try {
      final data = {
        'name': name,
        'location_type': locationType,
        'lat': lat,
        'lon': lon,
        'address': address,
        'is_active': true,
        'delivery_radius_km': deliveryRadiusKm,
        'delivery_base_fee': deliveryBaseFee,
        'delivery_rate_per_km': deliveryRatePerKm,
        'minimum_order_amount': minimumOrderAmount,
        'free_delivery_threshold': freeDeliveryThreshold,
      };

      final response = await _supabase
          .from('locations')
          .insert(data)
          .select()
          .single();

      final newLocation = Location.fromJson(response);
      _locations.insert(0, newLocation);
      notifyListeners();

      debugPrint('✅ Location added: ${newLocation.name}');
      return newLocation;
    } catch (e) {
      debugPrint('❌ Error adding location: $e');
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Update an existing location
  Future<bool> updateLocation({
    required String locationId,
    String? name,
    double? lat,
    double? lon,
    Map<String, dynamic>? address,
    bool? isActive,
    double? deliveryRadiusKm,
    int? deliveryBaseFee,
    int? deliveryRatePerKm,
    int? minimumOrderAmount,
    int? freeDeliveryThreshold,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (lat != null) data['lat'] = lat;
      if (lon != null) data['lon'] = lon;
      if (address != null) data['address'] = address;
      if (isActive != null) data['is_active'] = isActive;
      if (deliveryRadiusKm != null) data['delivery_radius_km'] = deliveryRadiusKm;
      if (deliveryBaseFee != null) data['delivery_base_fee'] = deliveryBaseFee;
      if (deliveryRatePerKm != null) data['delivery_rate_per_km'] = deliveryRatePerKm;
      if (minimumOrderAmount != null) data['minimum_order_amount'] = minimumOrderAmount;
      if (freeDeliveryThreshold != null) data['free_delivery_threshold'] = freeDeliveryThreshold;

      await _supabase
          .from('locations')
          .update(data)
          .eq('id', locationId);

      // Reload to get updated data
      await loadLocations();

      debugPrint('✅ Location updated: $locationId');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating location: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Delete a location
  Future<bool> deleteLocation(String locationId) async {
    try {
      await _supabase
          .from('locations')
          .delete()
          .eq('id', locationId);

      _locations.removeWhere((l) => l.id == locationId);
      notifyListeners();

      debugPrint('✅ Location deleted: $locationId');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting location: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Toggle location active status
  Future<bool> toggleLocationStatus(String locationId) async {
    final location = _locations.firstWhere((l) => l.id == locationId);
    return await updateLocation(
      locationId: locationId,
      isActive: !location.isActive,
    );
  }

  /// Find locations that can deliver to a given coordinate
  List<Location> findLocationsServingArea(double userLat, double userLon) {
    return _locations.where((location) {
      if (!location.isActive) return false;
      if (location.lat == null || location.lon == null) return false;

      final distance = _calculateDistance(
        userLat,
        userLon,
        location.lat!,
        location.lon!,
      );

      return location.canDeliverTo(distance);
    }).toList()
      ..sort((a, b) {
        final distA = _calculateDistance(userLat, userLon, a.lat!, a.lon!);
        final distB = _calculateDistance(userLat, userLon, b.lat!, b.lon!);
        return distA.compareTo(distB);
      });
  }

  /// Get the nearest location to a given coordinate
  Location? getNearestLocation(double userLat, double userLon) {
    final serving = findLocationsServingArea(userLat, userLon);
    return serving.isNotEmpty ? serving.first : null;
  }

  /// Calculate distance between two coordinates (Haversine formula)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  /// Calculate delivery fee from a specific location to user coordinates
  Map<String, dynamic>? calculateDeliveryDetails({
    required String locationId,
    required double userLat,
    required double userLon,
    required int orderAmount,
  }) {
    final location = _locations.firstWhere(
      (l) => l.id == locationId,
      orElse: () => throw Exception('Location not found'),
    );

    if (location.lat == null || location.lon == null) {
      return null;
    }

    final distance = _calculateDistance(userLat, userLon, location.lat!, location.lon!);
    
    if (!location.canDeliverTo(distance)) {
      return {
        'canDeliver': false,
        'reason': 'Outside delivery zone (${distance.toStringAsFixed(1)}km > ${location.deliveryRadiusKm}km)',
      };
    }

    if (!location.meetsMinimumOrder(orderAmount)) {
      return {
        'canDeliver': false,
        'reason': 'Order below minimum (KES $orderAmount < KES ${location.minimumOrderAmount})',
      };
    }

    final deliveryFee = location.calculateDeliveryFee(distance);
    final isFree = location.qualifiesForFreeDelivery(orderAmount);

    return {
      'canDeliver': true,
      'distance': distance,
      'deliveryFee': isFree ? 0 : deliveryFee,
      'originalFee': deliveryFee,
      'isFreeDelivery': isFree,
      'location': location,
    };
  }
}
