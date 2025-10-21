// lib/providers/location_provider.dart
import 'package:flutter/material.dart';

class LocationProvider with ChangeNotifier {
  double? _latitude;
  double? _longitude;
  String? _deliveryAddress;

  double? get latitude => _latitude;
  double? get longitude => _longitude;
  String? get deliveryAddress => _deliveryAddress;

  Future<void> setLocation(double latitude, double longitude) async {
    _latitude = latitude;
    _longitude = longitude;
    notifyListeners();
  }

  void setDeliveryAddress(String address) {
    _deliveryAddress = address;
    notifyListeners();
  }

  void clearLocation() {
    _latitude = null;
    _longitude = null;
    _deliveryAddress = null;
    notifyListeners();
  }
}