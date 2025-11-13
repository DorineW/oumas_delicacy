import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ADDED

import '../constants/colors.dart';
import '../services/auth_service.dart';
import 'location.dart'; // ADDED
import '../utils/phone_utils.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailCont = TextEditingController();
  final _phoneCont = TextEditingController();
  final _oldPasswordCont = TextEditingController();
  final _newPasswordCont = TextEditingController();
  bool _notificationsEnabled = true;

  File? _profileImageFile;
  final ImagePicker _picker = ImagePicker();

  bool _isSaving = false;

  List<String> _addresses = [];
  int? _defaultAddressIndex;

  // payment stored as map (simple): { 'brand': 'Visa', 'last4': '4242' }
  Map<String, String>? _paymentMethod;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.currentUser;
    
    // FIXED: Handle nullable values properly
    _nameController.text = user?.name ?? '';
    _emailCont.text = user?.email ?? '';
    _phoneCont.text = user?.phone ?? '';
    
    // ADDED: Load saved profile data
    _loadSavedProfile();
  }

  Future<void> _loadSavedProfile() async {
    // Load from Supabase FIRST (source of truth)
    final auth = Provider.of<AuthService>(context, listen: false);
    final currentUser = auth.currentUser;
    
    if (currentUser != null) {
      setState(() {
        _nameController.text = currentUser.name ?? ''; // FIXED: Handle null
        _emailCont.text = currentUser.email;
        _phoneCont.text = currentUser.phone == null
            ? ''
            : PhoneUtils.toLocalDisplay(currentUser.phone!);
      });
    }
    
    // THEN load local preferences (addresses, payment, image)
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      // Don't override name/email/phone from SharedPreferences if we got them from Supabase
      if (_nameController.text.isEmpty) {
        _nameController.text = prefs.getString('name') ?? '';
      }
      if (_emailCont.text.isEmpty) {
        _emailCont.text = prefs.getString('email') ?? '';
      }
      if (_phoneCont.text.isEmpty) {
        final p = prefs.getString('phone');
        _phoneCont.text = p == null ? '' : PhoneUtils.toLocalDisplay(p);
      }
      
      _notificationsEnabled = prefs.getBool('notifications') ?? true;

      final addressesJson = prefs.getStringList('addresses') ?? [];
      _addresses = List<String>.from(addressesJson);
      _defaultAddressIndex = prefs.getInt('defaultAddressIndex');

      final pmJson = prefs.getString('paymentMethod');
      if (pmJson != null) {
        _paymentMethod = Map<String, String>.from(jsonDecode(pmJson));
      }

      final profilePath = prefs.getString('profileImagePath');
      if (profilePath != null && profilePath.isNotEmpty) {
        final f = File(profilePath);
        if (f.existsSync()) _profileImageFile = f;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailCont.dispose();
    _phoneCont.dispose();
    _oldPasswordCont.dispose();
    _newPasswordCont.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? picked = await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 800,
    );
    if (picked != null) {
      setState(() {
        _profileImageFile = File(picked.path);
      });
    }
  }

  String _maskCard(String last4) => '**** **** **** $last4';

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final userId = auth.currentUser?.id;
      
      if (userId == null) throw Exception('Not logged in');

      // Update in Supabase
      final normalizedPhone = PhoneUtils.normalizeKenyan(_phoneCont.text);

      await Supabase.instance.client
          .from('users')
          .update({
            'name': _nameController.text.trim(),
        'phone': normalizedPhone,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('auth_id', userId);

      // ADDED: Save to SharedPreferences for offline access and checkout screen
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('name', _nameController.text.trim());
      await prefs.setString('email', _emailCont.text.trim());
      await prefs.setString('phone', normalizedPhone);
      await prefs.setBool('notifications', _notificationsEnabled);
      
      // Save addresses
      await prefs.setStringList('addresses', _addresses);
      if (_defaultAddressIndex != null) {
        await prefs.setInt('defaultAddressIndex', _defaultAddressIndex!);
      }
      
      // Save payment method
      if (_paymentMethod != null) {
        await prefs.setString('paymentMethod', jsonEncode(_paymentMethod!));
      } else {
        await prefs.remove('paymentMethod');
      }
      
      // Save profile image path
      if (_profileImageFile != null) {
        await prefs.setString('profileImagePath', _profileImageFile!.path);
      } else {
        await prefs.remove('profileImagePath');
      }

      // Force refresh from DB
      await Future.delayed(const Duration(milliseconds: 300));
      await auth.refreshProfile(); // FIXED: Use public method to refresh current user
      
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: AppColors.success,
        ),
      );

      Navigator.pop(context); // go back to profile screen
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _changePasswordDialog() async {
    _oldPasswordCont.clear();
    _newPasswordCont.clear();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _oldPasswordCont,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current Password'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _newPasswordCont,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              final newPass = _newPasswordCont.text.trim();
              if (newPass.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('New password must be at least 6 characters')),
                );
                return;
              }
              // In real app, call API to change password; here we simulate success
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password changed')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _addAddressDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Delivery Address'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'e.g. 12 Baker St, Nairobi'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              final val = controller.text.trim();
              if (val.isEmpty) return;
              setState(() {
                _addresses.add(val);
                // if this is first address, set default
                _defaultAddressIndex ??= 0;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _addPaymentDialog() async {
    final brandCtrl = TextEditingController();
    final last4Ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Payment Method'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: brandCtrl, decoration: const InputDecoration(labelText: 'Card Brand (e.g. Visa)')),
            TextField(controller: last4Ctrl, decoration: const InputDecoration(labelText: 'Last 4 digits')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              final brand = brandCtrl.text.trim();
              final last4 = last4Ctrl.text.trim();
              if (brand.isEmpty || last4.length != 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter brand and valid last 4 digits')),
                );
                return;
              }
              setState(() {
                _paymentMethod = {'brand': brand, 'last4': last4};
              });
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _removeAddress(int idx) {
    setState(() {
      _addresses.removeAt(idx);
      if (_defaultAddressIndex != null) {
        if (_addresses.isEmpty) {
          _defaultAddressIndex = null;
        } else if (_defaultAddressIndex! >= _addresses.length) {
          _defaultAddressIndex = _addresses.length - 1;
        }
      }
    });
  }

  String? _validateEmail(String? v) {
    final val = v?.trim() ?? '';
    if (val.isEmpty) return 'Email required';
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(val)) return 'Invalid email';
    return null;
  }

  String? _validatePhone(String? v) {
    final val = v?.trim() ?? '';
    if (val.isEmpty) return 'Phone required';
    final digits = val.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 6) return 'Enter a valid phone number';
    return null;
  }

  // ADDED: Navigate to location screen for address selection
  Future<void> _selectAddressFromMap() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => const LocationScreen(),
      ),
    );

    if (result != null && mounted) {
      final address = result['address'] as String;
      
      // Add to addresses list
      setState(() {
        _addresses.add(address);
        // Set as default if first address
        _defaultAddressIndex ??= _addresses.length - 1;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Address added successfully')),
            ],
          ),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Edit Profile'),
          backgroundColor: AppColors.primary,
          elevation: 4,
          iconTheme: const IconThemeData(color: AppColors.white),
          titleTextStyle: const TextStyle(
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        body: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(isLandscape ? 12 : 16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                SizedBox(height: isLandscape ? 12 : 16),
                // UPDATED: Profile image with icon fallback like profile_screen
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: isLandscape ? 100 : 120,
                      height: isLandscape ? 100 : 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary.withOpacity(0.3),
                            AppColors.primary.withOpacity(0.1),
                          ],
                        ),
                      ),
                    ),
                    CircleAvatar(
                      radius: isLandscape ? 45 : 55,
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      backgroundImage: _profileImageFile != null
                          ? FileImage(_profileImageFile!) as ImageProvider
                          : null,
                      child: _profileImageFile == null
                          ? Icon(
                              Icons.person,
                              size: isLandscape ? 45 : 55,
                              color: AppColors.primary,
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: isLandscape ? 10 : 15,
                      child: Material(
                        elevation: 4,
                        shape: const CircleBorder(),
                        child: PopupMenuButton<int>(
                          onSelected: (v) {
                            if (v == 0) _pickImage(ImageSource.camera);
                            if (v == 1) _pickImage(ImageSource.gallery);
                            if (v == 2) setState(() => _profileImageFile = null);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 0, child: Row(children: [Icon(Icons.camera_alt), SizedBox(width: 8), Text('Camera')])),
                            PopupMenuItem(value: 1, child: Row(children: [Icon(Icons.photo_library), SizedBox(width: 8), Text('Gallery')])),
                            PopupMenuItem(value: 2, child: Row(children: [Icon(Icons.delete), SizedBox(width: 8), Text('Remove')])),
                          ],
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit, size: 18, color: AppColors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isLandscape ? 20 : 24),

                // UPDATED: Section header
                _buildSectionHeader('Personal Information', Icons.person),
                SizedBox(height: isLandscape ? 8 : 12),
                
                // UPDATED: Modern text fields
                _buildModernTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  icon: Icons.person_outline,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Name required' : null,
                ),
                SizedBox(height: isLandscape ? 10 : 12),
                
                _buildModernTextField(
                  controller: _emailCont,
                  label: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),
                SizedBox(height: isLandscape ? 10 : 12),
                
                _buildModernTextField(
                  controller: _phoneCont,
                  label: 'Phone Number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: _validatePhone,
                ),
                SizedBox(height: isLandscape ? 16 : 20),

                // UPDATED: Notifications toggle
                Container(
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
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.notifications_outlined, color: AppColors.primary, size: 20),
                    ),
                    title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Receive order updates', style: TextStyle(fontSize: 12, color: AppColors.darkText.withOpacity(0.6))),
                    trailing: Switch(
                      value: _notificationsEnabled,
                      onChanged: (v) => setState(() => _notificationsEnabled = v),
                      activeColor: AppColors.primary,
                    ),
                  ),
                ),
                SizedBox(height: isLandscape ? 16 : 20),

                // UPDATED: Addresses section
                _buildSectionHeader('Delivery Addresses', Icons.location_on, onAdd: _addAddressDialog),
                SizedBox(height: isLandscape ? 8 : 12),
                
                if (_addresses.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.lightGray.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.location_off, size: 48, color: AppColors.darkText.withOpacity(0.3)),
                        const SizedBox(height: 8),
                        Text('No addresses yet', style: TextStyle(color: AppColors.darkText.withOpacity(0.5))),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _selectAddressFromMap,
                          icon: const Icon(Icons.map),
                          label: const Text('Select from Map'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  // ADDED: Add from map button
                  Column(
                    children: [
                      ..._addresses.asMap().entries.map((e) => _buildAddressCard(e.key, e.value)),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _selectAddressFromMap,
                        icon: const Icon(Icons.map),
                        label: const Text('Add from Map'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                    ],
                  ),
                
                SizedBox(height: isLandscape ? 16 : 20),

                // UPDATED: Payment section
                _buildSectionHeader('Payment Method', Icons.credit_card, onAdd: _addPaymentDialog),
                SizedBox(height: isLandscape ? 8 : 12),
                
                _buildPaymentCard(),
                SizedBox(height: isLandscape ? 16 : 20),

                // UPDATED: Change password button
                OutlinedButton.icon(
                  onPressed: _changePasswordDialog,
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Change Password'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                SizedBox(height: isLandscape ? 20 : 24),

                // UPDATED: Save button with gradient
                Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving
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
                              Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.white)),
                            ],
                          ),
                  ),
                ),
                SizedBox(height: isLandscape ? 20 : 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // NEW: Modern section header
  Widget _buildSectionHeader(String title, IconData icon, {VoidCallback? onAdd}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.darkText,
          ),
        ),
        const Spacer(),
        if (onAdd != null)
          IconButton(
            onPressed: onAdd,
            icon: const Icon(Icons.add_circle, color: AppColors.primary),
            tooltip: 'Add',
          ),
      ],
    );
  }

  // NEW: Modern text field
  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
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
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.primary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: AppColors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  // NEW: Modern address card
  Widget _buildAddressCard(int idx, String addr) {
    final isDefault = _defaultAddressIndex == idx;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDefault ? AppColors.primary : AppColors.lightGray.withOpacity(0.3),
          width: isDefault ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isDefault ? AppColors.primary : AppColors.lightGray).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isDefault ? Icons.home : Icons.location_on_outlined,
            color: isDefault ? AppColors.primary : AppColors.darkText,
            size: 20,
          ),
        ),
        title: Text(
          addr,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: isDefault ? const Text('Default', style: TextStyle(fontSize: 12, color: AppColors.primary)) : null,
        trailing: PopupMenuButton<String>(
          onSelected: (choice) {
            if (choice == 'set_default') {
              setState(() => _defaultAddressIndex = idx);
            } else if (choice == 'remove') {
              _removeAddress(idx);
            } else if (choice == 'edit') {
              _editAddressDialog(idx);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'set_default', child: Row(children: [Icon(Icons.check_circle), SizedBox(width: 8), Text('Set Default')])),
            const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit), SizedBox(width: 8), Text('Edit')])),
            const PopupMenuItem(value: 'remove', child: Row(children: [Icon(Icons.delete), SizedBox(width: 8), Text('Remove')])),
          ],
        ),
      ),
    );
  }

  // NEW: Modern payment card
  Widget _buildPaymentCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGray.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.credit_card, color: AppColors.primary, size: 20),
        ),
        title: Text(
          _paymentMethod != null
              ? '${_paymentMethod!['brand']} • ${_maskCard(_paymentMethod!['last4']!)}'
              : 'No payment method',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: _paymentMethod != null ? const Text('Primary card', style: TextStyle(fontSize: 12)) : null,
        trailing: _paymentMethod != null
            ? IconButton(
                onPressed: () {
                  setState(() => _paymentMethod = null);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Payment method removed')),
                  );
                },
                icon: const Icon(Icons.delete_outline, color: Colors.red),
              )
            : null,
      ),
    );
  }

  // ...existing helper methods (_validateEmail, _validatePhone, etc.)...

  Future<void> _editAddressDialog(int idx) async {
    final controller = TextEditingController(text: _addresses[idx]);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Delivery Address'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'e.g. 12 Baker St, Nairobi'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              final val = controller.text.trim();
              if (val.isEmpty) return;
              setState(() {
                _addresses[idx] = val;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
