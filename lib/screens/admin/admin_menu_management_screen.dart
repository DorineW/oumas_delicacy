// screens/admin/admin_menu_management_screen.dart
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../constants/colors.dart';
// Assuming these files exist with the necessary classes/enums
import '../../models/menu_item.dart'; // Must contain MenuItem class and MealWeight enum
import '../../providers/menu_provider.dart';

// --- Placeholder/Assumed Classes for Compilation (You must have these in your project) ---
// MealWeight enum is now imported from menu_item.dart

// Minimal placeholder for MenuItem (adjust based on your actual model)
// class MenuItem {
//   final String title;
//   final int price;
//   final double rating;
//   final String category;
//   final MealWeight mealWeight;
//   final String? description;
//   final String? imageUrl;
//   final bool isAvailable;
//   MenuItem({
//     required this.title,
//     required this.price,
//     required this.rating,
//     required this.category,
//     required this.mealWeight,
//     this.description,
//     this.imageUrl,
//     required this.isAvailable,
//   });
// }

// Minimal placeholder for MenuProvider (adjust based on your actual provider)
// class MenuProvider with ChangeNotifier {
//   final List<MenuItem> _menuItems = [
//     MenuItem(title: 'Burger', price: 500, rating: 4.5, category: 'Main', mealWeight: MealWeight.Heavy, imageUrl: 'https://placehold.co/60x60/0000FF/FFFFFF.png?text=B', isAvailable: true),
//     MenuItem(title: 'Salad', price: 300, rating: 4.2, category: 'Salads', mealWeight: MealWeight.Light, imageUrl: 'https://placehold.co/60x60/00FF00/000000.png?text=S', isAvailable: true),
//   ];

//   List<MenuItem> get menuItems => [..._menuItems];
//   bool isItemAvailable(String title) => _menuItems.firstWhere((item) => item.title == title).isAvailable;

//   Future<void> deleteMenuItem(String title) async {
//     // Impl detail for deletion
//     _menuItems.removeWhere((item) => item.title == title);
//     notifyListeners();
//   }

//   Future<void> updateMenuItem(String oldTitle, MenuItem newItem) async {
//     // Impl detail for update
//     final index = _menuItems.indexWhere((item) => item.title == oldTitle);
//     if (index != -1) {
//       _menuItems[index] = newItem;
//       notifyListeners();
//     }
//   }

//   Future<void> addMenuItem(MenuItem newItem) async {
//     // Impl detail for addition
//     _menuItems.add(newItem);
//     notifyListeners();
//   }
// }

// --- End of Placeholder/Assumed Classes ---

class AdminMenuManagementScreen extends StatefulWidget {
  const AdminMenuManagementScreen({super.key});

  @override
  State<AdminMenuManagementScreen> createState() =>
      _AdminMenuManagementScreenState();
}

class _AdminMenuManagementScreenState extends State<AdminMenuManagementScreen> {
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
  MealWeight? _selectedMealWeight;
  bool _showNewCategoryField = false;
  bool _showCategoryManagement = false;
  bool _isAvailable = true;

  final Set<String> _customCategories = {};

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _newCategoryController.dispose();
    _categoryNameController.dispose();
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
      _selectedMealWeight = null;
      _showNewCategoryField = false;
      _showCategoryManagement = false;
      _isAvailable = true;
    });
  }

  void _editItem(int index, MenuItem item) {
    setState(() {
      _editingIndex = index;
      _titleController.text = item.title;
      _priceController.text = item.price.toString();
      _selectedCategory = item.category;
      _selectedMealWeight = item.mealWeight as MealWeight?;
      _descriptionController.text = item.description ?? '';
      _showNewCategoryField = false;
      _isAvailable = item.isAvailable; // FIXED: Load existing availability status

      _selectedImageBytes = null;
      _editingImageString = item.imageUrl;
    });

    _showAddEditDialog(isEditing: true);
  }

  void _showDeleteConfirmation(int index, BuildContext context) {
    final menuProvider = Provider.of<MenuProvider>(context, listen: false);
    final item = menuProvider.menuItems[index];
    final title = item.title;

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
            onPressed: () async {
              try {
                await menuProvider.deleteMenuItem(item); // Pass the full item object
                if (!mounted) return;
                Navigator.of(context).pop();
                _showSuccessSnackBar('"$title" deleted successfully', Colors.red);
              } catch (e) {
                if (!mounted) return;
                Navigator.of(context).pop();
                _showErrorSnackBar('Failed to delete: $e');
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitForm() async {
    // FIXED: Ensure meal weight check is outside the form validation to allow custom UI
    // The TextFormField validation for category is still needed.
    if (_formKey.currentState!.validate()) {
      final category = _showNewCategoryField
          ? _newCategoryController.text.trim()
          : _selectedCategory;

      if (category == null || category.isEmpty) {
        // FIXED: Show snackbar if category is missing/empty
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select or enter a category'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_selectedMealWeight == null) {
        // FIXED: Show snackbar if meal weight is missing
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select meal weight'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Building the new MenuItem
      final menuProvider = Provider.of<MenuProvider>(context, listen: false);
      final String? existingId = _editingIndex != null 
          ? menuProvider.menuItems[_editingIndex!].id 
          : null;

      final newItem = MenuItem(
        id: existingId, // Preserve ID when editing
        title: _titleController.text.trim(),
        // FIXED: Price must be an integer (as per the model definition)
        price: int.parse(_priceController.text.trim()),
        // NOTE: The logic for rating calculation here seems non-standard but is kept.
        rating: _editingIndex != null
            ? menuProvider.menuItems[_editingIndex!].rating
            : 4.5,
        category: category,
        mealWeight: _selectedMealWeight!,
        description: _descriptionController.text.isNotEmpty
            ? _descriptionController.text.trim()
            : 'Delicious ${_titleController.text.trim()}',
        // CRITICAL FIX: Only include imageUrl if NO new image bytes exist
        // If imageBytes exist, provider will upload and set the URL
        // If no imageBytes, preserve existing URL (or null for new items)
        imageUrl: _selectedImageBytes == null ? _editingImageString : null,
        isAvailable: _isAvailable,
      );
      
      if (_editingIndex != null) {
        // Only show update confirmation if meaningful changes were made
        final oldItem = menuProvider.menuItems[_editingIndex!];
        final hasChanges = _hasSignificantChanges(oldItem, newItem) || oldItem.isAvailable != newItem.isAvailable;
        if (!hasChanges && _selectedImageBytes == null) {
          Navigator.of(context).pop();
          _showErrorSnackBar('No changes detected for update.');
          return;
        }
        _showUpdateConfirmation(menuProvider, newItem);
      } else {
        _showAddConfirmation(menuProvider, newItem);
      }
    }
  }

  void _showUpdateConfirmation(MenuProvider menuProvider, MenuItem newItem) {
    final oldItem = menuProvider.menuItems[_editingIndex!];

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
            Text('Update "${newItem.title}"?'),
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
                  if (oldItem.category != newItem.category)
                    Text(
                      '• Category: ${oldItem.category} → ${newItem.category}',
                      style: TextStyle(
                        color: Colors.blue.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  if (oldItem.price != newItem.price)
                    Text(
                      '• Price: Ksh ${oldItem.price} → Ksh ${newItem.price}',
                      style: TextStyle(
                        color: Colors.blue.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                   if (oldItem.mealWeight != newItem.mealWeight)
                    Text(
                      '• Weight: ${oldItem.mealWeight.displayName} → ${newItem.mealWeight.displayName}',
                      style: TextStyle(
                        color: Colors.blue.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  if (oldItem.isAvailable != newItem.isAvailable)
                    Text(
                      '• Available: ${oldItem.isAvailable ? 'Yes' : 'No'} → ${newItem.isAvailable ? 'Yes' : 'No'}',
                      style: TextStyle(
                        color: Colors.blue.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                   if (_selectedImageBytes != null)
                    Text(
                      '• Image: Will be updated with new selection',
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

  void _showAddConfirmation(MenuProvider menuProvider, MenuItem newItem) {
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

  bool _hasSignificantChanges(MenuItem oldItem, MenuItem newItem) {
    return oldItem.title != newItem.title ||
        oldItem.price != newItem.price ||
        oldItem.category != newItem.category ||
        oldItem.description != newItem.description ||
        oldItem.mealWeight != newItem.mealWeight; // FIXED: Include mealWeight check
  }

  void _performUpdate(MenuProvider menuProvider, MenuItem newItem) async {
    try {
      // Pass the selected image bytes to upload to storage
      await menuProvider.updateMenuItem(newItem, _selectedImageBytes);
      if (!mounted) return;
      _showSuccessSnackBar('"${newItem.title}" updated successfully');
      _clearForm();
      // NOTE: Navigator.of(context).pop() is not needed here as the dialog was closed in _showUpdateConfirmation
      // If you want to close the main screen after this, you'd navigate back.
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Failed to update: $e');
    }
  }

  void _performAdd(MenuProvider menuProvider, MenuItem newItem) async {
    try {
      // Pass the selected image bytes to upload to storage
      await menuProvider.addMenuItem(newItem, _selectedImageBytes);
      if (!mounted) return;
      _showSuccessSnackBar('"${newItem.title}" added to menu');
      _clearForm();
      // NOTE: Navigator.of(context).pop() is not needed here as the dialog was closed in _showAddConfirmation
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Failed to add: $e');
    }
  }

  Widget _buildMenuItemImage(MenuItem item) {
    const double size = 70.0;

    if (item.imageUrl == null) {
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

    return Image.network(
      item.imageUrl!,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        width: size,
        height: size,
        color: AppColors.lightGray,
        child: const Center(
          child: Icon(Icons.broken_image, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildCategoryManagement(MenuProvider menuProvider) {
    if (!_showCategoryManagement) return const SizedBox.shrink();

    final allCategories = {
      ...menuProvider.menuItems.map((item) => item.category),
      ..._customCategories,
    }.toList()..sort();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5, // Flexible max height
        ),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  setState(() {
                    _showCategoryManagement = false;
                  });
                },
                icon: const Icon(Icons.close, color: Colors.blue),
                tooltip: 'Close',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 48),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _categoryNameController,
                    decoration: InputDecoration(
                      hintText: 'Enter new category name...',
                      hintStyle: TextStyle(fontSize: 14, color: AppColors.darkText.withOpacity(0.4)),
                      prefixIcon: const Icon(Icons.add_circle_outline, size: 20, color: Colors.blue),
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
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
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
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: allCategories.map((category) {
                    final itemCount = menuProvider.menuItems
                        .where((item) => item.category == category)
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
                          const Icon(Icons.folder, size: 16, color: Colors.blue),
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
                              style: const TextStyle(
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
              ),
            ),
            ],
          ),
        ),
      ),
    );
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
          const Text(
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

  Widget _buildStatsHeader(MenuProvider menuProvider) {
    final menuItems = menuProvider.menuItems;
    final totalItems = menuItems.length;
    
    final categories = {
      ...menuItems.map((item) => item.category),
      ..._customCategories,
    }.length;
    
    final averagePrice = totalItems > 0 
        ? menuItems.fold<num>(0, (sum, item) => sum + item.price).toDouble() / totalItems
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
                  _showCategoryManagement ? Icons.expand_less : Icons.expand_more,
                  size: 16,
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

  void _addCategory(MenuProvider menuProvider) {
    final newCategory = _categoryNameController.text.trim();
    if (newCategory.isEmpty) {
      _showErrorSnackBar('Please enter a category name');
      return;
    }

    // Check if category already exists
    final allCategories = {
      ...menuProvider.menuItems.map((item) => item.category),
      ..._customCategories,
    };

    if (allCategories.contains(newCategory)) {
      _showErrorSnackBar('Category "$newCategory" already exists');
      return;
    }

    setState(() {
      _customCategories.add(newCategory);
      _categoryNameController.clear();
    });
    
    _showSuccessSnackBar('Category "$newCategory" added successfully');
  }

  void _deleteCategory(MenuProvider menuProvider, String category) {
    final itemsInCategory = menuProvider.menuItems
        .where((item) => item.category == category)
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

  @override
  Widget build(BuildContext context) {
    return Consumer<MenuProvider>(
      builder: (context, menuProvider, child) {
        final menuItems = menuProvider.menuItems;
        
        return Scaffold(
          resizeToAvoidBottomInset: true,
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
              // Make category panel flexible so it can shrink when keyboard shows
              Flexible(
                fit: FlexFit.loose,
                child: _buildCategoryManagement(menuProvider),
              ),
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
                                  child: _buildMenuItemImage(item),
                                ),
                              ),
                              title: Text(
                                item.title,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text('Ksh ${item.price}'),
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
                                            item.category,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
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
                                                _getMealWeightIcon(item.mealWeight.name),
                                                size: 10,
                                                color: Colors.orange,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                item.mealWeight.displayName,
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
                                            color: menuProvider.isItemAvailable(item.title)
                                                ? Colors.green.withOpacity(0.1)
                                                : Colors.red.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                menuProvider.isItemAvailable(item.title)
                                                    ? Icons.check_circle
                                                    : Icons.block,
                                                size: 10,
                                                color: menuProvider.isItemAvailable(item.title)
                                                    ? Colors.green
                                                    : Colors.red,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                menuProvider.isItemAvailable(item.title) ? 'Available' : 'Out of Stock',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: menuProvider.isItemAvailable(item.title)
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

  // FIXED & ADDED: The missing _showAddEditDialog function
  void _showAddEditDialog({bool isEditing = false}) {
    final menuProvider = Provider.of<MenuProvider>(context, listen: false);

    if (!isEditing) {
      _clearForm();
      _isAvailable = true; 
    } else {
      final editedItem = menuProvider.menuItems[_editingIndex!];
      _isAvailable = editedItem.isAvailable;
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                  maxWidth: 500,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              isEditing ? 'Edit Menu Item' : 'Add New Menu Item',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              Navigator.of(context).pop();
                              _clearForm();
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
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
                                  onSelected: (v) async {
                                    if (v == 0) {
                                      await _pickImageFromCamera();
                                      setDialogState(() {});
                                    }
                                    if (v == 1) {
                                      await _pickImageFromGallery();
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
                                    PopupMenuItem(value: 0, child: Row(children: [Icon(Icons.camera_alt), SizedBox(width: 8), Text('Camera')])),
                                    PopupMenuItem(value: 1, child: Row(children: [Icon(Icons.photo_library), SizedBox(width: 8), Text('Gallery')])),
                                    PopupMenuItem(value: 2, child: Row(children: [Icon(Icons.delete), SizedBox(width: 8), Text('Remove')])),
                                  ],
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.edit, size: 20, color: AppColors.white),
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
                          decoration: const InputDecoration(
                            labelText: 'Item Name',
                            border: OutlineInputBorder(),
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
                          decoration: const InputDecoration(
                            labelText: 'Price',
                            border: OutlineInputBorder(),
                            prefixText: 'KSh ',
                            prefixStyle: TextStyle(
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<String>(
                              value: _selectedCategory,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Category',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.category, color: AppColors.primary),
                                suffixIcon: _selectedCategory != null
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          setDialogState(() {
                                            _selectedCategory = null;
                                            _showNewCategoryField = false;
                                          });
                                        },
                                      )
                                    : null,
                              ),
                              hint: const Text('Select a category'),
                              items: [
                                ...({
                                  ...menuProvider.menuItems.map((item) => item.category),
                                  ..._customCategories,
                                }.toList()..sort()).map((category) {
                                  return DropdownMenuItem(
                                    value: category,
                                    child: Text(category, overflow: TextOverflow.ellipsis),
                                  );
                                }),
                                const DropdownMenuItem(
                                  value: 'add_new',
                                  child: Text('+ Add new category...'),
                                ),
                              ],
                              onChanged: (value) {
                                setDialogState(() {
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
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _newCategoryController,
                                decoration: const InputDecoration(
                                  labelText: 'New Category Name',
                                  border: OutlineInputBorder(),
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
                        ),
                        const SizedBox(height: 16),
                        
                        // Meal weight selector
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.fitness_center, size: 16, color: AppColors.primary),
                                SizedBox(width: 8),
                                Text(
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
                              children: MealWeight.values.map<Widget>((weight) {
                                final isSelected = _selectedMealWeight == weight;
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: InkWell(
                                      onTap: () {
                                        setDialogState(() {
                                          _selectedMealWeight = weight;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
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
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _getMealWeightIcon(weight.name),
                                              size: 18,
                                              color: isSelected ? Colors.white : AppColors.primary,
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              weight.displayName,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: isSelected ? Colors.white : AppColors.primary,
                                              ),
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
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
                        ),
                        const SizedBox(height: 12),
                        
                        // Availability toggle
                        Container(
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
                                    const Text(
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
                                          ? 'Available for customers'
                                          : 'Out of stock',
                                      style: TextStyle(
                                        fontSize: 11,
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
                                  setDialogState(() {
                                    _isAvailable = value;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Description field
                        TextFormField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Description (Optional)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.description, color: AppColors.primary),
                          ),
                          maxLines: 3,
                          minLines: 2,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
              // Actions
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _clearForm();
                      },
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
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
                ),
              ),
            ],
          ),
        ),
      );
          },
        );
      },
    );
  }
}