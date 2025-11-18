// lib/providers/address_provider.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/user_address.dart';
import '../models/location.dart';

class AddressProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  List<UserAddress> _addresses = [];
  UserAddress? _defaultAddress;
  bool _isLoading = false;
  String? _error;

  List<UserAddress> get addresses => _addresses;
  UserAddress? get defaultAddress => _defaultAddress;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load all addresses for the current user
  Future<void> loadAddresses({String? userId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final authUserId = userId ?? _supabase.auth.currentUser?.id;
      if (authUserId == null) {
        throw Exception('No user logged in');
      }

      debugPrint('📍 Loading addresses for user: $authUserId');

      final response = await _supabase
          .from('UserAddresses')
          .select()
          .eq('user_auth_id', authUserId)
          .order('is_default', ascending: false)
          .order('created_at', ascending: false);

      _addresses = (response as List)
          .map((json) => UserAddress.fromJson(json))
          .toList();

      _defaultAddress = _addresses.firstWhere(
        (addr) => addr.isDefault,
        orElse: () => _addresses.isNotEmpty ? _addresses.first : UserAddress(
          id: '',
          userAuthId: authUserId,
          label: '',
          latitude: 0,
          longitude: 0,
          descriptiveDirections: '',
          isDefault: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      debugPrint('✅ Loaded ${_addresses.length} addresses');
      if (_defaultAddress != null && _defaultAddress!.id.isNotEmpty) {
        debugPrint('✅ Default address: ${_defaultAddress!.label}');
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error loading addresses: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add a new address
  Future<UserAddress?> addAddress({
    required String label,
    required double latitude,
    required double longitude,
    required String descriptiveDirections,
    String? streetAddress,
    bool setAsDefault = false,
  }) async {
    try {
      final authUserId = _supabase.auth.currentUser?.id;
      if (authUserId == null) {
        throw Exception('No user logged in');
      }

      debugPrint('📍 Adding new address: $label');

      // If setting as default, unset other defaults first
      if (setAsDefault) {
        await _supabase
            .from('UserAddresses')
            .update({'is_default': false})
            .eq('user_auth_id', authUserId)
            .eq('is_default', true);
      }

      final response = await _supabase
          .from('UserAddresses')
          .insert({
            'user_auth_id': authUserId,
            'label': label,
            'latitude': latitude,
            'longitude': longitude,
            'descriptive_directions': descriptiveDirections,
            'street_address': streetAddress,
            'is_default': setAsDefault || _addresses.isEmpty, // First address is default
          })
          .select()
          .single();

      final newAddress = UserAddress.fromJson(response);
      _addresses.insert(0, newAddress);

      if (newAddress.isDefault) {
        _defaultAddress = newAddress;
      }

      debugPrint('✅ Address added successfully');
      notifyListeners();
      return newAddress;
    } catch (e) {
      debugPrint('❌ Error adding address: $e');
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Update an existing address
  Future<bool> updateAddress({
    required String addressId,
    String? label,
    double? latitude,
    double? longitude,
    String? descriptiveDirections,
    String? streetAddress,
    bool? isDefault,
  }) async {
    try {
      final authUserId = _supabase.auth.currentUser?.id;
      if (authUserId == null) {
        throw Exception('No user logged in');
      }

      debugPrint('📍 Updating address: $addressId');

      // If setting as default, unset other defaults first
      if (isDefault == true) {
        await _supabase
            .from('UserAddresses')
            .update({'is_default': false})
            .eq('user_auth_id', authUserId)
            .eq('is_default', true);
      }

      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (label != null) updateData['label'] = label;
      if (latitude != null) updateData['latitude'] = latitude;
      if (longitude != null) updateData['longitude'] = longitude;
      if (descriptiveDirections != null) updateData['descriptive_directions'] = descriptiveDirections;
      if (streetAddress != null) updateData['street_address'] = streetAddress;
      if (isDefault != null) updateData['is_default'] = isDefault;

      await _supabase
          .from('UserAddresses')
          .update(updateData)
          .eq('id', addressId)
          .eq('user_auth_id', authUserId);

      // Reload to reflect changes
      await loadAddresses();
      debugPrint('✅ Address updated successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating address: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Delete an address
  Future<bool> deleteAddress(String addressId) async {
    try {
      final authUserId = _supabase.auth.currentUser?.id;
      if (authUserId == null) {
        throw Exception('No user logged in');
      }

      debugPrint('📍 Deleting address: $addressId');

      final addressToDelete = _addresses.firstWhere(
        (addr) => addr.id == addressId,
        orElse: () => throw Exception('Address not found'),
      );

      await _supabase
          .from('UserAddresses')
          .delete()
          .eq('id', addressId)
          .eq('user_auth_id', authUserId);

      _addresses.removeWhere((addr) => addr.id == addressId);

      // If deleted address was default, set another as default
      if (addressToDelete.isDefault && _addresses.isNotEmpty) {
        await setDefaultAddress(_addresses.first.id);
      } else if (_addresses.isEmpty) {
        _defaultAddress = null;
      }

      debugPrint('✅ Address deleted successfully');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting address: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Set an address as default
  Future<bool> setDefaultAddress(String addressId) async {
    try {
      final authUserId = _supabase.auth.currentUser?.id;
      if (authUserId == null) {
        throw Exception('No user logged in');
      }

      debugPrint('📍 Setting default address: $addressId');

      // Unset all other defaults
      await _supabase
          .from('UserAddresses')
          .update({'is_default': false})
          .eq('user_auth_id', authUserId)
          .eq('is_default', true);

      // Set new default
      await _supabase
          .from('UserAddresses')
          .update({
            'is_default': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', addressId)
          .eq('user_auth_id', authUserId);

      // Update local state
      for (var addr in _addresses) {
        if (addr.id == addressId) {
          _defaultAddress = addr.copyWith(isDefault: true);
        }
      }

      debugPrint('✅ Default address set successfully');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Error setting default address: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Get address by ID
  UserAddress? getAddressById(String addressId) {
    try {
      return _addresses.firstWhere((addr) => addr.id == addressId);
    } catch (e) {
      return null;
    }
  }

  /// Calculate distance between address and location (in kilometers)
  Future<double> calculateDistanceToLocation({
    required UserAddress address,
    required Location location,
  }) async {
    if (location.lat == null || location.lon == null) {
      throw Exception('Location coordinates not available');
    }

    final distanceInMeters = Geolocator.distanceBetween(
      address.latitude,
      address.longitude,
      location.lat!,
      location.lon!,
    );

    return distanceInMeters / 1000; // Convert to kilometers
  }

  /// Check if address is within location's delivery zone
  Future<bool> isAddressInDeliveryZone({
    required UserAddress address,
    required Location location,
  }) async {
    try {
      final distance = await calculateDistanceToLocation(
        address: address,
        location: location,
      );

      return location.canDeliverTo(distance);
    } catch (e) {
      debugPrint('❌ Error checking delivery zone: $e');
      return false;
    }
  }

  /// Calculate delivery fee for address from location
  Future<int?> calculateDeliveryFee({
    required UserAddress address,
    required Location location,
  }) async {
    try {
      final distance = await calculateDistanceToLocation(
        address: address,
        location: location,
      );

      final fee = location.calculateDeliveryFee(distance);
      
      if (fee == -1) {
        // Outside delivery zone
        return null;
      }

      return fee;
    } catch (e) {
      debugPrint('❌ Error calculating delivery fee: $e');
      return null;
    }
  }

  /// Get delivery info for an address from a location
  Future<DeliveryZoneInfo> getDeliveryInfo({
    required UserAddress address,
    required Location location,
  }) async {
    try {
      final distance = await calculateDistanceToLocation(
        address: address,
        location: location,
      );

      final inZone = location.canDeliverTo(distance);
      final fee = inZone ? location.calculateDeliveryFee(distance) : null;

      return DeliveryZoneInfo(
        distance: distance,
        isInZone: inZone,
        deliveryFee: fee,
        deliveryRadius: location.deliveryRadiusKm,
      );
    } catch (e) {
      debugPrint('❌ Error getting delivery info: $e');
      return DeliveryZoneInfo(
        distance: 0,
        isInZone: false,
        deliveryFee: null,
        deliveryRadius: location.deliveryRadiusKm,
      );
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

/// Helper class for delivery zone information
class DeliveryZoneInfo {
  final double distance; // in kilometers
  final bool isInZone;
  final int? deliveryFee; // null if outside zone
  final double? deliveryRadius;

  DeliveryZoneInfo({
    required this.distance,
    required this.isInZone,
    this.deliveryFee,
    this.deliveryRadius,
  });

  String get distanceDisplay => '${distance.toStringAsFixed(1)} km';

  String get statusMessage {
    if (!isInZone) {
      if (deliveryRadius != null) {
        return 'Outside delivery zone (${deliveryRadius!.toStringAsFixed(1)} km radius)';
      }
      return 'Outside delivery zone';
    }
    return 'Within delivery zone';
  }
}
