// lib/screens/location.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
// ignore: unused_import
import 'package:geolocator/geolocator.dart';
import '../providers/location_provider.dart';
import '../constants/colors.dart';

class LocationScreen extends StatefulWidget {
  final dynamic initialPosition;

  const LocationScreen({super.key, this.initialPosition});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  LatLng? _selectedPoint;
  MapController mapController = MapController();
  bool _isMapReady = false;
  final TextEditingController _searchController = TextEditingController(); // ADDED
  List<Map<String, dynamic>> _searchResults = []; // ADDED

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMap();
    });
  }

  @override
  void dispose() {
    _searchController.dispose(); // ADDED
    super.dispose();
  }

  void _initializeMap() async {
    // FIXED: Check if widget is still mounted
    if (!mounted) return;
    
    final locationProvider = context.read<LocationProvider>();
    
    // If no initial position, get current location
    if (widget.initialPosition == null) {
      await locationProvider.initializeLocation();
      
      // FIXED: Check mounted again after async operation
      if (!mounted) return;
      
      if (locationProvider.latitude != null && locationProvider.longitude != null) {
        setState(() {
          _selectedPoint = LatLng(locationProvider.latitude!, locationProvider.longitude!);
        });
        
        // Center map on current location
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            mapController.move(_selectedPoint!, 15.0);
          }
        });
      }
    } else {
      // Use provided initial position
      setState(() {
        _selectedPoint = LatLng(
          widget.initialPosition.latitude ?? LocationProvider.defaultLatitude,
          widget.initialPosition.longitude ?? LocationProvider.defaultLongitude,
        );
      });
    }
    
    setState(() {
      _isMapReady = true;
    });
  }

  void _onMapTap(BuildContext context, LatLng point) async {
    final locationProvider = context.read<LocationProvider>();

    setState(() {
      _selectedPoint = point;
    });

    await locationProvider.setLocation(point.latitude, point.longitude);
  }

  void _confirmLocation(BuildContext context) {
    final provider = context.read<LocationProvider>();
    
    if (provider.deliveryAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a location on the map'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.pop(context, {
      'address': provider.deliveryAddress!,
      'latitude': provider.latitude,
      'longitude': provider.longitude,
    });
  }

  void _currentLocationButtonPressed() async {
    final locationProvider = context.read<LocationProvider>();
    await locationProvider.initializeLocation();
    
    if (locationProvider.latitude != null && locationProvider.longitude != null) {
      setState(() {
        _selectedPoint = LatLng(locationProvider.latitude!, locationProvider.longitude!);
      });
      
      mapController.move(_selectedPoint!, 15.0);
    }
  }

  // ADDED: Search address and update map
  Future<void> _searchAddress(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    final locationProvider = context.read<LocationProvider>();
    final results = await locationProvider.searchAddress(query);
    
    setState(() {
      _searchResults = results;
    });
  }

  // ADDED: Select search result
  void _selectSearchResult(Map<String, dynamic> result) async {
    final locationProvider = context.read<LocationProvider>();
    
    final lat = result['lat'] as double;
    final lon = result['lon'] as double;
    
    await locationProvider.setLocation(lat, lon);
    
    setState(() {
      _selectedPoint = LatLng(lat, lon);
      _searchResults = [];
      _searchController.clear();
    });
    
    mapController.move(_selectedPoint!, 15.0);
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
            child: Icon(
              Icons.location_on,
              size: 28,
              color: AppColors.primary,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Address Text
          Text(
            provider.isLoading
                ? "🔄 Getting address..."
                : (provider.deliveryAddress ?? "📍 Tap on map to select location"),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: provider.deliveryAddress == null 
                  ? Colors.grey 
                  : AppColors.darkText,
            ),
          ),
          
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
                  onPressed: _currentLocationButtonPressed,
                  icon: const Icon(Icons.my_location, size: 18),
                  label: const Text('Current'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Confirm Button
              Expanded(
                flex: 3,
                child: ElevatedButton(
                  onPressed: provider.deliveryAddress == null || provider.isLoading
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
                  child: provider.isLoading
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
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delivery Area'),
                  content: const Text(
                    'We deliver within 5km radius from Madaraka, Nairobi. '
                    'Tap on the map to select your exact delivery location.',
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
          // ADDED: Search field at top
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
                    TextField(
                      controller: _searchController,
                      onChanged: _searchAddress,
                      decoration: InputDecoration(
                        hintText: 'Search location (e.g. Moi Avenue)',
                        prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchResults = [];
                                  });
                                },
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
                    
                    // ADDED: Search results dropdown
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
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final result = _searchResults[index];
                            return ListTile(
                              leading: const Icon(Icons.location_on, color: AppColors.primary, size: 20),
                              title: Text(
                                result['name'],
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

          // ADDED: Outside delivery zone warning
          if (_isMapReady && provider.outsideDeliveryArea)
            Positioned(
              top: _searchResults.isNotEmpty ? 200 : 80,
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
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You are outside our delivery area (5km radius)',
                        style: const TextStyle(
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
          _isMapReady
              ? Positioned.fill(
                  top: 80, // ADDED: Offset for search field
                  child: FlutterMap(
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
                            radius: 5000, // 5km in meters
                          ),
                        ],
                      ),
                      
                      // Restaurant location marker
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: const LatLng(
                              LocationProvider.defaultLatitude,
                              LocationProvider.defaultLongitude,
                            ),
                            width: 40,
                            height: 40,
                            child: const Icon(Icons.restaurant, color: Colors.red, size: 30),
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
                  ),
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
          
          // Current Location FAB
          if (_isMapReady)
            Positioned(
              right: 16,
              bottom: 120,
              child: FloatingActionButton(
                onPressed: _currentLocationButtonPressed,
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                mini: true,
                child: const Icon(Icons.my_location),
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