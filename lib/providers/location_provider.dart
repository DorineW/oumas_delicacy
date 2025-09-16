import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationProvider with ChangeNotifier {
  Position? _currentPosition;
  String? _deliveryAddress;

  Position? get currentPosition => _currentPosition;
  String? get deliveryAddress => _deliveryAddress;

  Future<void> setLocation(Position position) async {
    _currentPosition = position;
    notifyListeners();
  }

  void setDeliveryAddress(String address) {
    _deliveryAddress = address;
    notifyListeners();
  }

  void clearLocation() {
    _currentPosition = null;
    _deliveryAddress = null;
    notifyListeners();
  }
}