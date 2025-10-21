// lib/screens/location.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import '../constants/colors.dart';

class LocationScreen extends StatefulWidget {
  final Position? initialPosition;

  const LocationScreen({super.key, this.initialPosition});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  LatLng? _selectedLocation;
  String? _selectedAddress;
  bool _isLoading = true;
  bool _permissionGranted = false;
  CameraPosition? _initialCameraPosition;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialPosition != null) {
      final pos = widget.initialPosition!;
      _initialCameraPosition = CameraPosition(
        target: LatLng(pos.latitude, pos.longitude),
        zoom: 14.0,
      );
      _selectedLocation = LatLng(pos.latitude, pos.longitude);
      _permissionGranted = true;
      _isLoading = false;
      _getAddressFromLatLng(_selectedLocation!); // pre-fill address
    } else {
      // default: Nairobi
      _initialCameraPosition = const CameraPosition(
        target: LatLng(-1.2921, 36.8219),
        zoom: 10.0,
      );
      _determinePosition();
    }
  }

  Future<void> _determinePosition() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoading = false;
          _error = 'Location services are disabled. Please enable them.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoading = false;
            _error = 'Location permissions are denied.';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoading = false;
          _error =
              'Location permissions are permanently denied. Please enable them from settings.';
        });
        return;
      }

      final Position position = await Geolocator.getCurrentPosition();
      if (!mounted) return;

      final camera = CameraPosition(
        target: LatLng(position.latitude, position.longitude),
        zoom: 14.0,
      );

      setState(() {
        _initialCameraPosition = camera;
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _permissionGranted = true;
        _isLoading = false;
      });

      // fetch human-readable address
      await _getAddressFromLatLng(_selectedLocation!);

      // animate if controller already available
      if (_controller.isCompleted) {
        final c = await _controller.future;
        c.animateCamera(CameraUpdate.newCameraPosition(camera));
      }
    } catch (e, st) {
      debugPrint('Location error: $e\n$st');
      setState(() {
        _isLoading = false;
        _error = 'Failed to obtain location: $e';
      });
    }
  }

  Future<void> _getAddressFromLatLng(LatLng pos) async {
    setState(() {
      _selectedAddress = null;
    });
    try {
      final placemarks = await geocoding.placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        // build a concise address; tune to your needs
        final street = p.street ?? '';
        final locality = p.locality ?? p.subAdministrativeArea ?? '';
        final country = p.country ?? '';
        final composed = [street, locality, country].where((s) => s.isNotEmpty).join(', ');
        setState(() {
          _selectedAddress = composed.isNotEmpty ? composed : 'Unknown address';
        });
      } else {
        setState(() {
          _selectedAddress = 'No address found';
        });
      }
    } catch (e) {
      debugPrint('Reverse geocoding failed: $e');
      setState(() {
        _selectedAddress = 'Failed to get address';
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) async {
    if (!_controller.isCompleted) _controller.complete(controller);

    if (_selectedLocation != null) {
      try {
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(_selectedLocation!, 14.0),
        );
      } catch (e) {
        debugPrint('animateCamera failed: $e');
      }
    } else if (_initialCameraPosition != null) {
      try {
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(_initialCameraPosition!),
        );
      } catch (e) {
        debugPrint('animateCamera failed: $e');
      }
    }
  }

  void _onMapTapped(LatLng location) async {
    setState(() {
      _selectedLocation = location;
      _selectedAddress = null; // will be filled shortly
    });
    await _getAddressFromLatLng(location);
  }

  void _confirmLocation() {
    if (_selectedLocation != null) {
      // return both LatLng + address
      Navigator.pop(context, {
        'latLng': _selectedLocation!,
        'address': _selectedAddress ?? '',
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location on the map.')),
      );
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    await _determinePosition();
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                onPressed: _determinePosition,
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.location_on),
                label: const Text('Use Default Area'),
                onPressed: () {
                  setState(() {
                    _error = null;
                    // keep initial camera position (already set to default)
                  });
                },
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: _initialCameraPosition!,
          onTap: _onMapTapped,
          myLocationEnabled: _permissionGranted,
          myLocationButtonEnabled: false,
          markers: _selectedLocation != null
              ? {
                  Marker(
                    markerId: const MarkerId('selectedLocation'),
                    position: _selectedLocation!,
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                  ),
                }
              : {},
        ),

        // Floating action to re-center on current location
        Positioned(
          top: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: _useCurrentLocation,
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.my_location, color: Colors.white),
          ),
        ),

        // address overlay
        if (_selectedAddress != null)
          Positioned(
            top: 16,
            left: 16,
            right: 96, // leave room for FAB on right
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
              ),
              child: Text(
                _selectedAddress!,
                style: const TextStyle(fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

        // confirm button
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: ElevatedButton(
            onPressed: _confirmLocation,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Confirm Location'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Select Delivery Location'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: _buildBody(),
    );
  }
}
