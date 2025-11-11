// lib/screens/location.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/location_provider.dart';
import '../constants/colors.dart';

class LocationScreen extends StatefulWidget {
  final dynamic initialPosition;

  const LocationScreen({super.key, this.initialPosition});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

// FIXED: Changed to TickerProviderStateMixin instead of SingleTickerProviderStateMixin
class _LocationScreenState extends State<LocationScreen> with TickerProviderStateMixin {
  LatLng? _selectedPoint;
  MapController mapController = MapController();
  bool _isMapReady = false;
  bool _isLoadingLocation = false;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _debounceTimer;
  
  // Store current address locally
  String? _currentAddress;
  bool _isLoadingAddress = false;

  // ADDED: Local state for delivery fee and zone status
  int? _localDeliveryFee; 
  bool _localOutsideZone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMap();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // UPDATED: Better location initialization with permission handling
  void _initializeMap() async {
    if (!mounted) return;

    setState(() => _isLoadingLocation = true);

    final locationProvider = context.read<LocationProvider>();

    try {
      LatLng initialPoint;
      bool locationFound = false;

      if (widget.initialPosition == null) {
        // Force fresh location fetch
        await locationProvider.initializeLocation();

        if (!mounted) return;

        if (locationProvider.latitude != null && locationProvider.longitude != null) {
          initialPoint = LatLng(locationProvider.latitude!, locationProvider.longitude!);
          _currentAddress = locationProvider.deliveryAddress;
          locationFound = true;
        } else {
          initialPoint = const LatLng(
            LocationProvider.defaultLatitude,
            LocationProvider.defaultLongitude,
          );
        }
      } else {
        // Use provided initial position and reverse geocode it
        initialPoint = LatLng(
          widget.initialPosition.latitude ?? LocationProvider.defaultLatitude,
          widget.initialPosition.longitude ?? LocationProvider.defaultLongitude,
        );
        
        // Get address for initial position
        await locationProvider.setLocation(initialPoint.latitude, initialPoint.longitude);
        _currentAddress = locationProvider.deliveryAddress;
        locationFound = true;
      }

      // ADDED: Sync delivery fee and zone status
      _localDeliveryFee = locationProvider.deliveryFee;
      _localOutsideZone = locationProvider.outsideDeliveryArea;
      
      setState(() {
        _selectedPoint = initialPoint;
        _isMapReady = true;
      });

      if (locationFound) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _animatedMapMove(initialPoint, 15.0);
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Error initializing map: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Could not get location: $e'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );

        setState(() {
          _selectedPoint = const LatLng(
            LocationProvider.defaultLatitude,
            LocationProvider.defaultLongitude,
          );
          _isMapReady = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  // ADDED: Animated map move for smoother transitions
  void _animatedMapMove(LatLng destLocation, double destZoom) {
    final camera = mapController.camera;
    final latTween = Tween<double>(
      begin: camera.center.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: camera.center.longitude,
      end: destLocation.longitude,
    );
    final zoomTween = Tween<double>(
      begin: camera.zoom,
      end: destZoom,
    );

    final controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    final Animation<double> animation = CurvedAnimation(
      parent: controller,
      curve: Curves.fastOutSlowIn,
    );

    controller.addListener(() {
      mapController.move(
        LatLng(
          latTween.evaluate(animation),
          lngTween.evaluate(animation),
        ),
        zoomTween.evaluate(animation),
      );
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });

    controller.forward();
  }

  // UPDATED: Improved onMapTap with better address handling
  void _onMapTap(BuildContext context, LatLng point) async {
    final locationProvider = context.read<LocationProvider>();

    setState(() {
      _selectedPoint = point;
      _isLoadingAddress = true;
      _currentAddress = null;
    });

    // Remove any existing snackbar before showing new one
    ScaffoldMessenger.of(context).clearSnackBars();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Expanded(child: Text('Getting address...')),
          ],
        ),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );

    await locationProvider.setLocation(point.latitude, point.longitude);

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      setState(() {
        _currentAddress = locationProvider.deliveryAddress;
        _localDeliveryFee = locationProvider.deliveryFee; // ADDED: Update fee
        _localOutsideZone = locationProvider.outsideDeliveryArea; // ADDED: Update zone
        _isLoadingAddress = false;
      });

      debugPrint('📍 Map tap - Address: $_currentAddress, Fee: $_localDeliveryFee');
    }
  }

  void _confirmLocation(BuildContext context) {
    // FIXED: Check for both address and coordinates
    if (_currentAddress == null || _currentAddress!.isEmpty || _selectedPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text('Please select a location on the map'),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    // FIXED: Return address with coordinates
    debugPrint('✅ Confirming location: $_currentAddress');
    debugPrint('✅ Coordinates: ${_selectedPoint!.latitude}, ${_selectedPoint!.longitude}');
    
    Navigator.pop(context, {
      'address': _currentAddress!,
      'latitude': _selectedPoint!.latitude,
      'longitude': _selectedPoint!.longitude,
      'outsideZone': _localOutsideZone, // ADDED
      'deliveryFee': _localDeliveryFee ?? 0, // ADDED
    });
  }

  // UPDATED: Refresh current location with better feedback
  Future<void> _currentLocationButtonPressed() async {
    setState(() => _isLoadingLocation = true);
    
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Location permissions are permanently denied. Please enable in settings.'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          ),
        );
        setState(() => _isLoadingLocation = false);
        return;
      }

      final locationProvider = context.read<LocationProvider>();
      
      // Clear cached location and force fresh fetch with reverse geocoding
      locationProvider.clearLocation();
      await locationProvider.initializeLocation();
      
      if (!mounted) return;
      
      if (locationProvider.latitude != null && locationProvider.longitude != null) {
        final newPoint = LatLng(locationProvider.latitude!, locationProvider.longitude!);
        
        setState(() {
          _selectedPoint = newPoint;
          _currentAddress = locationProvider.deliveryAddress; // Sync address from provider
          _localDeliveryFee = locationProvider.deliveryFee; // ADDED
          _localOutsideZone = locationProvider.outsideDeliveryArea; // ADDED
        });
        
        _animatedMapMove(newPoint, 16.0); // UPDATED: Zoom in more on current location
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _currentAddress != null && _currentAddress!.isNotEmpty
                        ? 'Location: $_currentAddress'
                        : 'Location updated!',
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Could not get current location. Using default.'),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Error: $e')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  // UPDATED: Faster search with immediate results on Enter/Done
  Future<void> _searchAddress(String query, {bool immediate = false}) async {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer?.cancel();
    }
    
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    // ADDED: If immediate (from Enter/Done), search right away
    if (immediate) {
      await _performSearch(query);
      return;
    }
    
    // Otherwise, debounce for typing
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async { // REDUCED: from 500ms to 300ms
      await _performSearch(query);
    });
  }

  // ADDED: Extracted search logic
  Future<void> _performSearch(String query) async {
    final locationProvider = context.read<LocationProvider>();
    final results = await locationProvider.searchAddress(query);
    
    if (mounted) {
      setState(() {
        _searchResults = results;
      });
    }
  }

  // UPDATED: Better result selection with immediate address update
  Future<void> _selectSearchResult(Map<String, dynamic> result) async {
    final locationProvider = context.read<LocationProvider>();
    
    final lat = result['lat'] as double;
    final lon = result['lon'] as double;
    final displayName = result['name'] as String;

    setState(() {
      _searchResults = [];
      _searchController.clear();
      _selectedPoint = LatLng(lat, lon);
      _currentAddress = displayName;
      _isLoadingAddress = false;
    });
    
    _animatedMapMove(_selectedPoint!, 16.0);
    
    locationProvider.setLocation(lat, lon).then((_) {
      if (mounted) {
        setState(() {
          _localDeliveryFee = locationProvider.deliveryFee; // ADDED
          _localOutsideZone = locationProvider.outsideDeliveryArea; // ADDED
        });

        final reverseAddress = locationProvider.deliveryAddress;
        if (reverseAddress != null && reverseAddress.length < displayName.length && reverseAddress.isNotEmpty) {
          setState(() {
            _currentAddress = reverseAddress;
          });
        }
      }
    });
  }

  Widget _buildAddressCard(LocationProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Location Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on,
              size: 28,
              color: AppColors.primary,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // UPDATED: Address Text using local state
          Text(
            _isLoadingAddress
                ? "🔄 Getting address..."
                : (_currentAddress ?? "📍 Tap on map to select location"),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: _currentAddress == null 
                  ? Colors.grey 
                  : AppColors.darkText,
            ),
          ),
          
          // ADDED: Display Delivery Fee or Warning
          if (_selectedPoint != null && !_isLoadingAddress) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _localOutsideZone 
                    ? Colors.red.withOpacity(0.1) 
                    : AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _localOutsideZone 
                    ? '🚫 Outside ${LocationProvider.maxDeliveryDistanceKm.toStringAsFixed(1)}km Delivery Zone'
                    : '🚚 Delivery Fee: KES ${_localDeliveryFee ?? 0}',
                style: TextStyle(
                  color: _localOutsideZone ? Colors.red : AppColors.success,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],

          // Error message if any
          if (provider.error != null) ...[
            const SizedBox(height: 8),
            Text(
              provider.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.red,
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          // Action Buttons
          Row(
            children: [
              // Current Location Button
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: _isLoadingLocation ? null : _currentLocationButtonPressed,
                  icon: _isLoadingLocation
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location, size: 18),
                  label: Text(_isLoadingLocation ? 'Loading...' : 'Current'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Confirm Button
              Expanded(
                flex: 3,
                child: ElevatedButton(
                  onPressed: (_currentAddress == null || _currentAddress!.isEmpty || _isLoadingAddress || _selectedPoint == null)
                      ? null
                      : () => _confirmLocation(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoadingAddress
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Confirm Location',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<LocationProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Select Delivery Location'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        actions: [
          // Refresh button
          IconButton(
            icon: _isLoadingLocation 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isLoadingLocation ? null : _currentLocationButtonPressed,
            tooltip: 'Refresh Location',
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delivery Area'),
                  content: const Text(
                    'We deliver within 5km radius from Madaraka, Nairobi. '
                    'Tap on the map to select your exact delivery location or search for an address.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Search field at top
          if (_isMapReady)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: AppColors.white,
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Search field with Enter/Done button support
                    TextField(
                      controller: _searchController,
                      onChanged: (value) => _searchAddress(value),
                      onSubmitted: (value) => _searchAddress(value, immediate: true),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search location (e.g. Moi Avenue, Nairobi)',
                        hintStyle: const TextStyle(fontSize: 14),
                        prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_forward, color: AppColors.primary),
                                    onPressed: () => _searchAddress(_searchController.text, immediate: true),
                                    tooltip: 'Search',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      setState(() {
                                        _searchController.clear();
                                        _searchResults = [];
                                      });
                                    },
                                  ),
                                ],
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    
                    // Search results dropdown
                    if (_searchResults.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final result = _searchResults[index];
                            return ListTile(
                              leading: const Icon(Icons.location_on, color: AppColors.primary, size: 20),
                              title: Text(
                                result['display_name'],
                                style: const TextStyle(fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => _selectSearchResult(result),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // Outside delivery zone warning
          if (_isMapReady && provider.outsideDeliveryArea)
            Positioned(
              top: _searchResults.isNotEmpty ? 220 : 80,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You are outside our delivery area (5km radius)',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Map
          Positioned.fill(
            top: _searchResults.isNotEmpty ? 220 : 80,
            child: _isMapReady
                ? FlutterMap(
                    mapController: mapController,
                    options: MapOptions(
                      initialCenter: _selectedPoint ?? 
                          const LatLng(
                            LocationProvider.defaultLatitude,
                            LocationProvider.defaultLongitude,
                          ),
                      initialZoom: 15.0,
                      onTap: (tapPosition, point) => _onMapTap(context, point),
                      interactionOptions: const InteractionOptions(
                        flags: ~InteractiveFlag.rotate,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                        userAgentPackageName: 'com.yourapp.fooddelivery',
                        subdomains: const ['a', 'b', 'c'],
                      ),
                      
                      // Delivery radius circle (5km)
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: const LatLng(
                              LocationProvider.defaultLatitude,
                              LocationProvider.defaultLongitude,
                            ),
                            color: AppColors.primary.withOpacity(0.2),
                            borderColor: AppColors.primary.withOpacity(0.5),
                            borderStrokeWidth: 2,
                            useRadiusInMeter: true,
                            radius: 5000,
                          ),
                        ],
                      ),
                      
                      // Restaurant location marker
                      const MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(
                              LocationProvider.defaultLatitude,
                              LocationProvider.defaultLongitude,
                            ),
                            width: 40,
                            height: 40,
                            child: Icon(Icons.restaurant, color: Colors.red, size: 30),
                          ),
                        ],
                      ),
                      
                      // Selected location marker
                      if (_selectedPoint != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _selectedPoint!,
                              width: 50,
                              height: 50,
                              alignment: Alignment.center,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: AppColors.accent.withOpacity(0.3),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const Icon(Icons.location_on, color: AppColors.accent, size: 35),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  )
                : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading map...'),
                      ],
                    ),
                  ),
          ),
          
          // Current Location FAB
          if (_isMapReady)
            Positioned(
              right: 16,
              bottom: 140,
              child: FloatingActionButton(
                onPressed: _isLoadingLocation ? null : _currentLocationButtonPressed,
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                mini: true,
                child: _isLoadingLocation
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
              ),
            ),
          
          // Address Card
          if (_isMapReady)
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildAddressCard(provider),
            ),
        ],
      ),
    );
  }
}