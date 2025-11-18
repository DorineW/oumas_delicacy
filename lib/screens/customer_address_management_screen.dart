// lib/screens/customer_address_management_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../models/user_address.dart';
import '../providers/address_provider.dart';
import '../providers/location_provider.dart';

class CustomerAddressManagementScreen extends StatefulWidget {
  const CustomerAddressManagementScreen({super.key});

  @override
  State<CustomerAddressManagementScreen> createState() =>
      _CustomerAddressManagementScreenState();
}

class _CustomerAddressManagementScreenState
    extends State<CustomerAddressManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AddressProvider>().loadAddresses();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Delivery Addresses'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Consumer<AddressProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.addresses.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.addresses.length,
            itemBuilder: (context, index) {
              final address = provider.addresses[index];
              return _buildAddressCard(address, provider);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAddressDialog(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_location, color: Colors.white),
        label: const Text('Add Address', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No delivery addresses yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first delivery address',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard(UserAddress address, AddressProvider provider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                  child: Icon(
                    _getIconForLabel(address.label),
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            address.label,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (address.isDefault) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'DEFAULT',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        address.descriptiveDirections,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (address.streetAddress != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          address.streetAddress!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!address.isDefault)
                  TextButton.icon(
                    onPressed: () async {
                      final success = await provider.setDefaultAddress(address.id);
                      if (mounted && success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Default address updated'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Set Default'),
                  ),
                TextButton.icon(
                  onPressed: () => _showEditAddressDialog(address),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _confirmDelete(address, provider),
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForLabel(String label) {
    final lowerLabel = label.toLowerCase();
    if (lowerLabel.contains('home')) return Icons.home;
    if (lowerLabel.contains('work') || lowerLabel.contains('office')) return Icons.work;
    if (lowerLabel.contains('school')) return Icons.school;
    if (lowerLabel.contains('gym')) return Icons.fitness_center;
    return Icons.location_on;
  }

  void _showAddAddressDialog() {
    _showAddressForm();
  }

  void _showEditAddressDialog(UserAddress address) {
    _showAddressForm(address: address);
  }

  void _showAddressForm({UserAddress? address}) {
    final isEdit = address != null;
    final labelController = TextEditingController(text: address?.label ?? '');
    final directionsController = TextEditingController(
      text: address?.descriptiveDirections ?? '',
    );
    final streetController = TextEditingController(
      text: address?.streetAddress ?? '',
    );
    double? selectedLat = address?.latitude;
    double? selectedLon = address?.longitude;
    bool setAsDefault = address?.isDefault ?? false;

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Address' : 'Add New Address'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: labelController,
                    decoration: const InputDecoration(
                      labelText: 'Label (e.g., Home, Office)',
                      prefixIcon: Icon(Icons.label),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a label';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: directionsController,
                    decoration: const InputDecoration(
                      labelText: 'Directions/Landmarks',
                      prefixIcon: Icon(Icons.directions),
                      border: OutlineInputBorder(),
                      hintText: 'e.g., Near the big mango tree, blue gate',
                    ),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter directions';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: streetController,
                    decoration: const InputDecoration(
                      labelText: 'Street Address (Optional)',
                      prefixIcon: Icon(Icons.home),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 20, color: AppColors.primary),
                              const SizedBox(width: 8),
                              const Text(
                                'Location Coordinates',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (selectedLat != null && selectedLon != null) ...[
                            Text(
                              'Lat: ${selectedLat!.toStringAsFixed(6)}\n'
                              'Lon: ${selectedLon!.toStringAsFixed(6)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ] else ...[
                            const Text(
                              'No coordinates set',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final locationProvider = context.read<LocationProvider>();
                              await locationProvider.initializeLocation();
                              
                              if (locationProvider.latitude != null &&
                                  locationProvider.longitude != null) {
                                setDialogState(() {
                                  selectedLat = locationProvider.latitude;
                                  selectedLon = locationProvider.longitude;
                                });
                                
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Current location captured'),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.my_location, size: 18),
                            label: const Text('Use Current Location'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    value: setAsDefault,
                    onChanged: (value) {
                      setDialogState(() {
                        setAsDefault = value ?? false;
                      });
                    },
                    title: const Text('Set as default address'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  if (selectedLat == null || selectedLon == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please set location coordinates'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  Navigator.pop(context);

                  final provider = context.read<AddressProvider>();
                  bool success;

                  if (isEdit) {
                    success = await provider.updateAddress(
                      addressId: address.id,
                      label: labelController.text.trim(),
                      latitude: selectedLat,
                      longitude: selectedLon,
                      descriptiveDirections: directionsController.text.trim(),
                      streetAddress: streetController.text.trim().isEmpty
                          ? null
                          : streetController.text.trim(),
                      isDefault: setAsDefault,
                    );
                  } else {
                    final newAddress = await provider.addAddress(
                      label: labelController.text.trim(),
                      latitude: selectedLat!,
                      longitude: selectedLon!,
                      descriptiveDirections: directionsController.text.trim(),
                      streetAddress: streetController.text.trim().isEmpty
                          ? null
                          : streetController.text.trim(),
                      setAsDefault: setAsDefault,
                    );
                    success = newAddress != null;
                  }

                  if (mounted && success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isEdit
                              ? 'Address updated successfully'
                              : 'Address added successfully',
                        ),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(isEdit ? 'Update' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(UserAddress address, AddressProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Address'),
        content: Text(
          'Are you sure you want to delete "${address.label}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await provider.deleteAddress(address.id);

      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Address deleted'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }
}
