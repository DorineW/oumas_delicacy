// lib/screens/checkout_screen.dart
// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart' show Position;
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/cart_item.dart';
import '../models/order.dart' show DeliveryType;
import '../services/location_service.dart';
import '../services/auth_service.dart';
import '../providers/cart_provider.dart';
import '../providers/menu_provider.dart';
import '../constants/colors.dart';
import 'location.dart'; // UPDATED: Use existing LocationScreen
import '../providers/location_provider.dart'; // ADDED

enum PaymentMethod { cash, mpesa }

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
  PaymentMethod _selectedMethod = PaymentMethod.cash;
  LatLng? _deliveryLatLng;
  bool _isLocationLoading = false;
  bool _isProcessing = false;

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _mpesaPhoneController = TextEditingController();
  final TextEditingController _deliveryAddressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final defaultPhone = widget.defaultPhoneNumber ?? '712345678';
    _phoneController.text = defaultPhone;
    _mpesaPhoneController.text = defaultPhone;

    _loadDefaultAddress();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _mpesaPhoneController.dispose();
    _deliveryAddressController.dispose();
    super.dispose();
  }

  int get totalAmount {
    final subtotal = widget.selectedItems.fold<int>(
      0,
      (sum, item) => sum + (item.price * item.quantity),
    );
    return _deliveryLatLng != null ? subtotal + 150 : subtotal;
  }

  Future<void> _getUserLocation() async {
    if (!mounted) return;
    setState(() => _isLocationLoading = true);

    try {
      final Position? pos = await LocationService.getCurrentLocation();
      if (!mounted) return;

      if (pos != null) {
        setState(() {
          _deliveryLatLng = LatLng(pos.latitude, pos.longitude);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not obtain current location')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
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
      final result = await Navigator.push<dynamic>(
        context,
        MaterialPageRoute(
          builder: (_) => LocationScreen(initialPosition: null),
        ),
      );

      if (!mounted) return;
      if (result == null) {
        // user cancelled selection
        return;
      }

      // If LocationScreen returned a Position (from geolocator)
      if (result is Position) {
        setState(() {
          _deliveryLatLng = LatLng(result.latitude, result.longitude);
        });
        return;
      }

      // If LocationScreen returned a LatLng (google maps)
      if (result is LatLng) {
        setState(() {
          _deliveryLatLng = result;
        });
        return;
      }

      // If LocationScreen returned a Map or other structure with lat/lng keys
      if (result is Map && result.containsKey('latitude') && result.containsKey('longitude')) {
        final lat = result['latitude'];
        final lng = result['longitude'];
        if (lat is num && lng is num) {
          setState(() {
            _deliveryLatLng = LatLng(lat.toDouble(), lng.toDouble());
            if (result.containsKey('address')) {
              _deliveryAddressController.text = result['address'] ?? '';
            }
          });
          
          // ADDED: Check if outside delivery zone
          if (result['outsideZone'] == true) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.white),
                    const SizedBox(width: 8),
                    const Expanded(
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
          return;
        }
      }

      // Unknown result type
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid location returned')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting location: $e')),
      );
    }
  }

  // ADDED: Load default address from SharedPreferences
  Future<void> _loadDefaultAddress() async {
    // ADDED: Load from Supabase currentUser FIRST
    final auth = Provider.of<AuthService>(context, listen: false);
    final currentUser = auth.currentUser;
    
    if (currentUser != null && currentUser.phone != null && currentUser.phone!.isNotEmpty) {
      setState(() {
        _phoneController.text = currentUser.phone!;
        _mpesaPhoneController.text = currentUser.phone!;
      });
    }
    
    // Load addresses from SharedPreferences (these are user-specific)
    final prefs = await SharedPreferences.getInstance();
    
    final addresses = prefs.getStringList('addresses') ?? [];
    final defaultIndex = prefs.getInt('defaultAddressIndex');
    
    if (addresses.isNotEmpty && defaultIndex != null && defaultIndex < addresses.length) {
      final defaultAddress = addresses[defaultIndex];
      
      setState(() {
        _deliveryAddressController.text = defaultAddress;
      });
      
      // UPDATED: Use LocationProvider to get coordinates
      try {
        final locationProvider = Provider.of<LocationProvider>(context, listen: false);
        final results = await locationProvider.searchAddress(defaultAddress);
        
        if (results.isNotEmpty && mounted) {
          final result = results[0];
          setState(() {
            _deliveryLatLng = LatLng(result['lat'], result['lon']);
          });
          
          debugPrint('📍 Loaded default address: $defaultAddress');
          debugPrint('📍 Coordinates: ${result['lat']}, ${result['lon']}');
        }
      } catch (e) {
        debugPrint('⚠️ Could not get coordinates for default address: $e');
        // Keep the address text even if coordinates fail
      }
    }
  }

  Future<void> _payNow() async {
    // UPDATED: Validate delivery address is required for delivery
    if (_deliveryLatLng != null) {
      // Delivery mode - address is REQUIRED
      if (_deliveryAddressController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Please select your delivery address from the map'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Select Address',
              textColor: Colors.white,
              onPressed: _selectLocationOnMap,
            ),
          ),
        );
        return;
      }
    }

    // ADDED: Validate phone number is required
    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Please enter your phone number'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // ADDED: Final availability check before processing payment
    final menuProvider = context.read<MenuProvider>();
    final cartProvider = context.read<CartProvider>();
    final auth = context.read<AuthService>();
    
    final unavailableItems = widget.selectedItems.where(
      (item) => !menuProvider.isItemAvailable(item.mealTitle)
    ).toList();

    if (unavailableItems.isNotEmpty) {
      final itemNames = unavailableItems.map((item) => item.mealTitle).join(', ');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text('The following items are no longer available: $itemNames'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);
    
    try {
      // Simulate payment processing
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) {
        setState(() => _isProcessing = false);
        return;
      }

      final currentUser = auth.currentUser;
      final customerId = currentUser?.id ?? 'guest';
      final customerName = currentUser?.name ?? 'Guest User';

      // Clear cart items after successful checkout
      for (final item in widget.selectedItems) {
        cartProvider.removeItem(item.id);
      }

      // Navigate to confirmation screen with full customer info
      Navigator.pushReplacementNamed(
        context,
        '/confirmation',
        arguments: {
          'items': widget.selectedItems,
          'deliveryType': _deliveryLatLng != null ? DeliveryType.delivery : DeliveryType.pickup,
          'totalAmount': totalAmount,
          'customerId': customerId,
          'customerName': customerName,
          'deliveryAddress': _deliveryAddressController.text.isNotEmpty 
              ? _deliveryAddressController.text 
              : null,
          'phoneNumber': _phoneController.text.isNotEmpty 
              ? _phoneController.text 
              : null,
        },
      );
    } catch (e) {
      if (!mounted) {
        setState(() => _isProcessing = false);
        return;
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isProcessing = false);
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final menuProvider = context.watch<MenuProvider>();

    // FIXED: Check for unavailable items during checkout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final unavailableItems = <CartItem>[];
      
      for (final item in widget.selectedItems) {
        if (!menuProvider.isItemAvailable(item.mealTitle)) {
          unavailableItems.add(item);
        }
      }

      if (unavailableItems.isNotEmpty && mounted) {
        // Remove unavailable items
        for (final item in unavailableItems) {
          cart.removeItem(item.id);
        }

        // Build content widgets explicitly to avoid complex inline collection syntax
        final List<Widget> contentWidgets = [
          const Text('The following items are currently out of stock and have been removed:'),
          const SizedBox(height: 12),
        ];

        for (final item in unavailableItems) {
          contentWidgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.close, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${item.quantity}x ${item.mealTitle}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        contentWidgets.add(const SizedBox(height: 12));

        if (cart.items.isEmpty) {
          contentWidgets.add(
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Your cart is now empty. Please add items to continue.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          );
        }

        // Build actions explicitly
        final List<Widget> actionButtons = [];
        if (cart.items.isEmpty) {
          actionButtons.add(
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back to cart
              },
              child: const Text('Back to Menu'),
            ),
          );
        } else {
          actionButtons.addAll([
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back to cart
              },
              child: const Text('Review Cart'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog and continue
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Continue Checkout'),
            ),
          ]);
        }

        // Show dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.warning, color: Colors.orange),
                const SizedBox(width: 8),
                const Text('Items Unavailable'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: contentWidgets,
            ),
            actions: actionButtons,
          ),
        );
      }
    });

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
            children: [
              _buildSelectedItemsList(),
              const SizedBox(height: 16),
              _buildDeliverySection(),
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
          const Divider(height: 24, thickness: 1.5),
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
              const Text(
                'Delivery Information',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkText),
              ),
            ],
          ),
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
                  const Text(
                    'KES 150',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ],
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
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.payment, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Payment Method',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkText),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildPaymentOption(
          PaymentMethod.cash,
          'Cash on Delivery',
          'Pay with cash when your order arrives',
          Icons.money,
        ),
        if (_selectedMethod == PaymentMethod.cash) ...[
          Container(
            margin: const EdgeInsets.only(top: 12),
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
            child: TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                hintText: 'For delivery updates',
                prefixText: '+254 ',
                prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.primary),
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
          ),
        ],
        const SizedBox(height: 12),
        _buildPaymentOption(
          PaymentMethod.mpesa,
          'M-Pesa Payment',
          'Pay securely via M-Pesa mobile money',
          Icons.phone_android,
        ),
        if (_selectedMethod == PaymentMethod.mpesa) ...[
          Container(
            margin: const EdgeInsets.only(top: 12),
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
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.success, AppColors.success.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.phone_android, color: AppColors.white, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'M-Pesa Till Number',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '123456',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Use this number when making payment',
                        style: TextStyle(fontSize: 12, color: AppColors.white.withOpacity(0.9)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _mpesaPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Your M-Pesa Number',
                    hintText: 'Enter phone number',
                    prefixText: '+254 ',
                    prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.primary),
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
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPaymentOption(PaymentMethod method, String title, String subtitle, IconData icon) {
    final isSelected = _selectedMethod == method;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = method),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.lightGray.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isSelected ? AppColors.primary : AppColors.lightGray).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: isSelected ? AppColors.primary : AppColors.darkText, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isSelected ? AppColors.primary : AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.darkText.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            Radio<PaymentMethod>(
              value: method,
              groupValue: _selectedMethod,
              activeColor: AppColors.primary,
              onChanged: (v) {
                if (v == null) return;
                setState(() => _selectedMethod = v);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayButton() {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.accent, AppColors.accent.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _payNow,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isProcessing
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, color: AppColors.white),
                  SizedBox(width: 8),
                  Text('Complete Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.white)),
                ],
              ),
      ),
    );
  }
}
