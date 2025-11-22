// lib/screens/location.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/location_provider.dart';
import '../providers/location_management_provider.dart'; // ADDED
import '../providers/connectivity_provider.dart';
import '../widgets/no_connection_screen.dart';
import '../constants/colors.dart';

class LocationScreen extends StatefulWidget {
  final Map<String, double>? initialPosition;

  const LocationScreen({super.key, this.initialPosition});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

// FIXED: Changed to TickerProviderStateMixin instead of SingleTickerProviderStateMixin
class _LocationScreenState extends State<LocationScreen> with TickerProviderStateMixin {
  MapController mapController = MapController();
  bool _isMapReady = false;
  bool _isLoadingLocation = false;
  bool _hasInitializationError = false;
  bool _isProcessingTap = false;
  Completer<void>? _currentOperation;
  AnimationController? _moveController;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounceTimer;
  bool _isLoadingAddress = false;

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
    _currentOperation?.completeError('Disposed');
    _moveController?.dispose();
    super.dispose();
  }

  // UPDATED: Better location initialization with permission handling and active location loading
  void _initializeMap() async {
    if (!mounted) return;
    setState(() {
      _isLoadingLocation = true;
      _hasInitializationError = false;
    });
    try {
      final locationProvider = context.read<LocationProvider>();
      final locationManagementProvider = context.read<LocationManagementProvider>();
      
      // Load locations from database if not already loaded
      if (locationManagementProvider.locations.isEmpty) {
        await locationManagementProvider.loadLocations();
      }
      
      // Set the first active location as the restaurant location
      final activeLocations = locationManagementProvider.activeLocations;
      if (activeLocations.isNotEmpty && mounted) {
        final firstLocation = activeLocations.first;
        locationProvider.setActiveLocation(firstLocation);
        debugPrint('📍 Active location loaded: ${firstLocation.name}');
      }
      
      // await locationProvider.ensureLocationServices?.call();
      if (!mounted) return;
      LatLng initialPoint;
      if (widget.initialPosition != null) {
        initialPoint = LatLng(
          widget.initialPosition!['latitude'] ?? -1.303960,
          widget.initialPosition!['longitude'] ?? 36.790900,
        );
      } else {
        await locationProvider.initializeLocation();
        if (locationProvider.latitude != null && locationProvider.longitude != null) {
          initialPoint = LatLng(locationProvider.latitude!, locationProvider.longitude!);
        } else {
          initialPoint = const LatLng(
            -1.303960,
            36.790900,
          );
        }
      }
      if (!mounted) return;
      setState(() => _isMapReady = true);
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) _animatedMapMove(initialPoint, 15.0);
    } catch (e) {
      debugPrint('Map initialization error: $e');
      if (mounted) {
        setState(() {
          _isMapReady = true;
          _hasInitializationError = true;
        });
        _showErrorSnackBar('Failed to initialize map: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
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
    _moveController?.dispose();
    _moveController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    final Animation<double> animation = CurvedAnimation(
      parent: _moveController!,
      curve: Curves.fastOutSlowIn,
    );
    _moveController!.addListener(() {
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
        _moveController?.dispose();
        _moveController = null;
      }
    });
    _moveController!.forward();
  }

  // UPDATED: Improved onMapTap with better address handling
  void _onMapTap(BuildContext context, LatLng point) async {
    if (!mounted || _isProcessingTap) return;
    _isProcessingTap = true;
    final locationProvider = context.read<LocationProvider>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() { _isLoadingAddress = true; });
    messenger.clearSnackBars();
    messenger.showSnackBar(
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
      messenger.clearSnackBars();
      setState(() { _isLoadingAddress = false; });
      debugPrint('📍 Map tap - Address: ${locationProvider.deliveryAddress}, Fee: ${locationProvider.deliveryFee}');
    }
    _isProcessingTap = false;
  }

  void _confirmLocation(BuildContext context) {
    if (!mounted) return;
    
    final locationProvider = context.read<LocationProvider>();
    
    // Check for both address and coordinates from provider
    if (locationProvider.deliveryAddress == null || 
        locationProvider.deliveryAddress!.isEmpty || 
        locationProvider.latitude == null || 
        locationProvider.longitude == null) {
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

    debugPrint('✅ Confirming location: ${locationProvider.deliveryAddress}');
    debugPrint('✅ Coordinates: ${locationProvider.latitude}, ${locationProvider.longitude}');
    
    Navigator.pop(context, {
      'address': locationProvider.deliveryAddress!,
      'latitude': locationProvider.latitude!,
      'longitude': locationProvider.longitude!,
      'outsideZone': locationProvider.outsideDeliveryArea,
      'deliveryFee': locationProvider.deliveryFee,
    });
  }

  // UPDATED: Refresh current location with better feedback
  Future<void> _currentLocationButtonPressed() async {
    if (!mounted) return;
    
    setState(() => _isLoadingLocation = true);
    
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Enable Location Access'),
            content: const Text('Location permissions are permanently denied. Please enable them in app settings.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await Geolocator.openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
        if (mounted) {
          setState(() => _isLoadingLocation = false);
        }
        return;
      }

      // If location services are disabled, prompt to enable
      final servicesEnabled = await Geolocator.isLocationServiceEnabled();
      if (!servicesEnabled) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Turn On Location'),
            content: const Text('Location services are disabled. Turn on location to get your current position.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Not Now')),
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await Geolocator.openLocationSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }

      final locationProvider = context.read<LocationProvider>();
      final messenger = ScaffoldMessenger.of(context);
      
      // Clear cached location and force fresh fetch with reverse geocoding
      locationProvider.clearLocation();
      await locationProvider.initializeLocation();
      
      if (!mounted) return;
      
      if (locationProvider.latitude != null && locationProvider.longitude != null) {
        final newPoint = LatLng(locationProvider.latitude!, locationProvider.longitude!);
        
        _animatedMapMove(newPoint, 16.0); // UPDATED: Zoom in more on current location
        
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    locationProvider.deliveryAddress != null && locationProvider.deliveryAddress!.isNotEmpty
                        ? 'Location: ${locationProvider.deliveryAddress}'
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

        messenger.showSnackBar(
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

      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
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
    if (!mounted) return;
    
    // Cancel any existing timer
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer?.cancel();
    }
    
    if (query.isEmpty) {
      if (mounted) {
        setState(() => _searchResults = []);
      }
      return;
    }

    // ADDED: If immediate (from Enter/Done), search right away
    if (immediate) {
      await _performSearch(query);
      return;
    }
    
    // Otherwise, debounce for typing
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      await _performSearch(query);
    });
  }

  // FIXED: Extracted search logic with proper Completer management
  Future<void> _performSearch(String query) async {
    if (!mounted || query.isEmpty) return;
    
    // Cancel previous operation if still pending
    if (_currentOperation != null && !_currentOperation!.isCompleted) {
      _currentOperation!.completeError('Cancelled');
    }
    
    setState(() => _isSearching = true);
    
    // Create new completer for this search
    _currentOperation = Completer<void>();
    
    try {
      final locationProvider = context.read<LocationProvider>();
      final results = await locationProvider.searchAddress(query);
      
      // Check if this operation was cancelled
      if (!mounted || (_currentOperation?.isCompleted ?? true)) {
        return;
      }
      
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
      
      if (results.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.search_off, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('No results found. Try a different search term.')),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      // Complete this operation
      if (!_currentOperation!.isCompleted) {
        _currentOperation!.complete();
      }
    } catch (e) {
      debugPrint('❌ Search error: $e');
      
      if (mounted) {
        setState(() => _isSearching = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Search failed: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
      
      // Complete with error if not already completed
      if (_currentOperation != null && !_currentOperation!.isCompleted) {
        _currentOperation!.completeError(e);
      }
    }
  }

  // UPDATED: Better result selection with immediate address update
  Future<void> _selectSearchResult(Map<String, dynamic> result) async {
    if (!mounted) return;
    
    final locationProvider = context.read<LocationProvider>();
    
    final lat = result['lat'] as double;
    final lon = result['lon'] as double;
    final name = result['name'] as String; // Use cleaned name, not full display_name

    debugPrint('✅ User selected: $name at ($lat, $lon)');

    setState(() {
      _searchResults = [];
      _searchController.clear();
      _isLoadingAddress = false;
    });
    
    final selectedPoint = LatLng(lat, lon);
    _animatedMapMove(selectedPoint, 17.0); // Zoom in closer
    
    // Use the cleaned name from search results
    locationProvider.setLocationWithAddress(lat, lon, name);
    
    // Show confirmation
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Location set: $name'),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
    }
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
          
          // UPDATED: Address Text using provider state as single source of truth
          Text(
            _isLoadingAddress
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
          
          // ADDED: Display Delivery Fee or Warning
          if (provider.latitude != null && !_isLoadingAddress) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: provider.outsideDeliveryArea 
                    ? Colors.red.withOpacity(0.1) 
                    : AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                provider.outsideDeliveryArea 
                    ? '🚫 Outside Delivery Zone'
                    : '🚚 Delivery Fee: KES ${provider.deliveryFee}',
                style: TextStyle(
                  color: provider.outsideDeliveryArea ? Colors.red : AppColors.success,
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
                  onPressed: (provider.deliveryAddress == null || provider.deliveryAddress!.isEmpty || _isLoadingAddress || provider.latitude == null)
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
    final connectivity = context.watch<ConnectivityProvider>();
    if (!connectivity.isConnected) {
      return NoConnectionScreen(
        onRetry: () => connectivity.retry(),
        customMessage:
            'You need an internet connection to search addresses and load the map tiles.',
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Select Delivery Location'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        actions: [
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
            onPressed: _isLoadingLocation ? null : _initializeMap,
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
                    'We deliver within our service area from Madaraka, Nairobi. '
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
                        hintText: 'Search location (e.g. Moi Avenue, Westlands, Karen)',
                        hintStyle: const TextStyle(fontSize: 14),
                        prefixIcon: _isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : const Icon(Icons.search, color: AppColors.primary),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!_isSearching)
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
                                        _isSearching = false;
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
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Results header
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.05),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.search, size: 16, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_searchResults.length} location${_searchResults.length > 1 ? 's' : ''} found',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Results list
                            Flexible(
                              child: ListView.separated(
                                shrinkWrap: true,
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                itemCount: _searchResults.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  indent: 52,
                                  color: Colors.grey.shade200,
                                ),
                                itemBuilder: (context, index) {
                                  final result = _searchResults[index];
                                  final distanceKm = result['distance_from_nairobi'] as double?;
                                  final type = result['type'] as String? ?? 'place';
                                  
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.location_on,
                                        color: AppColors.primary,
                                        size: 20,
                                      ),
                                    ),
                                    title: Text(
                                      result['name'],
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: distanceKm != null
                                        ? Text(
                                            '${distanceKm.toStringAsFixed(1)}km from city center • $type',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                            ),
                                          )
                                        : null,
                                    onTap: () => _selectSearchResult(result),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          // Map container with error/retry
          Consumer<LocationProvider>(
            builder: (context, provider, child) {
              return Positioned.fill(
                top: _searchResults.isNotEmpty ? 280 : 80,
                child: Stack(
                  children: [
                    if (!_isMapReady)
                      const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Loading map...'),
                          ],
                        ),
                      )
                    else if (_hasInitializationError)
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            const Text('Failed to load map', style: TextStyle(fontSize: 18)),
                            const SizedBox(height: 8),
                            const Text('Please check your internet connection', textAlign: TextAlign.center),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _initializeMap,
                              icon: Icon(Icons.refresh),
                              label: Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    else
                      FlutterMap(
                        mapController: mapController,
                        options: MapOptions(
                          initialCenter: (provider.latitude != null && provider.longitude != null)
                              ? LatLng(provider.latitude!, provider.longitude!)
                              : const LatLng(
                                  -1.303960,
                                  36.790900,
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
                          if (provider.activeLocation != null && provider.activeLocation!.lat != null && provider.activeLocation!.lon != null)
                            CircleLayer(
                              circles: [
                                CircleMarker(
                                  point: LatLng(
                                    provider.activeLocation!.lat!,
                                    provider.activeLocation!.lon!,
                                  ),
                                  color: AppColors.primary.withOpacity(0.2),
                                  borderColor: AppColors.primary.withOpacity(0.5),
                                  borderStrokeWidth: 2,
                                  useRadiusInMeter: true,
                                  radius: (provider.activeLocation!.deliveryRadiusKm ?? 2.0) * 1000,
                                ),
                              ],
                            ),
                          if (provider.activeLocation != null && provider.activeLocation!.lat != null && provider.activeLocation!.lon != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(
                                    provider.activeLocation!.lat!,
                                    provider.activeLocation!.lon!,
                                  ),
                                  width: 40,
                                  height: 40,
                                  child: const Icon(Icons.restaurant, color: Colors.red, size: 30),
                                ),
                              ],
                            ),
                          if (provider.latitude != null && provider.longitude != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(provider.latitude!, provider.longitude!),
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
                    if (_isMapReady && provider.outsideDeliveryArea)
                      Positioned(
                        top: 12,
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
                                  'You are outside our delivery zone',
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
                  ],
                ),
              );
            },
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
          Consumer<LocationProvider>(
            builder: (context, provider, child) {
              return Align(
                alignment: Alignment.bottomCenter,
                child: _buildAddressCard(provider),
              );
            },
          ),
        ],
      ),
    );
  }
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }


}