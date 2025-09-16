// screens/admin/admin_menu_management_screen.dart
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../constants/colors.dart';
import '../../providers/menu_provider.dart';

class AdminMenuManagementScreen extends StatefulWidget {
  const AdminMenuManagementScreen({super.key});

  @override
  State<AdminMenuManagementScreen> createState() =>
      _AdminMenuManagementScreenState();
}

class _AdminMenuManagementScreenState extends State<AdminMenuManagementScreen> {
  static const double _defaultRating = 4.5; // default rating for new items

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();

  /// We store selected image as bytes so it works on Web and Mobile.
  Uint8List? _selectedImageBytes;

  /// If editing an existing item and its image is a String (asset or URL),
  /// we keep the string here for preview (don't convert it to bytes).
  String? _editingImageString;

  int? _editingIndex; // Track which item is being edited

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _titleController.clear();
    _priceController.clear();
    _descriptionController.clear();
    _categoryController.clear();
    setState(() {
      _selectedImageBytes = null;
      _editingImageString = null;
      _editingIndex = null;
    });
  }

  void _editItem(int index, Map<String, dynamic> item) {
    setState(() {
      _editingIndex = index;
      _titleController.text = item['title'] ?? '';
      _priceController.text = (item['price'] ?? '').toString();
      _categoryController.text = item['category'] ?? '';
      _descriptionController.text = item['description'] ?? '';

      _selectedImageBytes = null;
      _editingImageString = null;

      final imageValue = item['image'];
      if (imageValue != null) {
        if (imageValue is Uint8List) {
          _selectedImageBytes = imageValue;
        } else if (imageValue is String) {
          // Could be 'assets/...' or an http(s) URL or a path string.
          // We'll keep the string for preview. On web, paths that are local won't work;
          // preferrable approach is to use bytes/URLs.
          _editingImageString = imageValue;
        }
      }
    });

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _buildAddItemDialog(isEditing: true);
      },
    );
  }

  void _deleteItem(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final title = Provider.of<MenuProvider>(context, listen: false)
                .menuItems[index]['title'] ??
            '';
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: Text('Are you sure you want to delete "$title"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Provider.of<MenuProvider>(context, listen: false)
                    .removeMenuItem(index);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Item deleted'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      // default image asset if none chosen
      dynamic imageValue = 'assets/images/default.jpg';
      if (_selectedImageBytes != null) {
        imageValue = _selectedImageBytes!;
      } else if (_editingImageString != null) {
        imageValue = _editingImageString!;
      }

      final newItem = {
        'title': _titleController.text.trim(),
        'price': int.parse(_priceController.text.trim()),
        'rating': _editingIndex != null
            ? Provider.of<MenuProvider>(context, listen: false)
                    .menuItems[_editingIndex!]['rating'] ??
                _defaultRating
            : _defaultRating,
        'image': imageValue,
        'category': _categoryController.text.trim(),
        'description': _descriptionController.text.isNotEmpty
            ? _descriptionController.text.trim()
            : 'Delicious ${_titleController.text.trim()}',
      };

      if (_editingIndex != null) {
        Provider.of<MenuProvider>(context, listen: false)
            .updateMenuItem(_editingIndex!, newItem);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_titleController.text} updated'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        Provider.of<MenuProvider>(context, listen: false).addMenuItem(newItem);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_titleController.text} added to menu'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      _clearForm();
    }
  }

  Future<void> _pickImageFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );

    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _selectedImageBytes = bytes;
        _editingImageString = null;
      });
    }
  }

  Future<void> _pickImageFromCamera() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1200,
    );

    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _selectedImageBytes = bytes;
        _editingImageString = null;
      });
    }
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImageFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImageFromCamera();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Builds a small 50x50 preview for list tiles.
  Widget _buildImage(dynamic imageValue, {double width = 50, double height = 50}) {
    if (imageValue == null) {
      return _placeholderBox(width, height);
    }

    if (imageValue is Uint8List) {
      return Image.memory(
        imageValue,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholderBox(width, height),
      );
    }

    if (imageValue is String) {
      if (imageValue.startsWith('assets/')) {
        return Image.asset(
          imageValue,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholderBox(width, height),
        );
      }
      if (imageValue.startsWith('http')) {
        return Image.network(
          imageValue,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholderBox(width, height),
        );
      }
      // Fallback: try network (may fail if it's a local path, but avoids dart:io import)
      return Image.network(
        imageValue,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholderBox(width, height),
      );
    }

    return _placeholderBox(width, height);
  }

  Widget _placeholderBox(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: AppColors.lightGray,
      child: const Icon(Icons.fastfood),
    );
  }

  @override
  Widget build(BuildContext context) {
    final menuProvider = Provider.of<MenuProvider>(context);
    final menuItems = menuProvider.menuItems;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Menu Management'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add menu item',
            onPressed: () {
              _clearForm();
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return _buildAddItemDialog();
                },
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () {
          _clearForm();
          showDialog(context: context, builder: (_) => _buildAddItemDialog());
        },
        child: const Icon(Icons.add),
        tooltip: 'Add menu item',
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Menu Items (${menuItems.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: menuItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.restaurant_menu,
                            size: 64,
                            color: AppColors.lightGray,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No menu items yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: AppColors.darkText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap the + button to add your first item',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.darkText.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: menuItems.length,
                      itemBuilder: (context, index) {
                        final item = menuItems[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: _buildImage(item['image'] ?? 'assets/images/default.jpg'),
                            ),
                            title: Text(
                              item['title'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              'Ksh ${item['price']} • ${item['category'] ?? ''} • ⭐${item['rating'] ?? _defaultRating}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: AppColors.primary),
                                  onPressed: () => _editItem(index, item),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteItem(index),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddItemDialog({bool isEditing = false}) {
    // For preview inside dialog prefer selected bytes first, then editing string, then default.
    Widget _dialogImagePreview() {
      if (_selectedImageBytes != null) {
        return Image.memory(_selectedImageBytes!, fit: BoxFit.cover);
      }
      if (_editingImageString != null) {
        final v = _editingImageString!;
        if (v.startsWith('assets/')) {
          return Image.asset(v, fit: BoxFit.cover);
        }
        if (v.startsWith('http')) {
          return Image.network(v, fit: BoxFit.cover);
        }
        // fallback to network attempt
        return Image.network(v, fit: BoxFit.cover);
      }
      // default placeholder
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.camera_alt, size: 40, color: AppColors.primary),
          const SizedBox(height: 8),
          Text('Tap to ${isEditing ? 'change' : 'add'} image',
              style: TextStyle(color: AppColors.primary)),
        ],
      );
    }

    return AlertDialog(
      title: Text(isEditing ? 'Edit Menu Item' : 'Add New Menu Item'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image preview and picker
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.lightGray,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _dialogImagePreview(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an item name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Price (Ksh)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a price';
                  }
                  if (int.tryParse(value.trim()) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Category input
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a category';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            _clearForm();
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              _submitForm();
              Navigator.of(context).pop();
            }
          },
          child: Text(isEditing ? 'Update Item' : 'Add Item'),
        ),
      ],
    );
  }
}
