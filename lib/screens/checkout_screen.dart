// lib/screens/checkout_screen.dart
// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart' show Position;
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/cart_item.dart';
import '../models/order.dart';
import '../services/location_service.dart';
import '../services/auth_service.dart';
import '../services/mpesa_service.dart'; // ADDED: M-Pesa service
import '../providers/cart_provider.dart';
import '../providers/menu_provider.dart';
import '../providers/store_provider.dart';
import '../providers/order_provider.dart';
import '../providers/address_provider.dart';
import '../providers/location_management_provider.dart';
import '../providers/mpesa_provider.dart';
import '../models/user_address.dart';
import '../constants/colors.dart';
import 'location.dart'; // UPDATED: Use existing LocationScreen
import '../providers/location_provider.dart'; // ADDED: Import LocationProvider (Removed duplicate import)
import 'customer_address_management_screen.dart'; // ADDED: Address management screen
import '../utils/error_snackbar.dart';
import '../utils/phone_utils.dart';

class CheckoutScreen extends StatefulWidget {
  final List<CartItem> selectedItems;
  final String? defaultPhoneNumber;

  const CheckoutScreen({
    super.key,
    required this.selectedItems,
    this.defaultPhoneNumber,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  LatLng? _deliveryLatLng;
  int _deliveryFee = 0; // ADDED: Store dynamic delivery fee
  String? _selectedAddressId; // ADDED: Track selected address ID
  bool _isLocationLoading = false;
  bool _isProcessing = false;
  bool _isCalculatingFee = false; // ADDED: Track delivery fee calculation

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _mpesaPhoneController = TextEditingController();
  final TextEditingController _deliveryAddressController = TextEditingController();
  final TextEditingController _specialInstructionsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final defaultPhone = widget.defaultPhoneNumber ?? '';
    final localDefault = defaultPhone.isEmpty ? '' : PhoneUtils.toLocalDisplay(defaultPhone);
    _phoneController.text = localDefault;
    _mpesaPhoneController.text = localDefault; // Auto-fill M-Pesa number in local format

    // Use post-frame callback to avoid calling notifyListeners during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadDefaultAddress();
      }
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _mpesaPhoneController.dispose();
    _deliveryAddressController.dispose();
    _specialInstructionsController.dispose();
    super.dispose();
  }

  // UPDATED: Calculate amounts correctly
  int get subtotalAmount {
    return widget.selectedItems.fold<int>(
      0,
      (sum, item) => sum + (item.price * item.quantity),
    );
  }

  int get tax {
    return (subtotalAmount * 0.0).toInt(); // 0% tax for now, adjust if needed
  }

  int get totalAmount {
    final deliveryCost = _deliveryLatLng != null ? _deliveryFee : 0;
    return subtotalAmount + deliveryCost + tax;
  }

  Future<void> _getUserLocation() async {
    if (!mounted) return;
    setState(() => _isLocationLoading = true);

    final messenger = ScaffoldMessenger.of(context);
    final locationProvider = context.read<LocationProvider>();
    final locationManagementProvider = context.read<LocationManagementProvider>();

    try {
      final Position? pos = await LocationService.getCurrentLocation();
      if (!mounted) return;

      if (pos != null) {
        await locationProvider.setLocation(pos.latitude, pos.longitude);

        if (!mounted) return;
        
        // Load locations if not loaded
        if (locationManagementProvider.locations.isEmpty) {
          await locationManagementProvider.loadLocations();
        }
        
        // Find nearest active location
        final nearestLocation = locationManagementProvider.getNearestLocation(
          pos.latitude, 
          pos.longitude,
        );
        
        if (nearestLocation != null) {
          // Calculate delivery details (temporary order amount for check)
          final deliveryDetails = locationManagementProvider.calculateDeliveryDetails(
            locationId: nearestLocation.id,
            userLat: pos.latitude,
            userLon: pos.longitude,
            orderAmount: subtotalAmount,
          );
          
          setState(() {
            _deliveryLatLng = LatLng(pos.latitude, pos.longitude);
            _deliveryAddressController.text = locationProvider.deliveryAddress ?? 'Location selected (details required)';
            
            if (deliveryDetails != null && deliveryDetails['canDeliver'] == true) {
              _deliveryFee = deliveryDetails['deliveryFee'] as int;
              debugPrint('📍 Delivery from: ${nearestLocation.name}, Fee: $_deliveryFee');
            } else {
              _deliveryFee = 0;
              final reason = deliveryDetails?['reason'] ?? 'Cannot deliver';
              debugPrint('⚠️ $reason');
            }
          });
          
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                deliveryDetails != null && deliveryDetails['canDeliver'] == true
                    ? 'Location determined: ${locationProvider.deliveryAddress ?? 'Coordinates only'}'
                    : 'Delivery not available: ${deliveryDetails?['reason'] ?? 'Unknown reason'}',
              ),
              backgroundColor: deliveryDetails != null && deliveryDetails['canDeliver'] == true 
                  ? AppColors.success 
                  : Colors.orange,
            ),
          );
        } else {
          setState(() {
            _deliveryLatLng = LatLng(pos.latitude, pos.longitude);
            _deliveryAddressController.text = locationProvider.deliveryAddress ?? 'Location selected (details required)';
            _deliveryFee = 0;
          });
          
          messenger.showSnackBar(
            const SnackBar(
              content: Text('No restaurant location serves your area'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not obtain current location or permissions denied.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Location error: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isLocationLoading = false);
    }
  }

  /// Open map screen and accept either LatLng or Position returned by that screen.
  Future<void> _selectLocationOnMap() async {
    try {
      final initialPosition = _deliveryLatLng != null
          ? {'latitude': _deliveryLatLng!.latitude, 'longitude': _deliveryLatLng!.longitude}
          : null;

      final result = await Navigator.push<Map<String, dynamic>?>(
        context,
        MaterialPageRoute(
          builder: (_) => LocationScreen(initialPosition: initialPosition),
        ),
      );

      if (!mounted) return;
      if (result == null || !result.containsKey('latitude')) {
        return;
      }

      final lat = result['latitude'] as num;
      final lng = result['longitude'] as num;
      final address = result['address'] as String? ?? '';
      final outsideZone = result['outsideZone'] as bool? ?? false;
      final fee = result['deliveryFee'] as int? ?? 0;

      setState(() {
        _deliveryLatLng = LatLng(lat.toDouble(), lng.toDouble());
        _deliveryAddressController.text = address;
        _deliveryFee = fee; // ADDED: Set dynamic fee from map screen
      });

      if (outsideZone) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.warning, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You are outside the delivery area! Delivery may not be available.',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting location: $e')),
      );
    }
  }

  // Load default address from UserAddresses table
  Future<void> _loadDefaultAddress() async {
    // Load user's phone number
    final auth = Provider.of<AuthService>(context, listen: false);
    final currentUser = auth.currentUser;

    if (currentUser != null && currentUser.phone != null && currentUser.phone!.isNotEmpty) {
      setState(() {
        final local = PhoneUtils.toLocalDisplay(currentUser.phone!);
        _phoneController.text = local;
        _mpesaPhoneController.text = local;
      });
    }

    // Load default address from UserAddresses table
    try {
      final addressProvider = Provider.of<AddressProvider>(context, listen: false);
      
      // Only reload if not already loaded (optimized - preloaded from home screen)
      if (addressProvider.addresses.isEmpty) {
        await addressProvider.loadAddresses();
      }
      
      final defaultAddress = addressProvider.addresses.where((addr) => addr.isDefault).firstOrNull;
      
      if (defaultAddress != null && mounted) {
        setState(() {
          _selectedAddressId = defaultAddress.id;
          _deliveryLatLng = LatLng(defaultAddress.latitude, defaultAddress.longitude);
          _deliveryAddressController.text = defaultAddress.displayAddress;
          _isCalculatingFee = true; // Show loading
        });
        
        // Use LocationManagementProvider to calculate delivery fee from nearest location
        try {
          final locationProvider = Provider.of<LocationProvider>(context, listen: false);
          final locationManagementProvider = Provider.of<LocationManagementProvider>(context, listen: false);
          
          await locationProvider.setLocation(defaultAddress.latitude, defaultAddress.longitude);
          
          // Load locations if not loaded
          if (locationManagementProvider.locations.isEmpty) {
            await locationManagementProvider.loadLocations();
          }
          
          // Find nearest active location
          final nearestLocation = locationManagementProvider.getNearestLocation(
            defaultAddress.latitude,
            defaultAddress.longitude,
          );
          
          if (nearestLocation != null) {
            final deliveryDetails = locationManagementProvider.calculateDeliveryDetails(
              locationId: nearestLocation.id,
              userLat: defaultAddress.latitude,
              userLon: defaultAddress.longitude,
              orderAmount: subtotalAmount,
            );
            
            setState(() {
              if (deliveryDetails != null && deliveryDetails['canDeliver'] == true) {
                _deliveryFee = deliveryDetails['deliveryFee'] as int;
              } else {
                _deliveryFee = 0;
              }
              _isCalculatingFee = false; // Done loading
            });
          } else {
            setState(() {
              _deliveryFee = 0;
              _isCalculatingFee = false;
            });
          }
          
          debugPrint('📍 Loaded default address: ${defaultAddress.label} with fee: $_deliveryFee');
        } catch (e) {
          debugPrint('⚠️ Could not calculate delivery fee: $e');
          if (mounted) {
            setState(() => _isCalculatingFee = false);
          }
        }
      } else {
        debugPrint('ℹ️ No default address found');
      }
    } catch (e) {
      debugPrint('⚠️ Error loading addresses: $e');
    }
  }

  // TEMPORARILY COMMENTED OUT FOR TESTING - M-Pesa payment dialog
  // Re-enable this when you want to show the payment dialog again
  /*
  void _showMpesaPaymentDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.payment, color: AppColors.success),
            SizedBox(width: 12),
            Text('Complete M-Pesa Payment'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.success, AppColors.success.withOpacity(0.8)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.phone_android, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Pay to Till Number',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '123456',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const Divider(color: Colors.white54, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Amount to Pay:',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      Text(
                        'KES $totalAmount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, size: 16, color: Colors.blue.withOpacity(0.8)),
                      const SizedBox(width: 8),
                      const Text(
                        'Payment Instructions',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. Go to M-Pesa on your phone\n'
                    '2. Select Lipa na M-Pesa > Buy Goods\n'
                    '3. Enter Till Number: 123456\n'
                    '4. Enter Amount: KES $totalAmount\n'
                    '5. Enter your M-Pesa PIN\n'
                    '6. Confirm payment',
                    style: const TextStyle(fontSize: 12, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Have you completed the payment?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _processOrder();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: const Text('I Have Paid'),
          ),
        ],
      ),
    );
  }
  */

  Widget _buildSelectedItemsList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.receipt_long, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Order Summary',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkText),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...widget.selectedItems.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${item.mealTitle} x${item.quantity}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    'KES ${item.price * item.quantity}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ],
              ),
            );
          }),
          const Divider(height: 12, thickness: 1.5),

          // ADDED: Subtotal
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
              Text(
                'KES $subtotalAmount',
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              ),
            ],
          ),

          // Delivery Fee (always show)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Delivery Fee', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                Text(
                  _deliveryLatLng != null 
                      ? 'KES $_deliveryFee' 
                      : 'Set location',
                  style: TextStyle(
                    fontWeight: FontWeight.w500, 
                    fontSize: 14, 
                    color: _deliveryLatLng != null ? AppColors.primary : Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 24, thickness: 1.5),

          // Total Amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(
                'KES $totalAmount',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeliverySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delivery_dining, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivery Information',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkText),
                    ),
                    Text(
                      'Required - Select delivery location',
                      style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Saved Addresses Selector
          _buildSavedAddressesSelector(),
          const SizedBox(height: 16),

          if (_deliveryLatLng == null) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLocationLoading ? null : _getUserLocation,
                    icon: _isLocationLoading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
                        : const Icon(Icons.my_location, size: 20),
                    label: Text(_isLocationLoading ? 'Getting...' : 'Current Location'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectLocationOnMap,
                    icon: const Icon(Icons.map_outlined, size: 20),
                    label: const Text('Select on Map'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: AppColors.success, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Location Selected',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.success),
                        ),
                        Text(
                          'Lat: ${_deliveryLatLng!.latitude.toStringAsFixed(5)}, Lng: ${_deliveryLatLng!.longitude.toStringAsFixed(5)}',
                          style: TextStyle(fontSize: 11, color: AppColors.darkText.withOpacity(0.7)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: AppColors.primary, size: 20),
                    onPressed: _selectLocationOnMap,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _deliveryAddressController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Delivery Address Details',
                hintText: 'Building, floor, apartment, landmark...',
                prefixIcon: const Icon(Icons.home_outlined, color: AppColors.primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.lightGray),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.lightGray.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
                filled: true,
                fillColor: AppColors.background,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_shipping, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Delivery Fee:',
                    style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.darkText),
                  ),
                  const Spacer(),
                  _isCalculatingFee
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        )
                      : Text(
                          'KES $_deliveryFee',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                        ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpecialInstructionsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_note, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order Instructions (Optional)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkText),
                    ),
                    Text(
                      'Add special notes for your order',
                      style: TextStyle(fontSize: 11, color: AppColors.darkText),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _specialInstructionsController,
            maxLines: 3,
            maxLength: 200,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              hintText: 'e.g., "Please call when you arrive", "Leave at gate", "Deliver to 3rd floor"...',
              hintStyle: TextStyle(fontSize: 13, color: AppColors.darkText.withOpacity(0.5)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.primary.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.primary.withOpacity(0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
              filled: true,
              fillColor: AppColors.background,
              counterStyle: TextStyle(fontSize: 11, color: AppColors.darkText.withOpacity(0.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.payment, color: AppColors.success, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Payment Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkText),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Payment info container
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.success.withOpacity(0.3), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // M-Pesa Phone Number (used for both payment and contact)
              TextFormField(
                controller: _mpesaPhoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'M-Pesa Phone Number *',
                  hintText: '0712345678',
                  prefixIcon: const Icon(Icons.phone_android, color: AppColors.success),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.success, width: 2),
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                  helperText: 'We\'ll send payment prompt & receipt to this number',
                  helperStyle: const TextStyle(fontSize: 12),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Phone number is required';
                  }
                  // Validate using PhoneUtils
                  final normalized = PhoneUtils.normalizeKenyan(value);
                  if (!PhoneUtils.isE164Kenyan(normalized)) {
                    return 'Please enter a valid Kenyan phone number';
                  }
                  return null;
                },
                onChanged: (value) {
                  // Auto-sync to contact phone
                  _phoneController.text = value;
                },
              ),

              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, size: 16, color: Colors.blue.withOpacity(0.8)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Payment is required to complete your order. You will pay via M-Pesa before order confirmation.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.darkText.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build saved addresses dropdown selector
  Widget _buildSavedAddressesSelector() {
    return Consumer<AddressProvider>(
      builder: (context, addressProvider, child) {
        if (addressProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final addresses = addressProvider.addresses;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Saved Delivery Addresses',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkText,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CustomerAddressManagementScreen(),
                      ),
                    ).then((_) {
                      // Reload addresses when returning
                      addressProvider.loadAddresses();
                    });
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Manage'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            if (addresses.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info, color: Colors.orange, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'No saved addresses',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Add an address or select location below',
                            style: TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedAddressId,
                    hint: const Text('Select a saved address'),
                    items: addresses.map((address) {
                      return DropdownMenuItem<String>(
                        value: address.id,
                        child: Row(
                          children: [
                            Icon(
                              address.isDefault ? Icons.home : Icons.location_on,
                              size: 18,
                              color: address.isDefault ? AppColors.success : AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    address.label.isNotEmpty ? address.label : 'Address',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    address.displayAddress,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.darkText.withOpacity(0.7),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (address.isDefault)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Default',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        final selectedAddress = addresses.firstWhere((addr) => addr.id == newValue);
                        _selectSavedAddress(selectedAddress);
                      }
                    },
                  ),
                ),
              ),
            
            if (addresses.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Or choose a different location:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// Select a saved address and calculate delivery fee
  Future<void> _selectSavedAddress(UserAddress address) async {
    setState(() => _isCalculatingFee = true); // Show loading
    
    try {
      final addressProvider = Provider.of<AddressProvider>(context, listen: false);
      final locationManagementProvider = Provider.of<LocationManagementProvider>(context, listen: false);
      
      // Load locations if not loaded
      if (locationManagementProvider.locations.isEmpty) {
        await locationManagementProvider.loadLocations();
      }
      
      // Find nearest active location
      final nearestLocation = locationManagementProvider.getNearestLocation(
        address.latitude,
        address.longitude,
      );
      
      if (nearestLocation == null) {
      if (mounted) {
        setState(() => _isCalculatingFee = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No restaurant/store location serves your area'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
      
      // Check delivery zone and calculate fee
      final deliveryInfo = await addressProvider.getDeliveryInfo(
        address: address,
        location: nearestLocation,
      );
      
      if (!deliveryInfo.isInZone) {
        if (mounted) {
          setState(() => _isCalculatingFee = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(deliveryInfo.statusMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }      // Address is valid, set it
      setState(() {
        _selectedAddressId = address.id;
        _deliveryLatLng = LatLng(address.latitude, address.longitude);
        _deliveryAddressController.text = address.displayAddress;
        _deliveryFee = deliveryInfo.deliveryFee ?? 0;
        _isCalculatingFee = false; // Done loading
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Delivering from ${nearestLocation.name}\\n'
              'Distance: ${deliveryInfo.distanceDisplay}\\n'
              'Fee: KES ${deliveryInfo.deliveryFee}',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCalculatingFee = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting address: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildPayButton() {
    if (_isProcessing) {
      return Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.success, AppColors.success.withOpacity(0.8)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
            ),
          ),
        ),
      );
    }

    // Validate form inputs
    if (_mpesaPhoneController.text.trim().isEmpty) {
      return _buildDisabledButton('Enter M-Pesa number');
    }

    if (_deliveryLatLng == null) {
      return _buildDisabledButton('Select delivery address');
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _processOrderAndPayment,
        icon: const Icon(Icons.phone_android, size: 24),
        label: const Text(
          'Pay with M-Pesa',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  Future<void> _processOrderAndPayment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_deliveryLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a delivery location'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      final mpesaProvider = Provider.of<MpesaProvider>(context, listen: false);
      
      final currentUser = auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      final mpesaPhone = PhoneUtils.normalizeKenyan(_mpesaPhoneController.text.trim());
      
      debugPrint('📦 Creating order...');
      
      // Convert CartItems to OrderItems
      final orderItems = widget.selectedItems.map((cartItem) => OrderItem(
        id: cartItem.id,
        menuItemId: cartItem.menuItemId,
        title: cartItem.mealTitle,
        quantity: cartItem.quantity,
        price: cartItem.price,
        itemType: 'Food',
      )).toList();
      
      // Create order in database with 'pending_payment' status
      final orderId = await orderProvider.createOrder(
        customerId: currentUser.id,
        customerName: currentUser.name ?? currentUser.email,
        items: orderItems,
        deliveryAddress: _deliveryAddressController.text.trim(),
        specialInstructions: _specialInstructionsController.text.trim(),
        deliveryType: DeliveryType.delivery,
        subtotal: subtotalAmount,
        deliveryFee: _deliveryFee,
        tax: tax,
        totalAmount: totalAmount,
        deliveryLat: _deliveryLatLng?.latitude,
        deliveryLon: _deliveryLatLng?.longitude,
      );

      debugPrint('✅ Order created: $orderId');
      debugPrint('💳 Initiating M-Pesa payment...');

      // Initiate M-Pesa payment with order ID
      final paymentSuccess = await mpesaProvider.initiatePayment(
        phoneNumber: mpesaPhone,
        amount: totalAmount,
        orderId: orderId,
        accountReference: 'ORDER-${orderId.substring(0, 8)}',
        transactionDesc: 'Payment for order',
      );

      if (!paymentSuccess) {
        throw Exception(mpesaProvider.errorMessage ?? 'Payment initiation failed');
      }

      if (!mounted) return;

      // Show payment dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _buildPaymentDialog(
          mpesaProvider: mpesaProvider,
          orderId: orderId,
          phoneNumber: mpesaPhone,
        ),
      );

    } catch (e) {
      debugPrint('❌ Error: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildPaymentDialog({
    required MpesaProvider mpesaProvider,
    required String orderId,
    required String phoneNumber,
  }) {
    return Consumer<MpesaProvider>(
      builder: (context, provider, child) {
        final status = provider.paymentStatus;

        // Handle payment completion
        if (status == 'completed') {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (mounted) {
              // Get provider references BEFORE any navigation
              final auth = Provider.of<AuthService>(context, listen: false);
              final orderProvider = Provider.of<OrderProvider>(context, listen: false);
              final cartProvider = Provider.of<CartProvider>(context, listen: false);
              final currentUser = auth.currentUser;
              
              // Close dialog first (fast)
              Navigator.of(context).pop();
              
              // Clear cart (fast)
              for (final item in widget.selectedItems) {
                cartProvider.removeItem(item.id);
              }
              
              setState(() => _isProcessing = false);
              
              // Navigate to order history or home (fast)
              Navigator.of(context).popUntil((route) => route.isFirst);
              
              // Show success message (fast)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 8),
                      Expanded(child: Text('✅ Payment successful! Order confirmed.')),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 4),
                ),
              );
              
              // Reload orders in background (doesn't block UI)
              if (currentUser != null) {
                orderProvider.loadOrders(currentUser.id).then((_) {
                  debugPrint('✅ Orders refreshed: ${orderProvider.orders.length} orders');
                });
              }
            }
          });
        }

        // Handle payment failure or timeout
        if (status == 'failed' || status == 'cancelled' || status == 'timeout') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pop();
              setState(() => _isProcessing = false);
              
              final isTimeout = status == 'timeout';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(
                        isTimeout ? Icons.access_time : Icons.error,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          provider.errorMessage ?? 
                          (isTimeout 
                            ? '⏱️ Payment verification timed out. Check \"My Orders\" or M-Pesa message.'
                            : '❌ Payment $status. Please try again.'),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: isTimeout ? Colors.orange : Colors.red,
                  duration: Duration(seconds: isTimeout ? 6 : 4),
                  action: isTimeout
                      ? SnackBarAction(
                          label: 'Check Orders',
                          textColor: Colors.white,
                          onPressed: () {
                            Navigator.of(context).pushNamed('/orders');
                          },
                        )
                      : null,
                ),
              );
              provider.reset();
            }
          });
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.phone_android,
                  color: Colors.green,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'M-Pesa Payment',
                style: TextStyle(fontSize: 20),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (status == 'pending') ...[
                  const SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      color: Colors.green,
                      strokeWidth: 6,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Processing Payment...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    phoneNumber,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Amount to pay',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'KSh ${totalAmount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Steps to complete payment:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '1. Enter your M-Pesa PIN when prompted\n'
                          '2. Confirm the payment\n'
                          '3. Confirm the payment',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Fallback view for non-pending statuses
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Column(
                      children: [
                        Text(
                          provider.errorMessage ?? 'Payment status: $status',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: status == 'completed' ? Colors.green : Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'If payment was completed, check your Orders section or wait for confirmation message.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                provider.reset();
                Navigator.of(context).pop();
                setState(() => _isProcessing = false);
              },
              icon: const Icon(Icons.close),
              label: const Text('Cancel'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDisabledButton(String message) {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: AppColors.white),
        titleTextStyle: const TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildSelectedItemsList(),
              const SizedBox(height: 16),
              _buildDeliverySection(),
              const SizedBox(height: 16),
              _buildSpecialInstructionsSection(),
              const SizedBox(height: 16),
              _buildPaymentSection(),
              const SizedBox(height: 24),
              _buildPayButton(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}