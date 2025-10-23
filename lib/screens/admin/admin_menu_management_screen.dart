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
  static const double _defaultRating = 4.5;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _newCategoryController = TextEditingController();

  Uint8List? _selectedImageBytes;
  String? _editingImageString;
  int? _editingIndex;
  
  String? _selectedCategory;
  bool _showNewCategoryField = false;

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _newCategoryController.dispose();
    super.dispose();
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _titleController.clear();
    _priceController.clear();
    _descriptionController.clear();
    _newCategoryController.clear();
    setState(() {
      _selectedImageBytes = null;
      _editingImageString = null;
      _editingIndex = null;
      _selectedCategory = null;
      _showNewCategoryField = false;
    });
  }

  void _editItem(int index, Map<String, dynamic> item) {
    setState(() {
      _editingIndex = index;
      _titleController.text = item['title'] ?? '';
      _priceController.text = (item['price'] ?? '').toString();
      _selectedCategory = item['category'] ?? '';
      _descriptionController.text = item['description'] ?? '';
      _showNewCategoryField = false;

      _selectedImageBytes = null;
      _editingImageString = null;

      final imageValue = item['image'];
      if (imageValue != null) {
        if (imageValue is Uint8List) {
          _selectedImageBytes = imageValue;
        } else if (imageValue is String) {
          _editingImageString = imageValue;
        }
      }
    });

    _showAddEditDialog(isEditing: true);
  }

  void _showDeleteConfirmation(int index, BuildContext context) {
    final menuProvider = Provider.of<MenuProvider>(context, listen: false);
    final item = menuProvider.menuItems[index];
    final title = item['title'] ?? 'this item';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Confirm Delete'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "$title"?'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.red.withOpacity(0.8), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This item will be removed from the customer menu immediately.',
                      style: TextStyle(
                        color: Colors.red.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              menuProvider.removeMenuItem(index);
              Navigator.of(context).pop();
              _showSuccessSnackBar('"$title" deleted successfully', Colors.red);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final category = _showNewCategoryField 
          ? _newCategoryController.text.trim()
          : _selectedCategory;

      if (category == null || category.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select or enter a category'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

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
        'category': category,
        'description': _descriptionController.text.isNotEmpty
            ? _descriptionController.text.trim()
            : 'Delicious ${_titleController.text.trim()}',
      };

      final menuProvider = Provider.of<MenuProvider>(context, listen: false);
      
      if (_editingIndex != null) {
        _showUpdateConfirmation(menuProvider, newItem);
      } else {
        _showAddConfirmation(menuProvider, newItem);
      }
    }
  }

  void _showUpdateConfirmation(MenuProvider menuProvider, Map<String, dynamic> newItem) {
    final oldItem = menuProvider.menuItems[_editingIndex!];
    final hasChanges = _hasSignificantChanges(oldItem, newItem);

    if (!hasChanges) {
      _performUpdate(menuProvider, newItem);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.update, color: Colors.blue),
            SizedBox(width: 8),
            Text('Confirm Update'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Update "${_titleController.text}"?'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This change will appear in the customer menu immediately.',
                    style: TextStyle(
                      color: Colors.blue.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (oldItem['category'] != newItem['category'])
                    Text(
                      '• Category: ${oldItem['category']} → ${newItem['category']}',
                      style: TextStyle(
                        color: Colors.blue.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  if (oldItem['price'] != newItem['price'])
                    Text(
                      '• Price: Ksh ${oldItem['price']} → Ksh ${newItem['price']}',
                      style: TextStyle(
                        color: Colors.blue.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _performUpdate(menuProvider, newItem);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showAddConfirmation(MenuProvider menuProvider, Map<String, dynamic> newItem) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_circle, color: AppColors.success),
            SizedBox(width: 8),
            Text('Confirm Add Item'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add "${_titleController.text}" to menu?'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'This item will appear in the customer menu immediately.',
                style: TextStyle(
                  color: AppColors.success.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _performAdd(menuProvider, newItem);
            },
            child: const Text('Add Item'),
          ),
        ],
      ),
    );
  }

  bool _hasSignificantChanges(Map<String, dynamic> oldItem, Map<String, dynamic> newItem) {
    return oldItem['title'] != newItem['title'] ||
        oldItem['price'] != newItem['price'] ||
        oldItem['category'] != newItem['category'] ||
        oldItem['description'] != newItem['description'];
  }

  void _performUpdate(MenuProvider menuProvider, Map<String, dynamic> newItem) {
    menuProvider.updateMenuItem(_editingIndex!, newItem);
    _showSuccessSnackBar('"${_titleController.text}" updated successfully');
    _clearForm();
    if (mounted) Navigator.of(context).pop();
  }

  void _performAdd(MenuProvider menuProvider, Map<String, dynamic> newItem) {
    menuProvider.addMenuItem(newItem);
    _showSuccessSnackBar('"${_titleController.text}" added to menu');
    _clearForm();
    if (mounted) Navigator.of(context).pop();
  }

  void _showSuccessSnackBar(String message, [Color? color]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: color ?? AppColors.success),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: (color ?? AppColors.success).withOpacity(0.3)),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.red.withOpacity(0.3)),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _pickImageFromGallery() async {
    try {
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
    } catch (e) {
      _showErrorSnackBar('Failed to pick image: $e');
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
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
    } catch (e) {
      _showErrorSnackBar('Failed to capture image: $e');
    }
  }

  Widget _buildImageContent() {
    if (_selectedImageBytes != null) {
      return Image.memory(
        _selectedImageBytes!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }

    if (_editingImageString != null) {
      final image = _editingImageString!;
      if (image.startsWith('assets/')) {
        return Image.asset(
          image,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        );
      }
      return Image.network(
        image,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.lightGray.withOpacity(0.3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate,
            size: 48,
            color: AppColors.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'Add Menu Photo',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap edit button below',
            style: TextStyle(
              color: AppColors.primary.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown(MenuProvider menuProvider) {
    final categories = menuProvider.menuItems
        .map((item) => item['category'] as String?)
        .where((c) => c != null && c.trim().isNotEmpty)
        .map((c) => c!.trim())
        .toSet()
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _selectedCategory,
          isExpanded: true, // prevent right overflow in dialog
          decoration: InputDecoration(
            labelText: 'Category',
            border: const OutlineInputBorder(),
            prefixIcon: Icon(Icons.category, color: AppColors.primary),
            suffixIcon: _selectedCategory != null
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      setState(() {
                        _selectedCategory = null;
                        _showNewCategoryField = false;
                      });
                    },
                  )
                : null,
          ),
          hint: const Text('Select a category'),
          items: [
            // categories
            ...categories.map((category) {
              return DropdownMenuItem(
                value: category,
                child: Text(category, overflow: TextOverflow.ellipsis),
              );
            }),
            // add new category (short label to avoid overflow)
            const DropdownMenuItem(
              value: 'add_new',
              child: Text('Add new category...'),
            ),
          ],
          onChanged: (value) {
            setState(() {
              if (value == 'add_new') {
                _showNewCategoryField = true;
                _selectedCategory = null;
                _newCategoryController.clear();
              } else {
                _selectedCategory = value;
                _showNewCategoryField = false;
              }
            });
          },
          validator: (value) {
            if (!_showNewCategoryField && (value == null || value.isEmpty)) {
              return 'Please select a category';
            }
            return null;
          },
        ),
        if (_showNewCategoryField) ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _newCategoryController,
            decoration: InputDecoration(
              labelText: 'New Category Name',
              border: const OutlineInputBorder(),
              prefixIcon: Icon(Icons.create_new_folder, color: AppColors.primary),
            ),
            validator: (value) {
              if (_showNewCategoryField && (value == null || value.trim().isEmpty)) {
                return 'Please enter a category name';
              }
              return null;
            },
          ),
        ],
      ],
    );
  }

  Widget _buildMenuItemImage(dynamic imageValue) {
    const double size = 56.0;

    if (imageValue == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.lightGray,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Icon(Icons.image, color: Colors.grey),
        ),
      );
    }

    Widget errorWidget = Container(
      width: size,
      height: size,
      color: AppColors.lightGray,
      child: const Center(
        child: Icon(Icons.broken_image, color: Colors.grey),
      ),
    );

    if (imageValue is Uint8List) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          imageValue,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => errorWidget,
        ),
      );
    }

    if (imageValue is String) {
      if (imageValue.startsWith('assets/')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            imageValue,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => errorWidget,
          ),
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageValue,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => errorWidget,
        ),
      );
    }

    return errorWidget;
  }

  Widget _buildStatsHeader(MenuProvider menuProvider) {
    final menuItems = menuProvider.menuItems;
    final totalItems = menuItems.length;
    final categories = menuItems
        .map((item) => item['category']?.toString() ?? '')
        .where((c) => c.trim().isNotEmpty)
        .toSet()
        .length;
    final averagePrice = totalItems > 0 
        ? menuItems.fold<num>(0, (sum, item) => sum + (item['price'] ?? 0)).toDouble() / totalItems
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        border: Border(
          bottom: BorderSide(color: AppColors.primary.withOpacity(0.1)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total Items', totalItems.toString(), Icons.restaurant, AppColors.primary),
          _buildStatItem('Categories', categories.toString(), Icons.category, Colors.blue),
          _buildStatItem('Avg Price', 'Ksh ${averagePrice.toStringAsFixed(0)}', Icons.attach_money, AppColors.success),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.darkText.withOpacity(0.6),
          ),
        ),
      ],
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
              _showAddEditDialog();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatsHeader(menuProvider),
          const SizedBox(height: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0), // REDUCED: from 16
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Menu Items',
                        style: const TextStyle(
                          fontSize: 16, // REDUCED: from 18
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkText,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${menuItems.length}',
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12), // REDUCED: from 16
                  Expanded(
                    child: menuItems.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.restaurant_menu,
                                  size: 80,
                                  color: AppColors.darkText.withOpacity(0.3),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No Menu Items Yet',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.darkText.withOpacity(0.5),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap the + button to add your first item',
                                  style: TextStyle(
                                    color: AppColors.darkText.withOpacity(0.4),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: menuItems.length,
                            itemBuilder: (context, index) {
                              final item = menuItems[index];
                              final isAvailable = item['isAvailable'] ?? true;
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                color: isAvailable ? null : Colors.grey.shade200,
                                child: Padding(
                                  padding: const EdgeInsets.all(12), // REDUCED: from 16
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Image section - COMPACT
                                      Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: SizedBox(
                                              width: 70, // REDUCED: from default ListTile size
                                              height: 70,
                                              child: _buildMenuItemImage(item['image']),
                                            ),
                                          ),
                                          if (!isAvailable)
                                            Positioned.fill(
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.black54,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Center(
                                                  child: Icon(
                                                    Icons.block,
                                                    color: Colors.white,
                                                    size: 28,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(width: 12),
                                      
                                      // Content section - EXPANDED
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Title row with availability badge
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    item['title'] ?? '',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14, // REDUCED
                                                      color: isAvailable 
                                                          ? AppColors.darkText 
                                                          : Colors.grey,
                                                      decoration: isAvailable 
                                                          ? null 
                                                          : TextDecoration.lineThrough,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: isAvailable 
                                                        ? AppColors.success.withOpacity(0.1) 
                                                        : Colors.red.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(10),
                                                    border: Border.all(
                                                      color: isAvailable 
                                                          ? AppColors.success 
                                                          : Colors.red,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    isAvailable ? 'Available' : 'Out',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.bold,
                                                      color: isAvailable 
                                                          ? AppColors.success 
                                                          : Colors.red,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            
                                            // Price and category row
                                            Row(
                                              children: [
                                                Icon(Icons.sell, size: 12, color: AppColors.primary),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Ksh ${item['price']}',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Icon(Icons.category, size: 12, color: AppColors.darkText.withOpacity(0.6)),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    item['category'] ?? '',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: isAvailable
                                                          ? AppColors.darkText.withOpacity(0.7)
                                                          : Colors.grey,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            
                                            // Rating row
                                            Row(
                                              children: [
                                                const Icon(Icons.star, size: 14, color: Colors.amber),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${item['rating'] ?? _defaultRating}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: AppColors.darkText.withOpacity(0.6),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            
                                            // Action buttons row - COMPACT
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [
                                                // Availability switch
                                                Transform.scale(
                                                  scale: 0.7,
                                                  child: Switch(
                                                    value: isAvailable,
                                                    onChanged: (value) {
                                                      menuProvider.toggleAvailability(index);
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            value 
                                                                ? '"${item['title']}" is now available' 
                                                                : '"${item['title']}" marked as out of stock',
                                                          ),
                                                          backgroundColor: value ? AppColors.success : Colors.red,
                                                          behavior: SnackBarBehavior.floating,
                                                          margin: const EdgeInsets.all(16),
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                        ),
                                                      );
                                                    },
                                                    activeColor: AppColors.success,
                                                  ),
                                                ),
                                                
                                                // Edit button
                                                Container(
                                                  margin: const EdgeInsets.only(left: 4),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: IconButton(
                                                    icon: const Icon(Icons.edit, size: 16),
                                                    color: AppColors.primary,
                                                    padding: const EdgeInsets.all(6),
                                                    constraints: const BoxConstraints(
                                                      minWidth: 32,
                                                      minHeight: 32,
                                                    ),
                                                    onPressed: () => _editItem(index, item),
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                
                                                // Delete button
                                                Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.red.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: IconButton(
                                                    icon: const Icon(Icons.delete, size: 16),
                                                    color: Colors.red,
                                                    padding: const EdgeInsets.all(6),
                                                    constraints: const BoxConstraints(
                                                      minWidth: 32,
                                                      minHeight: 32,
                                                    ),
                                                    onPressed: () => _showDeleteConfirmation(index, context),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () {
          _clearForm();
          _showAddEditDialog();
        },
        tooltip: 'Add menu item',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddEditDialog({bool isEditing = false}) {
    final menuProvider = Provider.of<MenuProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'Edit Menu Item' : 'Add New Menu Item'),
              content: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // UPDATED: Modern image picker with square shape (matches edit profile)
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Background gradient (square version)
                          Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
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
                          // Image container
                          Container(
                            width: 170,
                            height: 170,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.2),
                                width: 2,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: _buildImageContent(),
                            ),
                          ),
                          // Edit button (bottom right corner) - UPDATED: matches edit profile
                          Positioned(
                            bottom: 5,
                            right: 5,
                            child: Material(
                              elevation: 4,
                              shape: const CircleBorder(),
                              child: PopupMenuButton<int>(
                                onSelected: (v) {
                                  if (v == 0) {
                                    _pickImageFromCamera();
                                    setDialogState(() {});
                                  }
                                  if (v == 1) {
                                    _pickImageFromGallery();
                                    setDialogState(() {});
                                  }
                                  if (v == 2) {
                                    setState(() {
                                      _selectedImageBytes = null;
                                      _editingImageString = null;
                                    });
                                    setDialogState(() {});
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 0,
                                    child: Row(
                                      children: [
                                        Icon(Icons.camera_alt),
                                        SizedBox(width: 8),
                                        Text('Camera'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 1,
                                    child: Row(
                                      children: [
                                        Icon(Icons.photo_library),
                                        SizedBox(width: 8),
                                        Text('Gallery'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 2,
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete),
                                        SizedBox(width: 8),
                                        Text('Remove'),
                                      ],
                                    ),
                                  ),
                                ],
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    size: 20,
                                    color: AppColors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: 'Item Name',
                          border: const OutlineInputBorder(),
                          prefixIcon: Icon(Icons.fastfood, color: AppColors.primary),
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
                        decoration: InputDecoration(
                          labelText: 'Price',
                          border: const OutlineInputBorder(),
                          prefixText: 'KSh ',
                          prefixStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
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
                      _buildCategoryDropdown(menuProvider),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: 'Description (Optional)',
                          border: const OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description, color: AppColors.primary),
                        ),
                        maxLines: 3,
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _submitForm();
                    }
                  },
                  child: Text(isEditing ? 'Update Item' : 'Add Item'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
