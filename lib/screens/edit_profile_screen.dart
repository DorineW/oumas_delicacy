import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/colors.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'Dorin N.');
  final _emailCont = TextEditingController(text: 'dorin@example.com');
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
    _loadSavedProfile();
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

  Future<void> _loadSavedProfile() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _nameController.text = prefs.getString('name') ?? _nameController.text;
      _emailCont.text = prefs.getString('email') ?? _emailCont.text;
      _phoneCont.text = prefs.getString('phone') ?? '';
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
      // Simulate API save with a short delay.
      await Future.delayed(const Duration(seconds: 1));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('name', _nameController.text.trim());
      await prefs.setString('email', _emailCont.text.trim());
      await prefs.setString('phone', _phoneCont.text.trim());
      await prefs.setBool('notifications', _notificationsEnabled);
      await prefs.setStringList('addresses', _addresses);
      if (_defaultAddressIndex != null) {
        await prefs.setInt('defaultAddressIndex', _defaultAddressIndex!);
      } else {
        await prefs.remove('defaultAddressIndex');
      }
      if (_paymentMethod != null) {
        await prefs.setString('paymentMethod', jsonEncode(_paymentMethod));
      } else {
        await prefs.remove('paymentMethod');
      }

      if (_profileImageFile != null) {
        // store path for persistence; in a real app you'd upload to a server
        await prefs.setString('profileImagePath', _profileImageFile!.path);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Edit Profile"),
        backgroundColor: AppColors.primary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: _profileImageFile != null
                          ? FileImage(_profileImageFile!) as ImageProvider
                          : const AssetImage('assets/images/profile.jpg'),
                    ),
                    PopupMenuButton<int>(
                      onSelected: (v) {
                        if (v == 0) _pickImage(ImageSource.camera);
                        if (v == 1) _pickImage(ImageSource.gallery);
                        if (v == 2) {
                          setState(() => _profileImageFile = null);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 0, child: Text('Camera')),
                        PopupMenuItem(value: 1, child: Text('Gallery')),
                        PopupMenuItem(value: 2, child: Text('Remove')),
                      ],
                      icon: const CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white70,
                        child: Icon(Icons.edit, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Name required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCont,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  validator: _validateEmail,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCont,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                  validator: _validatePhone,
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Notifications'),
                  trailing: Switch(
                    value: _notificationsEnabled,
                    onChanged: (v) => setState(() => _notificationsEnabled = v),
                    activeThumbColor: AppColors.primary,
                  ),
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Delivery Addresses', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      onPressed: _addAddressDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    )
                  ],
                ),
                ..._addresses.asMap().entries.map((e) {
                  final idx = e.key;
                  final addr = e.value;
                  final isDefault = _defaultAddressIndex == idx;
                  return Card(
                    child: ListTile(
                      title: Text(addr),
                      leading: isDefault ? const Icon(Icons.home) : null,
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
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'set_default', child: Text('Set Default')),
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'remove', child: Text('Remove')),
                        ],
                      ),
                    ),
                  );
                }),
                if (_addresses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No addresses yet. Add one for faster checkout.'),
                  ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      onPressed: _addPaymentDialog,
                      icon: const Icon(Icons.add_card),
                      label: const Text('Add'),
                    )
                  ],
                ),
                Card(
                  child: ListTile(
                    title: Text(_paymentMethod != null
                        ? '${_paymentMethod!['brand']} • ${_maskCard(_paymentMethod!['last4']!)}'
                        : 'No payment method'),
                    trailing: _paymentMethod != null
                        ? IconButton(
                            onPressed: () {
                              setState(() => _paymentMethod = null);
                            },
                            icon: const Icon(Icons.delete),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _changePasswordDialog,
                        child: const Text('Change Password'),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: _isSaving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save Changes'),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editAddressDialog(int idx) async {
    final controller = TextEditingController(text: _addresses[idx]);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Address'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Address'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              final val = controller.text.trim();
              if (val.isEmpty) return;
              setState(() => _addresses[idx] = val);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
