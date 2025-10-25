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

  // Nairobi, Madaraka coordinates as fallback
  static const double defaultLatitude = -1.3076;
  static const double defaultLongitude = 36.7811;

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

      await _reverseGeocode(_latitude!, _longitude!);
      
    } catch (e) {
      _error = 'Failed to get location: $e';
      // Set default to Madaraka, Nairobi
      _latitude = defaultLatitude;
      _longitude = defaultLongitude;
      _deliveryAddress = 'Madaraka, Nairobi, Kenya';;
      _isLoading = false; // ADDED: Set loading false on error
      notifyListeners();
    }
    // REMOVED: finally block that was calling notifyListeners() - already called in _reverseGeocode
  }

  Future<void> setLocation(double latitude, double longitude) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    _latitude = latitude;
    _longitude = longitude;
    
    await _reverseGeocode(latitude, longitude);
    _checkDeliveryArea(); // ADDED: Check if location is in delivery zone
  }

  Future<void> _reverseGeocode(double lat, double lon) async {
    try {
      // Use OpenStreetMap Nominatim with proper rate limiting
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?'
        'lat=$lat&lon=$lon&format=json&addressdetails=1&zoom=18'
      );
      
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
      } else {
        _deliveryAddress = 'Near Madaraka, Nairobi';
        _error = 'Could not fetch detailed address';
      }
    } catch (e) {
      _deliveryAddress = 'Near Madaraka, Nairobi';
      _error = 'Address lookup failed';
    } finally {
      _isLoading = false;
      notifyListeners();
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

  // ADDED: Check if location is within delivery area (5km from restaurant)
  void _checkDeliveryArea() {
    const restaurantLat = defaultLatitude; // Restaurant location
    const restaurantLon = defaultLongitude;
    const deliveryRadius = 5.0; // 5km delivery radius

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
    
    _outsideDeliveryArea = distance > deliveryRadius;
  }

  // ADDED: Calculate distance using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Pi / 180
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // Distance in km
  }

  String _parseAddress(Map<String, dynamic> data) {
    final address = data['address'] as Map<String, dynamic>?;
    if (address == null) return data['display_name'] ?? 'Unknown Location';

    // Build address in a user-friendly format for Nairobi
    final parts = <String>[];
    
    if (address['road'] != null) parts.add(address['road']);
    if (address['neighbourhood'] != null) parts.add(address['neighbourhood']);
    if (address['suburb'] != null) parts.add(address['suburb']);
    if (address['city'] != null) {
      parts.add(address['city']);
    } else {
      parts.add('Nairobi'); // Default to Nairobi if no city
    }
    
    return parts.isNotEmpty ? parts.join(', ') : 'Madaraka, Nairobi, Kenya';
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

  // Get distance from restaurant in km
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