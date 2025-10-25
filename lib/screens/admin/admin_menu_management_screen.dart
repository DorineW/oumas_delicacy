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
  final TextEditingController _categoryNameController = TextEditingController();

  Uint8List? _selectedImageBytes;
  String? _editingImageString;
  int? _editingIndex;
  
  String? _selectedCategory;
  String? _selectedMealWeight; // ADDED: Meal weight selection
  bool _showNewCategoryField = false;
  bool _showCategoryManagement = false;
  bool _isAvailable = true; // ADDED: Availability toggle

  final Set<String> _customCategories = {};
  
  // ADDED: Meal weight options
  final List<String> _mealWeights = ['Light', 'Medium', 'Heavy'];

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _newCategoryController.dispose();
    _categoryNameController.dispose(); // ADDED: Dispose category controller
    super.dispose();
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _titleController.clear();
    _priceController.clear();
    _descriptionController.clear();
    _newCategoryController.clear();
    _categoryNameController.clear();
    setState(() {
      _selectedImageBytes = null;
      _editingImageString = null;
      _editingIndex = null;
      _selectedCategory = null;
      _selectedMealWeight = null; // ADDED: Reset meal weight
      _showNewCategoryField = false;
      _showCategoryManagement = false;
      _isAvailable = true; // ADDED: Reset availability
    });
  }

  void _editItem(int index, Map<String, dynamic> item) {
    setState(() {
      _editingIndex = index;
      _titleController.text = item['title'] ?? '';
      _priceController.text = (item['price'] ?? '').toString();
      _selectedCategory = item['category'] ?? '';
      _selectedMealWeight = item['mealWeight'] ?? 'Medium'; // ADDED: Load meal weight
      _descriptionController.text = item['description'] ?? '';
      _showNewCategoryField = false;
      _isAvailable = item['isAvailable'] ?? true; // ADDED: Load availability

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

      // ADDED: Validate meal weight
      if (_selectedMealWeight == null || _selectedMealWeight!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select meal weight'),
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
        'mealWeight': _selectedMealWeight, // ADDED: Save meal weight
        'isAvailable': _isAvailable, // ADDED: Save availability
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

  // ADDED: Build menu item image helper
  Widget _buildMenuItemImage(dynamic imageValue) {
    const double size = 70.0;

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
      return Image.memory(
        imageValue,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => errorWidget,
      );
    }

    if (imageValue is String) {
      if (imageValue.startsWith('assets/')) {
        return Image.asset(
          imageValue,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => errorWidget,
        );
      }
      return Image.network(
        imageValue,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => errorWidget,
      );
    }

    return errorWidget;
  }

  // ADDED: Build stats header
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
    final isCategories = label == 'Categories';
    
    return GestureDetector(
      onTap: isCategories ? () {
        setState(() {
          _showCategoryManagement = !_showCategoryManagement;
        });
      } : null,
      child: Column(
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (isCategories) ...[
                const SizedBox(width: 4),
                Icon(
                  _showCategoryManagement ? Icons.visibility_off : Icons.visibility,
                  size: 14,
                  color: color,
                ),
              ],
            ],
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.darkText.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  // UPDATED: Build category management section - matches inventory low stock styling
  Widget _buildCategoryManagement(MenuProvider menuProvider) {
    // FIXED: Only show when toggle is active
    if (!_showCategoryManagement) {
      return const SizedBox.shrink();
    }

    final allCategories = {
      ...menuProvider.menuItems
          .map((item) => item['category'] as String?)
          .where((c) => c != null && c.trim().isNotEmpty)
          .map((c) => c!.trim()),
      ..._customCategories,
    }.toList()
      ..sort();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.category, color: Colors.blue, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Manage Categories',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${allCategories.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Add new category
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _categoryNameController,
                  decoration: InputDecoration(
                    hintText: 'Enter new category name...',
                    hintStyle: TextStyle(fontSize: 14, color: AppColors.darkText.withOpacity(0.4)),
                    prefixIcon: Icon(Icons.add_circle_outline, size: 20, color: Colors.blue),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.lightGray.withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.lightGray.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.blue, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _addCategory(menuProvider),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _addCategory(menuProvider),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Existing categories list
          if (allCategories.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No categories yet. Add a category above.',
                  style: TextStyle(
                    color: AppColors.darkText.withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: allCategories.map((category) {
                final itemCount = menuProvider.menuItems
                    .where((item) => item['category'] == category)
                    .length;
                
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder, size: 16, color: Colors.blue),
                      const SizedBox(width: 6),
                      Text(
                        category,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$itemCount',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => _deleteCategory(menuProvider, category),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.red.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // UPDATED: Method to add new category
  void _addCategory(MenuProvider menuProvider) {
    final newCategory = _categoryNameController.text.trim();
    if (newCategory.isEmpty) {
      _showErrorSnackBar('Please enter a category name');
      return;
    }

    // Check if category already exists
    final allCategories = {
      ...menuProvider.menuItems
          .map((item) => item['category'] as String?)
          .where((c) => c != null && c.trim().isNotEmpty)
          .map((c) => c!.trim()),
      ..._customCategories,
    };

    if (allCategories.contains(newCategory)) {
      _showErrorSnackBar('Category "$newCategory" already exists');
      return;
    }

    // FIXED: Add to custom categories set
    setState(() {
      _customCategories.add(newCategory);
      _categoryNameController.clear();
    });
    
    _showSuccessSnackBar('Category "$newCategory" added successfully');
  }

  // UPDATED: Method to delete category
  void _deleteCategory(MenuProvider menuProvider, String category) {
    final itemsInCategory = menuProvider.menuItems
        .where((item) => item['category'] == category)
        .length;

    if (itemsInCategory > 0) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('Cannot Delete Category'),
            ],
          ),
          content: Text('Category "$category" has $itemsInCategory item(s). Please reassign or delete those items first.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Category'),
          ],
        ),
        content: Text('Delete category "$category"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              // FIXED: Remove from custom categories
              setState(() {
                _customCategories.remove(category);
              });
              _showSuccessSnackBar('Category "$category" deleted', Colors.red);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // UPDATED: Build category dropdown to include custom categories
  Widget _buildCategoryDropdown(MenuProvider menuProvider) {
    // FIXED: Combine menu categories with custom categories
    final allCategories = {
      ...menuProvider.menuItems
          .map((item) => item['category'] as String?)
          .where((c) => c != null && c.trim().isNotEmpty)
          .map((c) => c!.trim()),
      ..._customCategories,
    }.toList()
      ..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _selectedCategory,
          isExpanded: true,
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
            // FIXED: Show all available categories
            ...allCategories.map((category) {
              return DropdownMenuItem(
                value: category,
                child: Text(category, overflow: TextOverflow.ellipsis),
              );
            }),
            // add new category option
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

  // ADDED: Get icon for meal weight
  IconData _getMealWeightIcon(String weight) {
    switch (weight) {
      case 'Light':
        return Icons.light_mode;
      case 'Medium':
        return Icons.restaurant;
      case 'Heavy':
        return Icons.fitness_center;
      default:
        return Icons.restaurant;
    }
  }

  // FIXED: Complete build method
  @override
  Widget build(BuildContext context) {
    return Consumer<MenuProvider>(
      builder: (context, menuProvider, child) {
        final menuItems = menuProvider.menuItems;
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('Menu Management'),
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.add_circle),
                tooltip: 'Add Item',
                onPressed: () => _showAddEditDialog(),
              ),
            ],
          ),
          body: Column(
            children: [
              _buildStatsHeader(menuProvider),
              _buildCategoryManagement(menuProvider),
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
                              'No Menu Items',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkText.withOpacity(0.5),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add items to get started',
                              style: TextStyle(
                                color: AppColors.darkText.withOpacity(0.4),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: menuItems.length,
                        itemBuilder: (context, index) {
                          final item = menuItems[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 60,
                                  height: 60,
                                  child: _buildMenuItemImage(item['image']),
                                ),
                              ),
                              title: Text(
                                item['title'] ?? 'Untitled',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text('Ksh ${item['price']}'),
                                  const SizedBox(height: 2),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            item['category'] ?? 'Uncategorized',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (item['mealWeight'] != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  _getMealWeightIcon(item['mealWeight']),
                                                  size: 10,
                                                  color: Colors.orange,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  item['mealWeight'],
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.orange,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: (item['isAvailable'] ?? true)
                                                ? Colors.green.withOpacity(0.1)
                                                : Colors.red.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                (item['isAvailable'] ?? true)
                                                    ? Icons.check_circle
                                                    : Icons.block,
                                                size: 10,
                                                color: (item['isAvailable'] ?? true)
                                                    ? Colors.green
                                                    : Colors.red,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                (item['isAvailable'] ?? true) ? 'Available' : 'Out of Stock',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: (item['isAvailable'] ?? true)
                                                      ? Colors.green
                                                      : Colors.red,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _editItem(index, item),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _showDeleteConfirmation(index, context),
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
        );
      },
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
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.65, // REDUCED: from 0.7 to 0.65
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Image picker section
                        Stack(
                          alignment: Alignment.center,
                          children: [
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
                        
                        // Title field
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
                        
                        // Price field
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
                        
                        // Category dropdown
                        _buildCategoryDropdown(menuProvider),
                        const SizedBox(height: 16),
                        
                        // FIXED: Meal weight selector that updates on tap
                        StatefulBuilder(
                          builder: (context, setWeightState) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.fitness_center, size: 16, color: AppColors.primary),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Meal Weight',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: _mealWeights.map<Widget>((weight) {
                                    final isSelected = _selectedMealWeight == weight;
                                    return Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        child: InkWell(
                                          onTap: () {
                                            setState(() {
                                              _selectedMealWeight = weight;
                                            });
                                            setWeightState(() {
                                              _selectedMealWeight = weight;
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? AppColors.primary
                                                  : AppColors.primary.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: AppColors.primary,
                                                width: isSelected ? 2 : 1,
                                              ),
                                            ),
                                            child: Column(
                                              children: [
                                                Icon(
                                                  _getMealWeightIcon(weight),
                                                  size: 20,
                                                  color: isSelected ? Colors.white : AppColors.primary,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  weight,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: isSelected ? Colors.white : AppColors.primary,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // ADDED: Availability toggle
                        StatefulBuilder(
                          builder: (context, setAvailabilityState) {
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _isAvailable
                                    ? Colors.green.withOpacity(0.05)
                                    : Colors.red.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _isAvailable
                                      ? Colors.green.withOpacity(0.3)
                                      : Colors.red.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _isAvailable ? Icons.check_circle : Icons.block,
                                    color: _isAvailable ? Colors.green : Colors.red,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Availability',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.darkText,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _isAvailable
                                              ? 'Item is available for customers'
                                              : 'Item is out of stock',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.darkText.withOpacity(0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: _isAvailable,
                                    activeColor: Colors.green,
                                    onChanged: (value) {
                                      setState(() {
                                        _isAvailable = value;
                                      });
                                      setAvailabilityState(() {
                                        _isAvailable = value;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Description field
                        TextFormField(
                          controller: _descriptionController,
                          decoration: InputDecoration(
                            labelText: 'Description (Optional)',
                            border: const OutlineInputBorder(),
                            prefixIcon: Icon(Icons.description, color: AppColors.primary),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
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
