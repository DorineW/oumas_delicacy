// lib/screens/admin/admin_location_management_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../providers/location_management_provider.dart';
import '../../providers/location_provider.dart';
import '../../models/location.dart';

class AdminLocationManagementScreen extends StatefulWidget {
  const AdminLocationManagementScreen({super.key});

  @override
  State<AdminLocationManagementScreen> createState() => _AdminLocationManagementScreenState();
}

class _AdminLocationManagementScreenState extends State<AdminLocationManagementScreen> {
  Location? _selectedLocation;
  bool _isFormMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LocationManagementProvider>(context, listen: false).loadLocations();
    });
  }

  void _showLocationForm([Location? location]) {
    setState(() {
      _selectedLocation = location;
      _isFormMode = true;
    });
  }

  void _hideLocationForm() {
    setState(() {
      _selectedLocation = null;
      _isFormMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = context.watch<LocationManagementProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isFormMode 
          ? (_selectedLocation != null ? 'Edit Location' : 'Add Location')
          : 'Location Management'
        ),
        backgroundColor: AppColors.primary,
        elevation: 4,
        iconTheme: const IconThemeData(color: AppColors.white),
        titleTextStyle: const TextStyle(
          color: AppColors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        leading: _isFormMode
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _hideLocationForm,
            )
          : IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
      ),
      body: _isFormMode
          ? _LocationFormView(
              location: _selectedLocation,
              onSaved: () {
                _hideLocationForm();
                locationProvider.loadLocations();
              },
            )
          : locationProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : locationProvider.locations.isEmpty
                  ? _buildEmptyState()
                  : _buildLocationsList(locationProvider),
      floatingActionButton: !_isFormMode
          ? FloatingActionButton.extended(
              onPressed: () => _showLocationForm(),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_location, color: AppColors.white),
              label: const Text('Add Location', style: TextStyle(color: AppColors.white)),
            )
          : null,
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
            'No locations yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first restaurant or store location',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationsList(LocationManagementProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.locations.length,
      itemBuilder: (context, index) {
        final location = provider.locations[index];
        return _buildLocationCard(location);
      },
    );
  }

  Widget _buildLocationCard(Location location) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: () => _showLocationForm(location),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: location.isActive
                          ? AppColors.success.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getLocationIcon(location.locationType),
                      color: location.isActive ? AppColors.success : Colors.grey,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          location.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getLocationTypeColor(location.locationType).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                location.locationType,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _getLocationTypeColor(location.locationType),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: location.isActive
                                    ? AppColors.success.withOpacity(0.1)
                                    : Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                location.isActive ? 'Active' : 'Inactive',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: location.isActive ? AppColors.success : Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) => _handleMenuAction(value, location),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'toggle_status',
                        child: Row(
                          children: [
                            Icon(
                              location.isActive ? Icons.pause_circle : Icons.play_circle,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(location.isActive ? 'Deactivate' : 'Activate'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Delivery settings info
              if (location.deliveryRadiusKm != null || location.deliveryBaseFee != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.lightGray.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.delivery_dining, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          const Text(
                            'Delivery Settings',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (location.deliveryRadiusKm != null)
                            Expanded(
                              child: _buildInfoChip(
                                icon: Icons.radio_button_checked,
                                label: 'Radius',
                                value: '${location.deliveryRadiusKm}km',
                              ),
                            ),
                          if (location.deliveryBaseFee != null) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildInfoChip(
                                icon: Icons.attach_money,
                                label: 'Base Fee',
                                value: 'KES ${location.deliveryBaseFee}',
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (location.deliveryRatePerKm != null) ...[
                        const SizedBox(height: 8),
                        _buildInfoChip(
                          icon: Icons.timeline,
                          label: 'Per Km',
                          value: 'KES ${location.deliveryRatePerKm}/km',
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.darkText,
          ),
        ),
      ],
    );
  }

  IconData _getLocationIcon(String type) {
    switch (type) {
      case 'Restaurant':
        return Icons.restaurant;
      case 'General Store':
        return Icons.store;
      case 'Warehouse':
        return Icons.warehouse;
      default:
        return Icons.location_on;
    }
  }

  Color _getLocationTypeColor(String type) {
    switch (type) {
      case 'Restaurant':
        return Colors.orange;
      case 'General Store':
        return Colors.blue;
      case 'Warehouse':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  void _handleMenuAction(String action, Location location) {
    switch (action) {
      case 'edit':
        _showLocationForm(location);
        break;
      case 'toggle_status':
        _toggleLocationStatus(location);
        break;
      case 'delete':
        _confirmDelete(location);
        break;
    }
  }

  Future<void> _toggleLocationStatus(Location location) async {
    final provider = Provider.of<LocationManagementProvider>(context, listen: false);
    final success = await provider.toggleLocationStatus(location.id);

    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            location.isActive
                ? '${location.name} deactivated'
                : '${location.name} activated',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _confirmDelete(Location location) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Location'),
        content: Text(
          'Are you sure you want to delete "${location.name}"? This action cannot be undone.',
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
      final provider = Provider.of<LocationManagementProvider>(context, listen: false);
      final success = await provider.deleteLocation(location.id);

      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${location.name} deleted'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }
}

// FORM VIEW WIDGET - Embedded form to avoid separate screen
class _LocationFormView extends StatefulWidget {
  final Location? location;
  final VoidCallback onSaved;

  const _LocationFormView({
    this.location,
    required this.onSaved,
  });

  @override
  State<_LocationFormView> createState() => _LocationFormViewState();
}

class _LocationFormViewState extends State<_LocationFormView> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _latController;
  late TextEditingController _lonController;
  late TextEditingController _deliveryRadiusController;
  late TextEditingController _baseFeeController;
  late TextEditingController _ratePerKmController;
  late TextEditingController _minimumOrderController;
  late TextEditingController _freeDeliveryThresholdController;
  
  String _selectedType = 'Restaurant';
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
    _nameController = TextEditingController(text: widget.location?.name ?? '');
    _addressController = TextEditingController(text: widget.location?.displayAddress ?? '');
    _latController = TextEditingController(text: widget.location?.lat?.toString() ?? '');
    _lonController = TextEditingController(text: widget.location?.lon?.toString() ?? '');
    _deliveryRadiusController = TextEditingController(
      text: widget.location?.deliveryRadiusKm?.toString() ?? '10',
    );
    _baseFeeController = TextEditingController(
      text: widget.location?.deliveryBaseFee?.toString() ?? '50',
    );
    _ratePerKmController = TextEditingController(
      text: widget.location?.deliveryRatePerKm?.toString() ?? '20',
    );
    _minimumOrderController = TextEditingController(
      text: widget.location?.minimumOrderAmount?.toString() ?? '200',
    );
    _freeDeliveryThresholdController = TextEditingController(
      text: widget.location?.freeDeliveryThreshold?.toString() ?? '1000',
    );
    
    _selectedType = widget.location?.locationType ?? 'Restaurant';
    _isActive = widget.location?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lonController.dispose();
    _deliveryRadiusController.dispose();
    _baseFeeController.dispose();
    _ratePerKmController.dispose();
    _minimumOrderController.dispose();
    _freeDeliveryThresholdController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    try {
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      await locationProvider.initializeLocation();
      
      if (locationProvider.latitude != null && locationProvider.longitude != null) {
        setState(() {
          _latController.text = locationProvider.latitude.toString();
          _lonController.text = locationProvider.longitude.toString();
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Current location loaded'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveLocation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final provider = Provider.of<LocationManagementProvider>(context, listen: false);
      
      final name = _nameController.text.trim();
      final lat = double.parse(_latController.text);
      final lon = double.parse(_lonController.text);
      final deliveryRadius = double.parse(_deliveryRadiusController.text);
      final baseFee = int.parse(_baseFeeController.text);
      final ratePerKm = int.parse(_ratePerKmController.text);
      final minimumOrder = int.parse(_minimumOrderController.text);
      final freeDeliveryThreshold = int.parse(_freeDeliveryThresholdController.text);

      bool success;
      if (widget.location != null) {
        success = await provider.updateLocation(
          locationId: widget.location!.id,
          name: name,
          lat: lat,
          lon: lon,
          address: {'display': _addressController.text.trim()},
          isActive: _isActive,
          deliveryRadiusKm: deliveryRadius,
          deliveryBaseFee: baseFee,
          deliveryRatePerKm: ratePerKm,
          minimumOrderAmount: minimumOrder,
          freeDeliveryThreshold: freeDeliveryThreshold,
        );
      } else {
        final newLocation = await provider.addLocation(
          name: name,
          locationType: _selectedType,
          lat: lat,
          lon: lon,
          address: {'display': _addressController.text.trim()},
          deliveryRadiusKm: deliveryRadius,
          deliveryBaseFee: baseFee,
          deliveryRatePerKm: ratePerKm,
          minimumOrderAmount: minimumOrder,
          freeDeliveryThreshold: freeDeliveryThreshold,
        );
        success = newLocation != null;
      }

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.location != null
                    ? 'Location updated successfully'
                    : 'Location added successfully',
              ),
              backgroundColor: AppColors.success,
            ),
          );
          widget.onSaved();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error saving location'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionCard(
            title: 'Basic Information',
            icon: Icons.info_outline,
            children: [
              _buildTextField(
                controller: _nameController,
                label: 'Location Name',
                hint: 'e.g., Downtown Restaurant',
                icon: Icons.location_city,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              _buildDropdownField(
                value: _selectedType,
                label: 'Location Type',
                icon: Icons.category,
                items: const ['Restaurant', 'General Store', 'Warehouse'],
                onChanged: (value) => setState(() => _selectedType = value!),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _addressController,
                label: 'Address',
                hint: 'Full street address',
                icon: Icons.location_on,
                maxLines: 2,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Address is required' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _latController,
                      label: 'Latitude',
                      hint: 'e.g., -1.286389',
                      icon: Icons.pin_drop,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      validator: _validateCoordinate,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _lonController,
                      label: 'Longitude',
                      hint: 'e.g., 36.817223',
                      icon: Icons.pin_drop,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      validator: _validateCoordinate,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _useCurrentLocation,
                icon: const Icon(Icons.my_location, size: 18),
                label: const Text('Use Current Location'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  foregroundColor: AppColors.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildSectionCard(
            title: 'Delivery Settings',
            icon: Icons.delivery_dining,
            children: [
              _buildTextField(
                controller: _deliveryRadiusController,
                label: 'Delivery Radius (km)',
                hint: 'Maximum delivery distance',
                icon: Icons.radio_button_checked,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _validatePositiveNumber,
                suffix: const Text('km', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _baseFeeController,
                label: 'Base Delivery Fee (KES)',
                hint: 'Starting fee from 0km',
                icon: Icons.attach_money,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _validatePositiveNumber,
                suffix: const Text('KES', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _ratePerKmController,
                label: 'Rate Per Kilometer (KES)',
                hint: 'Additional cost per km',
                icon: Icons.timeline,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _validatePositiveNumber,
                suffix: const Text('KES/km', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(height: 16),
              _buildDeliveryPreview(),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildSectionCard(
            title: 'Order Requirements',
            icon: Icons.shopping_cart,
            children: [
              _buildTextField(
                controller: _minimumOrderController,
                label: 'Minimum Order Amount (KES)',
                hint: 'Minimum total for delivery',
                icon: Icons.shopping_bag,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _validatePositiveNumber,
                suffix: const Text('KES', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _freeDeliveryThresholdController,
                label: 'Free Delivery Threshold (KES)',
                hint: 'Amount for free delivery',
                icon: Icons.local_shipping,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _validatePositiveNumber,
                suffix: const Text('KES', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildSectionCard(
            title: 'Status',
            icon: Icons.toggle_on,
            children: [
              SwitchListTile(
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
                title: const Text('Location Active'),
                subtitle: Text(
                  _isActive
                      ? 'Location is visible and accepting orders'
                      : 'Location is hidden from customers',
                ),
                activeColor: AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          ElevatedButton(
            onPressed: _isLoading ? null : _saveLocation,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(AppColors.white),
                    ),
                  )
                : Text(
                    widget.location != null ? 'Save Changes' : 'Add Location',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Widget? suffix,
    int? maxLines,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines ?? 1,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        suffix: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      validator: validator,
    );
  }

  Widget _buildDropdownField({
    required String value,
    required String label,
    required IconData icon,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      items: items.map((item) => DropdownMenuItem(
        value: item,
        child: Text(item),
      )).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildDeliveryPreview() {
    final radius = double.tryParse(_deliveryRadiusController.text) ?? 0;
    final baseFee = double.tryParse(_baseFeeController.text) ?? 0;
    final rate = double.tryParse(_ratePerKmController.text) ?? 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightGray.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Delivery Fee Examples',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildFeeExample('0.5 km', baseFee + (0.5 * rate)),
          _buildFeeExample('2 km', baseFee + (2 * rate)),
          _buildFeeExample('5 km', baseFee + (5 * rate)),
          _buildFeeExample('$radius km (max)', baseFee + (radius * rate)),
        ],
      ),
    );
  }

  Widget _buildFeeExample(String distance, double fee) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            distance,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          Text(
            'KES ${fee.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
            ),
          ),
        ],
      ),
    );
  }

  String? _validateCoordinate(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    final num = double.tryParse(value);
    if (num == null) return 'Invalid number';
    return null;
  }

  String? _validatePositiveNumber(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    final num = double.tryParse(value);
    if (num == null) return 'Invalid number';
    if (num < 0) return 'Must be positive';
    return null;
  }
}
