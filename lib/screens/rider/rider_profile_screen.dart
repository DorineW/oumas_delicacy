import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/colors.dart';
import '../../services/auth_service.dart';
import '../../utils/phone_utils.dart';

class RiderProfileScreen extends StatefulWidget {
  const RiderProfileScreen({super.key});

  @override
  State<RiderProfileScreen> createState() => _RiderProfileScreenState();
}

class _RiderProfileScreenState extends State<RiderProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailCont = TextEditingController();
  final _phoneCont = TextEditingController();
  final _vehicleController = TextEditingController();
  final _plateController = TextEditingController();
  
  File? _profileImageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isSaving = false;
  bool _isLoading = true;
  String? _riderId;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailCont.dispose();
    _phoneCont.dispose();
    _vehicleController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final authId = auth.currentUser?.id;
      
      if (authId == null) {
        debugPrint('❌ No auth user found');
        setState(() => _isLoading = false);
        return;
      }

      debugPrint('🔄 Loading rider profile for auth_id: $authId');
      
      final supabase = Supabase.instance.client;
      
      // Get rider data from riders table
      final riderData = await supabase
          .from('riders')
          .select('id, auth_id, name, phone, vehicle')
          .eq('auth_id', authId)
          .maybeSingle();

      if (riderData == null) {
        debugPrint('❌ No rider record found for auth_id: $authId');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rider profile not found')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      debugPrint('✅ Rider data loaded: $riderData');

      // Get email from auth.users
      final authUser = supabase.auth.currentUser;
      
      setState(() {
        _riderId = riderData['id'];
        _nameController.text = riderData['name'] ?? '';
        final p = riderData['phone'] as String?;
        _phoneCont.text = p == null ? '' : PhoneUtils.toLocalDisplay(p);
        _vehicleController.text = riderData['vehicle'] ?? '';
        _emailCont.text = authUser?.email ?? '';
        _isLoading = false;
      });
      
    } catch (e) {
      debugPrint('❌ Error loading rider profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_riderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No rider profile found')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      debugPrint('🔄 Saving rider profile...');
      
      final supabase = Supabase.instance.client;
      
      // Update riders table
      final normalizedPhone = PhoneUtils.normalizeKenyan(_phoneCont.text);

      await supabase
          .from('riders')
          .update({
            'name': _nameController.text.trim(),
        'phone': normalizedPhone,
            'vehicle': _vehicleController.text.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _riderId!);

      debugPrint('✅ Rider profile updated successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: AppColors.white),
        titleTextStyle: const TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 16),
              // Modern profile image section
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
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
                    radius: 55,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: 52,
                      backgroundImage: _profileImageFile != null
                          ? FileImage(_profileImageFile!) as ImageProvider
                          : null,
                      child: _profileImageFile == null
                          ? const Icon(Icons.person, size: 48, color: AppColors.primary)
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 15,
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
              const SizedBox(height: 24),

              _buildModernTextField(
                controller: _nameController,
                label: 'Full Name',
                icon: Icons.person_outline,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name required' : null,
              ),
              const SizedBox(height: 12),
              
              _buildModernTextField(
                controller: _emailCont,
                label: 'Email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                enabled: false, // Email can't be changed
              ),
              const SizedBox(height: 12),
              
              _buildModernTextField(
                controller: _phoneCont,
                label: 'Phone Number',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              
              _buildModernTextField(
                controller: _vehicleController,
                label: 'Vehicle Type',
                icon: Icons.directions_bike,
              ),
              const SizedBox(height: 12),
              
              _buildModernTextField(
                controller: _plateController,
                label: 'Plate Number',
                icon: Icons.directions_car,
              ),
              const SizedBox(height: 24),

              // Save button
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
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool enabled = true,
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
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.primary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: enabled ? AppColors.white : Colors.grey[100],
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}
