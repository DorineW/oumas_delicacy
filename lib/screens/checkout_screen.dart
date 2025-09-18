// lib/screens/checkout_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart' show Position;
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;

import '../models/cart_item.dart';
import '../models/order.dart' show DeliveryType;
import '../services/location_service.dart';
import '../services/auth_service.dart';
import '../constants/colors.dart';
import 'location.dart'; // LocationScreen

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
  LatLng? _deliveryLatLng; // we store lat/lng here (safer than constructing Position)
  bool _isLocationLoading = false;
  bool _showDeliveryFields = false;
  bool _isProcessing = false;

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _mpesaPhoneController = TextEditingController();
  final TextEditingController _deliveryAddressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final defaultPhone = widget.defaultPhoneNumber ?? '712345678';
    _phoneController.text = defaultPhone;
    _mpesaPhoneController.text = defaultPhone;
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
          _showDeliveryFields = true;
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
          _showDeliveryFields = true;
        });
        return;
      }

      // If LocationScreen returned a LatLng (google maps)
      if (result is LatLng) {
        setState(() {
          _deliveryLatLng = result;
          _showDeliveryFields = true;
        });
        return;
      }

      // If it returned a Map or other structure with lat/lng keys
      if (result is Map && result.containsKey('latitude') && result.containsKey('longitude')) {
        final lat = result['latitude'];
        final lng = result['longitude'];
        if (lat is num && lng is num) {
          setState(() {
            _deliveryLatLng = LatLng(lat.toDouble(), lng.toDouble());
            _showDeliveryFields = true;
          });
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

  bool _validateInputs() {
    if (_showDeliveryFields && _deliveryAddressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter delivery address details')),
      );
      return false;
    }

    if (_selectedMethod == PaymentMethod.cash && _phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter phone number for delivery updates')),
      );
      return false;
    }

    if (_selectedMethod == PaymentMethod.mpesa && _mpesaPhoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter M-Pesa phone number')),
      );
      return false;
    }

    return true;
  }

  Future<void> _payNow() async {
    if (!_validateInputs()) return;

    setState(() => _isProcessing = true);
    try {
      // Simulate processing
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      final auth = Provider.of<AuthService>(context, listen: false);
      final customerId = auth.currentUser?.id ?? 'guest';
      final customerName = auth.currentUser?.name ?? 'Guest';

      Navigator.pushNamed(
        context,
        '/confirmation',
        arguments: {
          'items': widget.selectedItems,
          'deliveryType': _deliveryLatLng != null ? DeliveryType.delivery : DeliveryType.pickup,
          'totalAmount': totalAmount,
          'paymentMethod': _selectedMethod == PaymentMethod.cash ? 'Cash on Delivery' : 'M-Pesa',
          'customerId': customerId,
          'customerName': customerName,
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment failed: $e')));
    } finally {
      if (!mounted) return;
      setState(() => _isProcessing = false);
    }
  }

  Widget _buildDeliverySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text('Delivery Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        if (_deliveryLatLng == null)
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLocationLoading ? null : _getUserLocation,
                  icon: _isLocationLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location),
                  label: Text(_isLocationLoading ? 'Getting location...' : 'Use Current Location'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _selectLocationOnMap,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Select on Map'),
                ),
              ),
            ],
          ),
        if (_deliveryLatLng != null) ...[
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.location_on, color: Colors.green),
            title: const Text('Delivery location selected'),
            subtitle: Text('Lat: ${_deliveryLatLng!.latitude.toStringAsFixed(5)}, '
                'Lng: ${_deliveryLatLng!.longitude.toStringAsFixed(5)}'),
            trailing: IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: _selectLocationOnMap,
              tooltip: 'Edit on map',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _deliveryAddressController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Delivery Address Details',
              hintText: 'Building name, floor, apartment, landmark...',
              border: OutlineInputBorder(),
              filled: true,
            ),
          ),
          const SizedBox(height: 8),
          const Text('Delivery fee: KES 150', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ],
    );
  }

  Widget _buildSelectedItemsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Order Summary:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...widget.selectedItems.map((item) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text('${item.mealTitle} x${item.quantity}')),
                Text('KES ${item.price * item.quantity}'),
              ],
            ),
          );
        }),
        const Divider(height: 20, thickness: 1.5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('KES $totalAmount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentOption(PaymentMethod method, String title, String subtitle, IconData icon) {
    return Card(
      color: AppColors.cardBackground,
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkText)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.darkText)),
        ]),
        trailing: Radio<PaymentMethod>(
          value: method,
          groupValue: _selectedMethod,
          activeColor: AppColors.primary,
          onChanged: (v) {
            if (v == null) return;
            setState(() => _selectedMethod = v);
          },
        ),
        onTap: () => setState(() => _selectedMethod = method),
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
        foregroundColor: AppColors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildSelectedItemsList(),
          _buildDeliverySection(),
          const SizedBox(height: 20),
          const Text('Select Payment Method', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildPaymentOption(PaymentMethod.cash, 'Cash on Delivery', 'Pay with cash when delivered', Icons.money),
          if (_selectedMethod == PaymentMethod.cash) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number for delivery updates',
                prefixText: '+254 ',
                border: OutlineInputBorder(),
                filled: true,
              ),
            ),
          ],
          const SizedBox(height: 14),
          _buildPaymentOption(PaymentMethod.mpesa, 'M-Pesa', 'Pay securely via M-Pesa', Icons.phone_android),
          if (_selectedMethod == PaymentMethod.mpesa) ...[
            const SizedBox(height: 12),
            const Card(
              color: AppColors.cardBackground,
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('M-Pesa Till Number', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  SizedBox(height: 6),
                  Text('123456', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text('Use this till number when making payment'),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _mpesaPhoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Your M-Pesa Phone Number',
                prefixText: '+254 ',
                border: OutlineInputBorder(),
                filled: true,
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _payNow,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isProcessing
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white))
                  : const Text('Pay Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }
}
