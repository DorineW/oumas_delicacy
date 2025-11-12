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
import '../providers/order_provider.dart';
import '../constants/colors.dart';
import 'location.dart'; // UPDATED: Use existing LocationScreen
import '../providers/location_provider.dart'; // ADDED: Import LocationProvider (Removed duplicate import)
import 'mpesa_payment_confirmation_screen.dart'; // ADDED: M-Pesa confirmation screen

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
  bool _isLocationLoading = false;
  bool _isProcessing = false;

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _mpesaPhoneController = TextEditingController();
  final TextEditingController _deliveryAddressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final defaultPhone = widget.defaultPhoneNumber ?? '';
    _phoneController.text = defaultPhone;
    _mpesaPhoneController.text = defaultPhone; // Auto-fill M-Pesa number

    _loadDefaultAddress();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _mpesaPhoneController.dispose();
    _deliveryAddressController.dispose();
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

      _deliveryAddressController.text = defaultAddress;

      // UPDATED: Use LocationProvider to get coordinates
      try {
        final locationProvider = Provider.of<LocationProvider>(context, listen: false);
        // Assuming searchAddress returns a list of results with 'lat' and 'lon' keys
        final results = await locationProvider.searchAddress(defaultAddress);

        if (results.isNotEmpty && mounted) {
          final result = results[0];

          // Use the correct argument types (double) for setLocation
          await locationProvider.setLocation(result['lat'].toDouble(), result['lon'].toDouble());

          setState(() {
            _deliveryLatLng = LatLng(result['lat'].toDouble(), result['lon'].toDouble());
            _deliveryFee = locationProvider.deliveryFee; // ADDED: Update fee on load
          });

          debugPrint('📍 Loaded default address: $defaultAddress with fee: $_deliveryFee');
        }
      } catch (e) {
        debugPrint('⚠️ Could not get coordinates/fee for default address: $e');
      }
    }
  }

  Future<void> _payNow() async {
    // REQUIRED: Location and payment must be provided
    
    // Only check if mounted before showing errors
    if (!mounted) return;

    // 1. REQUIRED: Validate delivery location is selected
    if (_deliveryLatLng == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.location_off, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Please select a delivery location (Current Location or Map)')),
            ],
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 2. Validate delivery address details are provided
    if (_deliveryAddressController.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter delivery address details (building, floor, etc.)')),
      );
      return;
    }

    // 3. REQUIRED: Validate M-Pesa phone number for payment
    if (_mpesaPhoneController.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.payment, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Please enter your M-Pesa phone number for payment')),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 3. Check item availability
    final menuProvider = context.read<MenuProvider>();
    final cartProvider = context.read<CartProvider>();

    final unavailableItems = widget.selectedItems.where(
      (item) => !menuProvider.isItemAvailable(item.mealTitle)
    ).toList();

    if (unavailableItems.isNotEmpty) {
      if (!mounted) return;
      _showUnavailableItemsDialog(unavailableItems, cartProvider);
      return;
    }

    // Process order directly
    if (!mounted) return;
    _processOrder();
  }

  // ADDED: Method to show dialog for unavailable items
  void _showUnavailableItemsDialog(List<CartItem> unavailableItems, CartProvider cart) {
    // Remove unavailable items
    for (final item in unavailableItems) {
      cart.removeItem(item.id);
    }

    // Build content widgets explicitly
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

    // Show dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Items Unavailable'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: contentWidgets,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            child: const Text('Back to Menu'),
          ),
        ],
      ),
    );
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

  // UPDATED: Process order with M-Pesa payment
  void _processOrder() async {
    setState(() => _isProcessing = true);

    try {
      final auth = context.read<AuthService>();
      final cartProvider = context.read<CartProvider>();
      final currentUser = auth.currentUser;
      final customerId = currentUser?.id ?? 'guest';
      final customerName = currentUser?.name ?? 'Guest User';
      
      // Validate M-Pesa phone number
      final mpesaPhone = _mpesaPhoneController.text.trim();
      if (mpesaPhone.isEmpty) {
        if (!mounted) return;
        _showErrorSnackBar('Please enter M-Pesa phone number');
        setState(() => _isProcessing = false);
        return;
      }

      // Determine delivery type
      final DeliveryType orderDeliveryType = _deliveryLatLng != null
          ? DeliveryType.delivery
          : DeliveryType.pickup;

      // CHANGED: Prepare order details but DON'T save to database yet
      // Order will be created by backend after payment succeeds
      
      // Create order items data
      final orderItems = widget.selectedItems.map((item) {
        return {
          'id': item.id,
          'menuItemId': item.menuItemId,
          'title': item.mealTitle,
          'quantity': item.quantity,
          'price': item.price,
        };
      }).toList();

      // Prepare order details to send to backend
      final orderDetails = {
        'customerId': customerId,
        'customerName': customerName,
        'deliveryPhone': _phoneController.text.isNotEmpty ? _phoneController.text : null,
        'items': orderItems,
        'subtotal': subtotalAmount,
        'deliveryFee': orderDeliveryType == DeliveryType.delivery ? _deliveryFee : 0,
        'tax': tax,
        'totalAmount': totalAmount,
        'deliveryType': orderDeliveryType.name,
        'deliveryAddress': _deliveryAddressController.text.isNotEmpty
            ? {'address': _deliveryAddressController.text}
            : null,
      };

      // Format phone number for M-Pesa
      final formattedPhone = MpesaService.formatPhoneNumber(mpesaPhone);

      // Initiate M-Pesa payment (backend will create order after payment confirms)
      debugPrint('💳 Initiating M-Pesa payment...');
      final paymentResult = await MpesaService.initiateStkPush(
        phoneNumber: mpesaPhone,
        amount: totalAmount,
        userId: customerId,
        orderDetails: orderDetails, // ADDED: Send order details to backend
      );

      if (!mounted) {
        setState(() => _isProcessing = false);
        return;
      }

      if (paymentResult['success'] == true) {
        debugPrint('✅ STK push initiated successfully');
        
        // Clear cart items after successful payment initiation
        for (final item in widget.selectedItems) {
          cartProvider.removeItem(item.id);
        }

        // Navigate to M-Pesa confirmation screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MpesaPaymentConfirmationScreen(
              orderId: null, // CHANGED: No order ID yet
              totalAmount: totalAmount,
              checkoutRequestId: paymentResult['checkoutRequestID'],
              phoneNumber: formattedPhone,
            ),
          ),
        );
      } else {
        // Payment initiation failed
        debugPrint('❌ Payment initiation failed: ${paymentResult['error']}');
        
        if (!mounted) return;
        _showErrorSnackBar(
          paymentResult['error'] ?? 'Failed to initiate payment. Please try again.',
        );
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      debugPrint('❌ Error processing order: $e');
      
      if (!mounted) {
        setState(() => _isProcessing = false);
        return;
      }

      _showErrorSnackBar('Order processing failed: $e');
      setState(() => _isProcessing = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
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

          // ADDED: Delivery Fee
          if (_deliveryLatLng != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Delivery Fee', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                  Text(
                    'KES $_deliveryFee',
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: AppColors.primary),
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
                  Text(
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
                  hintText: 'Enter your phone number (e.g., 0712345678)',
                  prefixText: '+254 ',
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

  Widget _buildPayButton() {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.success, AppColors.success.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withOpacity(0.3),
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
                  Icon(Icons.check_circle, color: AppColors.white), // UPDATED: Changed icon
                  SizedBox(width: 8),
                  Text(
                    'Complete Order', // UPDATED: Simplified text
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                  ),
                ],
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
      ), // FIXED: Removed the misplaced closing brace '}' here
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
}