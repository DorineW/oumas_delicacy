// lib/providers/location_provider.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math'; // ADDED: Import for cos, asin, sqrt
import 'package:geolocator/geolocator.dart';
import '../models/location.dart'; // ADDED: Import Location model

class LocationProvider with ChangeNotifier {
  double? _latitude;
  double? _longitude;
  String? _deliveryAddress;
  bool _isLoading = false;
  String? _error;
  Position? _currentPosition;
  bool _outsideDeliveryArea = false; // ADDED: Delivery zone check
  Location? _activeLocation; // ADDED: Store active location for delivery calculations

  double? get latitude => _latitude;
  double? get longitude => _longitude;
  String? get deliveryAddress => _deliveryAddress;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Position? get currentPosition => _currentPosition;
  bool get outsideDeliveryArea => _outsideDeliveryArea; // ADDED
  Location? get activeLocation => _activeLocation; // ADDED: Expose active location

  // Dynamic location - will be set from LocationManagementProvider
  double? _restaurantLat;
  double? _restaurantLon;
  double _maxDeliveryDistanceKm = 5.0; // Default, will be updated from location
  
  // Fallback coordinates (only if no locations in database)
  static const double fallbackLatitude = -1.303960; 
  static const double fallbackLongitude = 36.790900;

  // Set restaurant location dynamically from Location model
  void setActiveLocation(Location location) {
    _activeLocation = location;
    if (location.lat != null && location.lon != null) {
      _restaurantLat = location.lat;
      _restaurantLon = location.lon;
      _maxDeliveryDistanceKm = location.deliveryRadiusKm ?? 5.0;
      _checkDeliveryArea();
      notifyListeners();
      debugPrint('✅ Active location set: ${location.name} (${location.lat}, ${location.lon})');
      debugPrint('   Delivery radius: ${location.deliveryRadiusKm}km');
      debugPrint('   Base fee: KES ${location.deliveryBaseFee}');
      debugPrint('   Rate per km: KES ${location.deliveryRatePerKm}/km');
    }
  }

  // Legacy method - kept for backward compatibility
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

  // ADDED: Set location with pre-determined address (for search results)
  void setLocationWithAddress(double latitude, double longitude, String address) {
    _latitude = latitude;
    _longitude = longitude;
    _deliveryAddress = address;
    _error = null;
    _isLoading = false;
    
    // Check delivery area
    _checkDeliveryArea();
    
    debugPrint('✅ Location set from search: $address');
    debugPrint('   Coordinates: ($latitude, $longitude)');
    
    notifyListeners();
  }

  Future<void> _reverseGeocode(double lat, double lon) async {
    try {
      // IMPROVED: Use even higher zoom level (20) for building-level precision
      // zoom=20 gives the most detailed street-level information available
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?'
        'lat=$lat&lon=$lon&format=json&addressdetails=1&zoom=20&'
        'accept-language=en&namedetails=1' // Get all name variations
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
        _deliveryAddress = 'Location: ${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}';
        _error = 'Could not fetch detailed address';
        debugPrint('⚠️ Geocoding failed: HTTP ${response.statusCode}');
      }
    } catch (e) {
      // Don't cache fallback - show coordinates instead
      _deliveryAddress = 'Location: ${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}';
      _error = 'Address lookup failed';
      debugPrint('❌ Geocoding error: $e');
    } finally {
      _isLoading = false;
      // REMOVED: notifyListeners() - caller will handle it
    }
  }

  // UPDATED: Forward geocoding (search by text) - focused on Nairobi with better accuracy
  Future<List<Map<String, dynamic>>> searchAddress(String query) async {
    if (query.isEmpty) return [];
    
    try {
      // Enhance query with Nairobi context if not already specified
      String enhancedQuery = query.trim();
      final queryLower = query.toLowerCase();
      
      // Add "Nairobi" context if user hasn't specified it
      if (!queryLower.contains('nairobi') && 
          !queryLower.contains('kenya') &&
          !queryLower.contains(', ke')) {
        enhancedQuery = '$query, Nairobi, Kenya';
      }
      
      final encodedQuery = Uri.encodeComponent(enhancedQuery);
      
      // IMPROVED: Use viewbox to prioritize Nairobi metropolitan area
      // Bounding box for Nairobi: approximately -1.45 to -1.15 lat, 36.65 to 37.10 lon
      // bounded=1 means prefer results inside the viewbox
      // namedetails=1 gives us the actual place names (universities, buildings, etc.)
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?'
        'q=$encodedQuery&'
        'format=json&'
        'limit=15&' // Increased to get more options before filtering
        'countrycodes=ke&'
        'addressdetails=1&'
        'namedetails=1&' // ADDED: Get place names for universities, buildings, etc.
        'viewbox=36.65,-1.15,37.10,-1.45&' // Nairobi bounding box (left,top,right,bottom)
        'bounded=1' // Prefer results within viewbox
      );
      
      debugPrint('🔍 Searching: "$query" (enhanced: "$enhancedQuery")');
      
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'FoodDeliveryApp/1.0 (contact@yourapp.com)',
          'Accept-Language': 'en',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('❌ Search failed: ${response.statusCode}');
        return [];
      }
      
      final results = json.decode(response.body) as List;
      debugPrint('✅ Found ${results.length} raw results');
      
      // Known Nairobi neighborhoods/estates for relevance boosting
      final nairobiFamiliarAreas = [
        'westlands', 'karen', 'kilimani', 'lavington', 'runda', 'muthaiga',
        'parklands', 'highridge', 'south c', 'south b', 'langata', 'kibera',
        'kasarani', 'ruaka', 'kileleshwa', 'upperhill', 'kilimani', 'ngong',
        'kitisuru', 'spring valley', 'loresho', 'gigiri', 'rosslyn', 
        'riverside', 'embakasi', 'donholm', 'buruburu', 'umoja', 'komarock',
        'dandora', 'kahawa', 'zimmerman', 'roysambu', 'thika road', 'cbd',
        'industrial area', 'jkia', 'syokimau', 'athi river', 'mlolongo',
        'kiambu road', 'limuru road', 'waiyaki way', 'thika', 'ruiru'
      ];
      
      // Filter and format results with better display names
      final formattedResults = <Map<String, dynamic>>[];
      
      for (final r in results) {
        final lat = double.tryParse(r['lat']?.toString() ?? '');
        final lon = double.tryParse(r['lon']?.toString() ?? '');
        
        if (lat == null || lon == null) continue;
        
        // ADDED: Filter out results too far from Nairobi center (more than 50km)
        final distanceFromNairobi = _calculateDistance(
          -1.286389, 36.817223, // Nairobi city center
          lat, lon
        );
        
        if (distanceFromNairobi > 50) {
          debugPrint('⚠️ Skipping far result: ${r['display_name']} (${distanceFromNairobi.toStringAsFixed(1)}km away)');
          continue;
        }
        
        // Build a better display name using address components
        String displayName;
        final address = r['address'] as Map<String, dynamic>?;
        final nameDetails = r['namedetails'] as Map<String, dynamic>?;
        double relevanceBoost = r['importance'] ?? 0.0;
        
        // PRIORITY 1: Check if this is a named place (university, building, amenity, etc.)
        String? placeName;
        
        // Try to get the actual place name from various fields
        if (nameDetails != null && nameDetails['name'] != null) {
          placeName = nameDetails['name'];
        } else if (r['name'] != null) {
          placeName = r['name'];
        }
        
        // If we have a place name AND it's not just a road name, use it
        final placeType = r['type']?.toString() ?? '';
        final isNamedPlace = ['university', 'school', 'college', 'hospital', 'mall', 
                               'shopping_centre', 'hotel', 'restaurant', 'cafe', 
                               'building', 'house', 'amenity', 'tourism', 'leisure'].contains(placeType);
        
        if (address != null) {
          // Prioritize relevant address components for Nairobi
          final parts = <String>[];
          
          // FIRST: Add the place name if this is a named location (university, building, etc.)
          if (placeName != null && placeName.isNotEmpty && isNamedPlace) {
            parts.add(placeName);
            relevanceBoost += 0.5; // Boost named places
            debugPrint('🏛️ Named place found: $placeName (type: $placeType)');
          }
          
          // Check for specific location types in address
          if (address['amenity'] != null && !parts.contains(address['amenity'])) {
            parts.add(address['amenity']);
          } else if (address['building'] != null && address['building'] != 'yes') {
            parts.add(address['building']);
          }
          
          // House number/name (only if we don't have a named place already)
          if (parts.isEmpty && address['house_number'] != null) {
            parts.add(address['house_number']);
          }
          
          // Road/Street name (only if we don't already have enough detail)
          if (parts.length < 2) {
            if (address['road'] != null) {
              parts.add(address['road']);
            } else if (address['pedestrian'] != null) {
              parts.add(address['pedestrian']);
            }
          }
          
          // Neighborhood/Suburb/Estate
          if (address['suburb'] != null) {
            final suburb = address['suburb'].toString().toLowerCase();
            parts.add(address['suburb']);
            
            // Boost relevance if it's a well-known Nairobi area
            if (nairobiFamiliarAreas.any((area) => suburb.contains(area))) {
              relevanceBoost += 0.3;
            }
          } else if (address['neighbourhood'] != null) {
            final neighbourhood = address['neighbourhood'].toString().toLowerCase();
            parts.add(address['neighbourhood']);
            
            if (nairobiFamiliarAreas.any((area) => neighbourhood.contains(area))) {
              relevanceBoost += 0.3;
            }
          } else if (address['residential'] != null) {
            parts.add(address['residential']);
          }
          
          // Only add city if it's not already clear from context
          if (parts.length < 2) {
            if (address['city'] != null && address['city'] != 'Nairobi') {
              parts.add(address['city']);
            } else if (address['town'] != null) {
              parts.add(address['town']);
            }
          }
          
          // Add "Nairobi" at the end if not present and it's in Nairobi County
          final hasNairobi = parts.any((p) => p.toLowerCase().contains('nairobi'));
          if (!hasNairobi && (address['county'] == 'Nairobi' || address['city'] == 'Nairobi')) {
            parts.add('Nairobi');
          }
          
          displayName = parts.isNotEmpty ? parts.join(', ') : r['display_name'];
        } else {
          // Fallback: use display_name but clean it up
          String fullName = r['display_name'] ?? '';
          
          // If it's too long, extract just the relevant parts
          final nameParts = fullName.split(',').take(3).toList();
          displayName = nameParts.join(',');
        }
        
        // Limit display name length
        if (displayName.length > 120) {
          displayName = '${displayName.substring(0, 117)}...';
        }
        
        formattedResults.add({
          'name': displayName,
          'display_name': r['display_name'], // Keep original for debugging
          'lat': lat,
          'lon': lon,
          'type': r['type'] ?? 'place',
          'importance': relevanceBoost,
          'distance_from_nairobi': distanceFromNairobi,
        });
      }
      
      // Sort by boosted importance (relevance score + Nairobi area boost)
      formattedResults.sort((a, b) {
        final importanceCompare = (b['importance'] as double).compareTo(a['importance'] as double);
        
        // If importance is similar, prefer closer results
        if (importanceCompare.abs() < 0.1) {
          return (a['distance_from_nairobi'] as double).compareTo(b['distance_from_nairobi'] as double);
        }
        
        return importanceCompare;
      });
      
      debugPrint('✅ Filtered to ${formattedResults.length} relevant Nairobi results');
      
      // Log top results for debugging
      if (formattedResults.isNotEmpty) {
        debugPrint('📍 Top results:');
        final topCount = formattedResults.length < 3 ? formattedResults.length : 3;
        for (int i = 0; i < topCount; i++) {
          final r = formattedResults[i];
          debugPrint('   ${i + 1}. ${r['name']} (${r['distance_from_nairobi'].toStringAsFixed(1)}km)');
        }
      }
      
      // Return top 8 most relevant results
      return formattedResults.take(8).toList();
    } catch (e) {
      debugPrint('❌ Address search error: $e');
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

  // UPDATED: Delivery Fee Logic - uses active location's settings
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

    // Use active location's calculation method if available
    if (_activeLocation != null) {
      return _activeLocation!.calculateDeliveryFee(distance);
    }

    // Fallback to simple tiered pricing if no active location set
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

  // ADDED: Get delivery fee details for display
  String getDeliveryFeeDescription() {
    final fee = deliveryFee;
    if (fee == 0) {
      if (_latitude == null || _longitude == null) {
        return 'Set location';
      }
      return 'Outside delivery area';
    }
    return 'KES $fee';
  }

  String _parseAddress(Map<String, dynamic> data) {
    final address = data['address'] as Map<String, dynamic>?;
    final nameDetails = data['namedetails'] as Map<String, dynamic>?;
    
    // Debug: Print raw address data to see what we're getting
    debugPrint('🏠 Raw address data: $address');
    debugPrint('🏷️ Name details: $nameDetails');
    
    if (address == null) {
      // Use display_name as fallback if no address components
      return data['display_name'] ?? 'Location: ${_latitude?.toStringAsFixed(5)}, ${_longitude?.toStringAsFixed(5)}';
    }

    // IMPROVED: Build very specific address prioritizing PLACE NAME then street-level detail
    final parts = <String>[];
    
    // 0. HIGHEST PRIORITY: Named place (university, hospital, mall, etc.)
    String? placeName;
    if (nameDetails != null && nameDetails['name'] != null) {
      placeName = nameDetails['name'];
    } else if (data['name'] != null) {
      placeName = data['name'];
    }
    
    // Check if this is a named location (not just a road)
    final placeType = data['type']?.toString() ?? '';
    final addressType = data['addresstype']?.toString() ?? '';
    final isNamedPlace = ['university', 'school', 'college', 'hospital', 'clinic',
                           'mall', 'shopping_centre', 'supermarket', 'hotel', 
                           'restaurant', 'cafe', 'bank', 'building', 'house', 
                           'amenity', 'tourism', 'leisure', 'stadium', 'attraction',
                           'theatre', 'cinema', 'library', 'museum'].contains(placeType) ||
                          ['amenity', 'tourism', 'leisure', 'building'].contains(addressType);
    
    // Add place name FIRST if it's a named location
    if (placeName != null && placeName.isNotEmpty && isNamedPlace) {
      parts.add(placeName);
      debugPrint('🏛️ Named place in reverse geocode: $placeName (type: $placeType)');
    }
    
    // Check for amenity or building name in address
    if (parts.isEmpty) {
      if (address['amenity'] != null && address['amenity'].toString().isNotEmpty && 
          address['amenity'] != 'yes') {
        parts.add(address['amenity']);
      } else if (address['building'] != null && address['building'].toString().isNotEmpty && 
                 address['building'] != 'yes') {
        parts.add(address['building']);
      }
    }
    
    // 1. Road/Street name (secondary now, but still important if no place name)
    String? roadName;
    if (parts.isEmpty || parts.length == 1) { // Only add road if we need more detail
      if (address['road'] != null && address['road'].toString().isNotEmpty) {
        roadName = address['road'];
      } else if (address['pedestrian'] != null) {
        roadName = address['pedestrian'];
      } else if (address['footway'] != null) {
        roadName = address['footway'];
      } else if (address['path'] != null) {
        roadName = address['path'];
      }
    }
    
    // 2. Building/House identifier (only if we don't have a named place already)
    if (parts.isEmpty) {
      if (address['house_number'] != null && address['house_number'].toString().isNotEmpty) {
        if (roadName != null) {
          parts.add('${address['house_number']} $roadName');
          roadName = null; // Already used
        } else {
          parts.add('Building ${address['house_number']}');
        }
      } else if (address['house_name'] != null && address['house_name'].toString().isNotEmpty) {
        parts.add(address['house_name']);
      }
    }
    
    // Add road name if not yet added and we need more context
    if (roadName != null && parts.length < 2) {
      parts.add(roadName);
    }
    
    // 3. Neighborhood/Estate/Suburb (secondary but important)
    String? areaName;
    
    // Try multiple fields in order of specificity
    if (address['neighbourhood'] != null && address['neighbourhood'].toString().isNotEmpty) {
      areaName = address['neighbourhood'];
    } else if (address['suburb'] != null && address['suburb'].toString().isNotEmpty) {
      areaName = address['suburb'];
    } else if (address['residential'] != null && address['residential'].toString().isNotEmpty) {
      areaName = address['residential'];
    } else if (address['quarter'] != null && address['quarter'].toString().isNotEmpty) {
      areaName = address['quarter'];
    } else if (address['hamlet'] != null && address['hamlet'].toString().isNotEmpty) {
      areaName = address['hamlet'];
    }
    
    // Only add area if it's different and useful
    if (areaName != null) {
      final areaLower = areaName.toLowerCase();
      
      // Check if area name is not already mentioned
      final alreadyIncluded = parts.any((part) => 
        part.toLowerCase().contains(areaLower) || 
        areaLower.contains(part.toLowerCase())
      );
      
      if (!alreadyIncluded) {
        parts.add(areaName);
      }
    }
    
    // 4. Ward or administrative area (for additional context if we still don't have enough)
    if (parts.length < 2) {
      if (address['city_district'] != null && address['city_district'].toString().isNotEmpty) {
        final district = address['city_district'];
        if (!parts.any((p) => p.toLowerCase().contains(district.toLowerCase()))) {
          parts.add(district);
        }
      } else if (address['municipality'] != null && address['municipality'].toString().isNotEmpty) {
        final municipality = address['municipality'];
        if (!parts.any((p) => p.toLowerCase().contains(municipality.toLowerCase()))) {
          parts.add(municipality);
        }
      }
    }
    
    // 5. Only add city if we still have very little information
    if (parts.length < 2) {
      if (address['city'] != null && address['city'] != 'Nairobi') {
        parts.add(address['city']);
      } else if (address['town'] != null) {
        parts.add(address['town']);
      }
    }
    
    // 6. Add "Nairobi" at the end only if we're in Nairobi and it adds value
    final hasNairobi = parts.any((p) => p.toLowerCase().contains('nairobi'));
    final isInNairobi = address['county'] == 'Nairobi' || 
                        address['state'] == 'Nairobi' || 
                        address['city'] == 'Nairobi';
    
    if (!hasNairobi && isInNairobi && parts.length >= 1) {
      parts.add('Nairobi');
    }
    
    // Final check: if we STILL got nothing useful, use display_name intelligently
    if (parts.isEmpty) {
      final displayName = data['display_name']?.toString() ?? '';
      if (displayName.isNotEmpty) {
        // Extract first 3 meaningful parts (skip country, large regions)
        final nameParts = displayName.split(',')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty && p.toLowerCase() != 'kenya')
          .take(3)
          .toList();
        
        if (nameParts.isNotEmpty) {
          return nameParts.join(', ');
        }
      }
      
      // Absolute last resort: coordinates
      return 'Location: ${_latitude?.toStringAsFixed(5)}, ${_longitude?.toStringAsFixed(5)}';
    }
    
    // Join parts with nice formatting
    String finalAddress = parts.join(', ');
    
    // Ensure reasonable length
    if (finalAddress.length > 120) {
      finalAddress = '${finalAddress.substring(0, 117)}...';
    }
    
    debugPrint('📍 Parsed address: $finalAddress');
    return finalAddress;
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