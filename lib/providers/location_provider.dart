// lib/providers/location_provider.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math'; // ADDED: Import for cos, asin, sqrt
import 'package:geolocator/geolocator.dart';

class LocationProvider with ChangeNotifier {
  double? _latitude;
  double? _longitude;
  String? _deliveryAddress;
  bool _isLoading = false;
  String? _error;
  Position? _currentPosition;
  bool _outsideDeliveryArea = false; // ADDED: Delivery zone check

  double? get latitude => _latitude;
  double? get longitude => _longitude;
  String? get deliveryAddress => _deliveryAddress;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Position? get currentPosition => _currentPosition;
  bool get outsideDeliveryArea => _outsideDeliveryArea; // ADDED

  // Dynamic location - will be set from LocationManagementProvider
  double? _restaurantLat;
  double? _restaurantLon;
  double _maxDeliveryDistanceKm = 5.0; // Default, will be updated from location
  
  // Fallback coordinates (only if no locations in database)
  static const double fallbackLatitude = -1.303960; 
  static const double fallbackLongitude = 36.790900;

  // Set restaurant location dynamically
  void setRestaurantLocation(double lat, double lon, double deliveryRadius) {
    _restaurantLat = lat;
    _restaurantLon = lon;
    _maxDeliveryDistanceKm = deliveryRadius;
    _checkDeliveryArea();
    notifyListeners();
  }

  Future<void> initializeLocation() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Check location permissions
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _error = 'Location services are disabled. Please enable them.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _error = 'Location permissions are denied';
          _isLoading = false;
          notifyListeners();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _error = 'Location permissions are permanently denied. Please enable them in app settings.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Get current position
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      _latitude = _currentPosition!.latitude;
      _longitude = _currentPosition!.longitude;

      // ADDED: Check delivery area before reverse geocode
      _checkDeliveryArea();
      
      await _reverseGeocode(_latitude!, _longitude!);
      
      // ADDED: Notify after all operations complete
      notifyListeners();
      
    } catch (e) {
      _error = 'Failed to get location: $e';
      // Set fallback coordinates only if restaurant location not set
      if (_restaurantLat == null || _restaurantLon == null) {
        _latitude = fallbackLatitude;
        _longitude = fallbackLongitude;
        _deliveryAddress = 'Default Location';
      }
      _checkDeliveryArea(); // ADDED: Check delivery area for default location
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setLocation(double latitude, double longitude) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    _latitude = latitude;
    _longitude = longitude;
    
    // FIXED: Check delivery area first (before reverse geocode to get accurate fee)
    _checkDeliveryArea();
    
    await _reverseGeocode(latitude, longitude);
    
    // ADDED: Notify again after reverse geocode completes to update delivery fee
    notifyListeners();
  }

  Future<void> _reverseGeocode(double lat, double lon) async {
    try {
      // Use OpenStreetMap Nominatim with proper rate limiting
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?'
        'lat=$lat&lon=$lon&format=json&addressdetails=1&zoom=18'
      );
      
      debugPrint('🌍 Reverse geocoding: $lat, $lon');
      
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'FoodDeliveryApp/1.0 (contact@yourapp.com)',
          'Accept-Language': 'en',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _deliveryAddress = _parseAddress(data);
        _error = null;
        debugPrint('✅ Address resolved: $_deliveryAddress');
      } else {
        // Don't cache fallback - just set generic address
        _deliveryAddress = 'Lat: ${lat.toStringAsFixed(5)}, Lon: ${lon.toStringAsFixed(5)}';
        _error = 'Could not fetch detailed address';
        debugPrint('⚠️ Geocoding failed: HTTP ${response.statusCode}');
      }
    } catch (e) {
      // Don't cache fallback - show coordinates instead
      _deliveryAddress = 'Lat: ${lat.toStringAsFixed(5)}, Lon: ${lon.toStringAsFixed(5)}';
      _error = 'Address lookup failed';
      debugPrint('❌ Geocoding error: $e');
    } finally {
      _isLoading = false;
      // REMOVED: notifyListeners() - caller will handle it
    }
  }

  // ADDED: Forward geocoding (search by text)
  Future<List<Map<String, dynamic>>> searchAddress(String query) async {
    if (query.isEmpty) return [];
    
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?'
        'q=$query&format=json&limit=5&countrycodes=ke' // ADDED: Limit to Kenya
      );
      
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'FoodDeliveryApp/1.0 (contact@yourapp.com)',
          'Accept-Language': 'en',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];
      
      final results = json.decode(response.body) as List;
      return results
          .map((r) => {
                'name': r['display_name'],
                'lat': double.parse(r['lat']),
                'lon': double.parse(r['lon']),
              })
          .toList();
    } catch (e) {
      debugPrint('Address search error: $e');
      return [];
    }
  }

  // ADDED: Check if location is within delivery area from nearest restaurant
  void _checkDeliveryArea() {
    // Use dynamic restaurant location or fallback
    final restaurantLat = _restaurantLat ?? fallbackLatitude;
    final restaurantLon = _restaurantLon ?? fallbackLongitude;
    
    if (_latitude == null || _longitude == null) {
      _outsideDeliveryArea = false;
      return;
    }

    final distance = _calculateDistance(
      restaurantLat,
      restaurantLon,
      _latitude!,
      _longitude!,
    );
    
    debugPrint('🔍 Location Check:');
    debugPrint('   Restaurant: ($restaurantLat, $restaurantLon)');
    debugPrint('   User: ($_latitude, $_longitude)');
    debugPrint('   Distance: ${distance.toStringAsFixed(3)} km');
    debugPrint('   Max Distance: $_maxDeliveryDistanceKm km');
    debugPrint('   Outside Zone: ${distance > _maxDeliveryDistanceKm}');
    
    _outsideDeliveryArea = distance > _maxDeliveryDistanceKm;
  }

  // ADDED: Calculate distance using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Pi / 180
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // Distance in km
  }

  // ADDED: Delivery Fee Logic - will be calculated by LocationManagementProvider
  // This is a fallback for backward compatibility
  int get deliveryFee {
    if (_latitude == null || _longitude == null) {
      return 0; // No location set, no delivery fee
    }
    
    final restaurantLat = _restaurantLat ?? fallbackLatitude;
    final restaurantLon = _restaurantLon ?? fallbackLongitude;
    final distance = getDistanceFrom(restaurantLat, restaurantLon);
    
    if (distance > _maxDeliveryDistanceKm) {
      return 0; // Outside delivery area
    }

    // Simple tiered pricing for fallback (real pricing from LocationManagementProvider)
    if (distance <= 1.0) {
      return 50;
    } else if (distance <= 2.0) {
      return 100;
    } else if (distance <= 3.0) {
      return 150;
    } else if (distance <= 4.0) {
      return 200;
    } else {
      return 250;
    }
  }

  String _parseAddress(Map<String, dynamic> data) {
    final address = data['address'] as Map<String, dynamic>?;
    if (address == null) {
      // Use display_name as fallback if no address components
      return data['display_name'] ?? 'Location: ${_latitude?.toStringAsFixed(5)}, ${_longitude?.toStringAsFixed(5)}';
    }

    // Build address in a user-friendly format for Nairobi
    final parts = <String>[];
    
    // Priority order: road, neighbourhood, suburb, city/town
    if (address['road'] != null) parts.add(address['road']);
    if (address['neighbourhood'] != null && address['neighbourhood'] != address['road']) {
      parts.add(address['neighbourhood']);
    }
    if (address['suburb'] != null && address['suburb'] != address['neighbourhood']) {
      parts.add(address['suburb']);
    }
    
    // Add city/town/village
    if (address['city'] != null) {
      parts.add(address['city']);
    } else if (address['town'] != null) {
      parts.add(address['town']);
    } else if (address['village'] != null) {
      parts.add(address['village']);
    } else {
      // Only add "Nairobi" if we're actually in Nairobi County
      if (address['county'] == 'Nairobi' || address['state'] == 'Nairobi') {
        parts.add('Nairobi');
      }
    }
    
    // Final check: if we got nothing useful, show coordinates
    if (parts.isEmpty) {
      return 'Location: ${_latitude?.toStringAsFixed(5)}, ${_longitude?.toStringAsFixed(5)}';
    }
    
    return parts.join(', ');
  }

  // Check if location is within delivery radius (5km from restaurant)
  bool isWithinDeliveryRadius(double restaurantLat, double restaurantLon) {
    if (_latitude == null || _longitude == null) return false;
    
    final distance = Geolocator.distanceBetween(
      restaurantLat,
      restaurantLon,
      _latitude!,
      _longitude!,
    );
    
    return distance <= 5000; // 5km in meters
  }

  // ADDED: Get distance from restaurant in km
  double getDistanceFrom(double restaurantLat, double restaurantLon) {
    if (_latitude == null || _longitude == null) return 0.0;
    
    final distance = Geolocator.distanceBetween(
      restaurantLat,
      restaurantLon,
      _latitude!,
      _longitude!,
    );
    
    return distance / 1000; // Convert to kilometers
  }

  void clearLocation() {
    _latitude = null;
    _longitude = null;
    _deliveryAddress = null;
    _error = null;
    _outsideDeliveryArea = false; // ADDED: Reset delivery zone flag
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}