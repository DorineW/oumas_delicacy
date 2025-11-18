import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ADDED

import '../constants/colors.dart';
import '../services/auth_service.dart';
import '../utils/phone_utils.dart';
import '../providers/address_provider.dart';
import '../models/user_address.dart';
import 'customer_address_management_screen.dart';

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

  List<UserAddress> _addresses = [];

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
      // Fetch user data from Supabase
      try {
        debugPrint('🔄 Loading user profile from Supabase...');
        final userData = await Supabase.instance.client
            .from('users')
            .select('name, email, phone')
            .eq('auth_id', currentUser.id)
            .single();
        
        debugPrint('✅ User data loaded: $userData');
        
        setState(() {
          _nameController.text = userData['name'] ?? '';
          _emailCont.text = userData['email'] ?? '';
          final phone = userData['phone'];
          _phoneCont.text = phone == null ? '' : PhoneUtils.toLocalDisplay(phone);
        });
        
        // Load addresses from UserAddresses table via AddressProvider
        final addressProvider = Provider.of<AddressProvider>(context, listen: false);
        await addressProvider.loadAddresses();
        
        setState(() {
          _addresses = List.from(addressProvider.addresses);
        });
        
        debugPrint('✅ Loaded ${_addresses.length} addresses from UserAddresses table');
      } catch (e) {
        debugPrint('⚠️ Error loading user data from Supabase: $e');
        // Fallback to basic user info
        setState(() {
          _nameController.text = currentUser.name ?? '';
          _emailCont.text = currentUser.email;
          _phoneCont.text = currentUser.phone == null
              ? ''
              : PhoneUtils.toLocalDisplay(currentUser.phone!);
        });
      }
    }
    
    // THEN load local preferences (notifications, payment, image)
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _notificationsEnabled = prefs.getBool('notifications') ?? true;

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
    try {
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final userId = auth.currentUser?.id;
      
      if (userId == null) throw Exception('Not logged in');

      // Update in Supabase
      final normalizedPhone = PhoneUtils.normalizeKenyan(_phoneCont.text);

      debugPrint('💾 Saving profile to Supabase...');
      debugPrint('   Name: ${_nameController.text.trim()}');
      debugPrint('   Phone: $normalizedPhone');

      await Supabase.instance.client
          .from('users')
          .update({
            'name': _nameController.text.trim(),
            'phone': normalizedPhone,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('auth_id', userId);

      debugPrint('✅ Profile saved to Supabase successfully');

      // Save to SharedPreferences for offline access
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('name', _nameController.text.trim());
      await prefs.setString('email', _emailCont.text.trim());
      await prefs.setString('phone', normalizedPhone);
      await prefs.setBool('notifications', _notificationsEnabled);
      
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
    final formKey = GlobalKey<FormState>();
    _oldPasswordCont.clear();
    _newPasswordCont.clear();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _oldPasswordCont,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current Password'),
                validator: (v) => (v == null || v.isEmpty) ? 'Current password required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newPasswordCont,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password'),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'New password required';
                  if (v.length < 6) return 'Must be at least 6 characters';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
            ),
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              
              // In real app, call API to change password; here we simulate success
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Password changed successfully'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
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
                
                // IMPROVEMENT: Email field is read-only since email changes require re-authentication
                _buildModernTextField(
                  controller: _emailCont,
                  label: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                  readOnly: true, // ADDED: Email changes require re-authentication in Supabase
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

                // UPDATED: Addresses section - Link to dedicated screen
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.location_on, size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Delivery Addresses',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CustomerAddressManagementScreen(),
                          ),
                        ).then((_) {
                          // Reload addresses when returning
                          _loadSavedProfile();
                        });
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Manage'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                    ),
                  ],
                ),
                SizedBox(height: isLandscape ? 8 : 12),
                
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.lightGray.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_addresses.isEmpty) ...[
                        Row(
                          children: [
                            Icon(Icons.location_off, size: 24, color: AppColors.darkText.withOpacity(0.3)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No delivery addresses saved',
                                style: TextStyle(
                                  color: AppColors.darkText.withOpacity(0.6),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          children: [
                            const Icon(Icons.check_circle, size: 20, color: AppColors.success),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${_addresses.length} ${_addresses.length == 1 ? 'address' : 'addresses'} saved',
                                style: const TextStyle(
                                  color: AppColors.darkText,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_addresses.any((addr) => addr.isDefault)) ...[
                          const SizedBox(height: 8),
                          const Divider(),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.home, size: 18, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Default Address:',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      _addresses.firstWhere((addr) => addr.isDefault).label,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                
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
    bool readOnly = false, // ADDED: readOnly parameter
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
        readOnly: readOnly, // ADDED: Apply readOnly flag
        style: TextStyle(
          color: readOnly ? AppColors.darkText.withOpacity(0.6) : AppColors.darkText, // ADDED: Gray out read-only text
        ),
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
}
