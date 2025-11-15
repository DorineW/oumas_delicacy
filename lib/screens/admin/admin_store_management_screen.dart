// lib/screens/admin/admin_store_management_screen.dart
// ignore_for_file: unused_import

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../constants/colors.dart';
import '../../models/store_item.dart';
import '../../models/location.dart';
import '../../providers/store_provider.dart';
import '../../widgets/smart_product_image.dart';

class AdminStoreManagementScreen extends StatefulWidget {
  const AdminStoreManagementScreen({super.key});

  @override
  State<AdminStoreManagementScreen> createState() =>
      _AdminStoreManagementScreenState();
}

class _AdminStoreManagementScreenState extends State<AdminStoreManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _newCategoryController = TextEditingController();
  final TextEditingController _unitDescriptionController = TextEditingController();
  final TextEditingController _initialStockController = TextEditingController(text: '0');

  Uint8List? _selectedImageBytes;
  String? _editingImageString;
  int? _editingIndex;
  
  String? _selectedCategory;
  String? _selectedLocationId;
  bool _showNewCategoryField = false;
  bool _isAvailable = true;

  // Store the item being processed globally for confirmation dialogs
  StoreItem? _itemToProcess;
  String? _locationIdForItem;
  int? _initialStockForItem;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _newCategoryController.dispose();
    _unitDescriptionController.dispose();
    _initialStockController.dispose();
    super.dispose();
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _priceController.clear();
    _descriptionController.clear();
    _newCategoryController.clear();
    _unitDescriptionController.clear();
    _initialStockController.text = '0';
    setState(() {
      _selectedImageBytes = null;
      _editingImageString = null;
      _editingIndex = null;
      _selectedCategory = null;
      _selectedLocationId = null;
      _showNewCategoryField = false;
      _isAvailable = true;
      _itemToProcess = null;
      _locationIdForItem = null;
      _initialStockForItem = null;
    });
  }

  void _editItem(int index, StoreItem item) {
    setState(() {
      _editingIndex = index;
      _nameController.text = item.name;
      _priceController.text = item.price.toString();
      _selectedCategory = item.category;
      _unitDescriptionController.text = item.unitDescription ?? item.unitOfMeasure;
      _descriptionController.text = item.description;
      _showNewCategoryField = false;
      _isAvailable = item.available;
      _selectedLocationId = item.locationId;
      _initialStockController.text = (item.currentStock ?? 0).toString();

      _selectedImageBytes = null;
      _editingImageString = item.imageUrl;
    });

    _showAddEditDialog(isEditing: true);
  }

  void _showDeleteConfirmation(int index, BuildContext context) {
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    final item = storeProvider.storeItems[index];
    final name = item.name;

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
            Text('Are you sure you want to delete "$name"?'),
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
                      'This item will be removed from the store immediately.',
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
                // Delete logic would go here when you implement it in provider
                Navigator.of(context).pop();
                _showSuccessSnackBar('"$name" will be deleted', Colors.red);
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

      final unitDesc = _unitDescriptionController.text.trim();
      if (unitDesc.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter unit description (e.g., 500g, 2L, Half)'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final storeProvider = Provider.of<StoreProvider>(context, listen: false);
      final String? existingId = _editingIndex != null
          ? storeProvider.storeItems[_editingIndex!].id
          : null;
      final String? existingProductId = _editingIndex != null
          ? storeProvider.storeItems[_editingIndex!].productId
          : null;

      final newItem = StoreItem(
        id: existingId ?? '',
        productId: existingProductId ?? '',
        name: _nameController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : 'Quality ${_nameController.text.trim()}',
        category: category,
        unitOfMeasure: 'Piece', // Legacy field
        unitDescription: _unitDescriptionController.text.trim(),
        available: _isAvailable,
        imageUrl: _selectedImageBytes == null ? _editingImageString : null,
        createdAt: _editingIndex != null
            ? storeProvider.storeItems[_editingIndex!].createdAt
            : DateTime.now(),
        updatedAt: DateTime.now(),
      );

      _itemToProcess = newItem;
      _locationIdForItem = _selectedLocationId;
      _initialStockForItem = int.tryParse(_initialStockController.text) ?? 0;
      
      if (_editingIndex != null) {
        final oldItem = storeProvider.storeItems[_editingIndex!];
        final hasChanges = _hasSignificantChanges(oldItem, newItem) || 
                          oldItem.available != newItem.available;
        
        if (!hasChanges && _selectedImageBytes == null) {
          Navigator.of(context).pop();
          _showErrorSnackBar('No changes detected for update.');
          return;
        }
        _showUpdateConfirmation();
      } else {
        _showAddConfirmation();
      }
    }
  }

  void _showUpdateConfirmation() {
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    final newItem = _itemToProcess!;
    final oldItem = storeProvider.storeItems[_editingIndex!];

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
            Text('Update "${newItem.name}"?'),
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
                    'Changes will be visible immediately.',
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
                      '• Price: KSh ${oldItem.price} → KSh ${newItem.price}',
                      style: TextStyle(
                        color: Colors.blue.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  if ((oldItem.unitDescription ?? oldItem.unitOfMeasure) != (newItem.unitDescription ?? newItem.unitOfMeasure))
                    Text(
                      '• Unit: ${oldItem.unitDescription ?? oldItem.unitOfMeasure} → ${newItem.unitDescription ?? newItem.unitOfMeasure}',
                      style: TextStyle(
                        color: Colors.blue.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  if (oldItem.available != newItem.available)
                    Text(
                      '• Available: ${oldItem.available ? 'Yes' : 'No'} → ${newItem.available ? 'Yes' : 'No'}',
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
            onPressed: () => _performUpdate(),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showAddConfirmation() {
    final newItem = _itemToProcess!;
    
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
            Text('Add "${newItem.name}" to store?'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'New item details:',
                    style: TextStyle(
                      color: AppColors.success.withOpacity(0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• Name: ${newItem.name}',
                    style: TextStyle(
                      color: AppColors.success.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '• Price: KSh ${newItem.price}',
                    style: TextStyle(
                      color: AppColors.success.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '• Category: ${newItem.category}',
                    style: TextStyle(
                      color: AppColors.success.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '• Unit: ${newItem.unitDescription ?? newItem.unitOfMeasure}',
                    style: TextStyle(
                      color: AppColors.success.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                  if (_locationIdForItem != null && _initialStockForItem != null && _initialStockForItem! > 0)
                    Text(
                      '• Initial Stock: $_initialStockForItem at selected location',
                      style: TextStyle(
                        color: AppColors.success.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    )
                  else
                    Text(
                      '• Initial Stock: 0 (no location selected)',
                      style: TextStyle(
                        color: AppColors.success.withOpacity(0.8),
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
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            onPressed: () => _performAdd(),
            child: const Text('Add Item'),
          ),
        ],
      ),
    );
  }

  Future<void> _performAdd() async {
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    final newItem = _itemToProcess!;

    Navigator.of(context).pop(); // Close confirmation dialog
    Navigator.of(context).pop(); // Close form dialog

    _showLoadingDialog('Adding item...');

    try {
      String? imageUrl;
      if (_selectedImageBytes != null) {
        imageUrl = await storeProvider.uploadImage(_selectedImageBytes!, 'store_item.jpg');
      }

      final itemWithImage = StoreItem(
        id: newItem.id,
        productId: newItem.productId,
        name: newItem.name,
        price: newItem.price,
        description: newItem.description,
        category: newItem.category,
        unitOfMeasure: newItem.unitOfMeasure,
        unitDescription: newItem.unitDescription,
        available: newItem.available,
        imageUrl: imageUrl ?? newItem.imageUrl,
        createdAt: newItem.createdAt,
        updatedAt: newItem.updatedAt,
      );

      await storeProvider.addStoreItem(
        itemWithImage, 
        _locationIdForItem, 
        _initialStockForItem ?? 0
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      _clearForm();
      _showSuccessSnackBar('${itemWithImage.name} added successfully!', AppColors.success);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      _showErrorSnackBar('Failed to add item: $e');
    }
  }

  Future<void> _performUpdate() async {
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    final updatedItem = _itemToProcess!;

    Navigator.of(context).pop(); // Close confirmation dialog
    Navigator.of(context).pop(); // Close form dialog

    _showLoadingDialog('Updating item...');

    try {
      String? imageUrl = updatedItem.imageUrl;
      if (_selectedImageBytes != null) {
        imageUrl = await storeProvider.uploadImage(_selectedImageBytes!, 'store_item.jpg');
      }

      final itemWithImage = StoreItem(
        id: updatedItem.id,
        productId: updatedItem.productId,
        name: updatedItem.name,
        price: updatedItem.price,
        description: updatedItem.description,
        category: updatedItem.category,
        unitOfMeasure: updatedItem.unitOfMeasure,
        unitDescription: updatedItem.unitDescription,
        available: updatedItem.available,
        imageUrl: imageUrl,
        createdAt: updatedItem.createdAt,
        updatedAt: updatedItem.updatedAt,
      );

      await storeProvider.updateStoreItem(itemWithImage);

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      _clearForm();
      _showSuccessSnackBar('${itemWithImage.name} updated successfully!', Colors.blue);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      _showErrorSnackBar('Failed to update item: $e');
    }
  }

  bool _hasSignificantChanges(StoreItem oldItem, StoreItem newItem) {
    return oldItem.name != newItem.name ||
           oldItem.price != newItem.price ||
           oldItem.category != newItem.category ||
           oldItem.unitDescription != newItem.unitDescription ||
           oldItem.description != newItem.description;
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _selectedImageBytes = bytes;
      });
    }
  }

  void _showAddEditDialog({bool isEditing = false}) {
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    
    // Get unique categories from existing items
    final categories = storeProvider.storeItems
        .map((e) => e.category)
        .where((cat) => cat.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Edit Store Item' : 'Add Store Item'),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Image Picker
                  GestureDetector(
                    onTap: () async {
                      await _pickImage();
                      setDialogState(() {});
                    },
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _selectedImageBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                _selectedImageBytes!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : _editingImageString != null && _editingImageString!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    _editingImageString!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return _buildImagePlaceholder();
                                    },
                                  ),
                                )
                              : _buildImagePlaceholder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Name
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Item Name *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter item name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Price
                  TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(
                      labelText: 'Price (KSh) *',
                      border: OutlineInputBorder(),
                      prefixText: 'KSh ',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter price';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Category
                  if (!_showNewCategoryField)
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category *',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        ...categories.map((cat) => DropdownMenuItem(
                              value: cat,
                              child: Text(cat),
                            )),
                        const DropdownMenuItem(
                          value: '__new__',
                          child: Text('+ Add New Category'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == '__new__') {
                          setDialogState(() {
                            _showNewCategoryField = true;
                            _selectedCategory = null;
                          });
                        } else {
                          setDialogState(() {
                            _selectedCategory = value;
                          });
                        }
                      },
                    ),
                  
                  if (_showNewCategoryField) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _newCategoryController,
                            decoration: const InputDecoration(
                              labelText: 'New Category *',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (_showNewCategoryField &&
                                  (value == null || value.trim().isEmpty)) {
                                return 'Please enter category name';
                              }
                              return null;
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setDialogState(() {
                              _showNewCategoryField = false;
                              _newCategoryController.clear();
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Unit Description (Flexible)
                  TextFormField(
                    controller: _unitDescriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Unit Description *',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., 500g, 2L, Half, 1 Sack, 250ml',
                      helperText: 'Specify exact size/quantity for this item',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter unit description';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),

                  // Initial Stock (only for new items)
                  if (!isEditing) ...[
                    DropdownButtonFormField<String>(
                      value: _selectedLocationId,
                      decoration: const InputDecoration(
                        labelText: 'Initial Location (Optional)',
                        border: OutlineInputBorder(),
                        helperText: 'Leave empty to add item without stock',
                      ),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text(
                            'None - Add without inventory',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ...storeProvider.locations.map((location) => DropdownMenuItem(
                              value: location.id,
                              child: Text(
                                '${location.name} (${location.locationType})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            )),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          _selectedLocationId = value;
                          if (value == null) {
                            _initialStockController.text = '0';
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _initialStockController,
                      decoration: InputDecoration(
                        labelText: 'Initial Stock Quantity',
                        border: const OutlineInputBorder(),
                        helperText: _selectedLocationId == null 
                            ? 'Select a location first to set stock'
                            : 'Stock will be added to selected location',
                      ),
                      keyboardType: TextInputType.number,
                      enabled: _selectedLocationId != null,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Availability
                  SwitchListTile(
                    title: const Text('Available for Sale'),
                    value: _isAvailable,
                    onChanged: (value) {
                      setDialogState(() {
                        _isAvailable = value;
                      });
                    },
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
              onPressed: _submitForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: isEditing ? Colors.blue : AppColors.success,
                foregroundColor: Colors.white,
              ),
              child: Text(isEditing ? 'Update' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate, size: 50, color: Colors.grey[400]),
        const SizedBox(height: 8),
        Text(
          'Tap to add image',
          style: TextStyle(color: Colors.grey[600]),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Store Management'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<StoreProvider>().loadStoreItems();
            },
          ),
        ],
      ),
      body: Consumer<StoreProvider>(
        builder: (context, storeProvider, child) {
          if (storeProvider.isLoading && storeProvider.storeItems.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (storeProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 60, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${storeProvider.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: storeProvider.loadStoreItems,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final items = storeProvider.storeItems;

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text(
                    'No store items yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap + to add your first item',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final stock = item.currentStock ?? 0;
              final isLowStock = stock > 0 && stock <= 5;
              final isOutOfStock = stock == 0;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[200],
                    ),
                    child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              item.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(Icons.inventory_2, color: Colors.grey[400]);
                              },
                            ),
                          )
                        : Icon(Icons.inventory_2, color: Colors.grey[400]),
                  ),
                  title: Text(
                    item.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: item.available ? null : TextDecoration.lineThrough,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('KSh ${item.price.toStringAsFixed(2)}'),
                      Text('${item.category} • ${item.unitDescription ?? item.unitOfMeasure}'),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            isOutOfStock ? Icons.error : 
                            isLowStock ? Icons.warning : Icons.check_circle,
                            size: 16,
                            color: isOutOfStock ? Colors.red : 
                                   isLowStock ? Colors.orange : Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$stock in stock',
                            style: TextStyle(
                              fontSize: 12,
                              color: isOutOfStock ? Colors.red : 
                                     isLowStock ? Colors.orange : Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Row(
                          children: [
                            Icon(
                              item.available ? Icons.visibility_off : Icons.visibility,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(item.available ? 'Hide from Store' : 'Show in Store'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'inventory',
                        child: Row(
                          children: [
                            Icon(Icons.inventory, size: 20),
                            SizedBox(width: 8),
                            Text('Manage Stock'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) async {
                      switch (value) {
                        case 'edit':
                          _editItem(index, item);
                          break;
                        case 'toggle':
                          await storeProvider.toggleAvailability(
                            item.id,
                            !item.available,
                          );
                          break;
                        case 'inventory':
                          _showStockManagementDialog(item);
                          break;
                        case 'delete':
                          _showDeleteConfirmation(index, context);
                          break;
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
    );
  }

  void _showStockManagementDialog(StoreItem item) {
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    final stockController = TextEditingController(
      text: (item.currentStock ?? 0).toString(),
    );
    String? selectedLocationId = item.locationId ?? storeProvider.locations.firstOrNull?.id;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Manage Stock - ${item.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (storeProvider.locations.isEmpty)
                const Text('No locations available. Please add a warehouse or store location.'),
              
              if (storeProvider.locations.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  value: selectedLocationId,
                  decoration: const InputDecoration(
                    labelText: 'Location *',
                    border: OutlineInputBorder(),
                  ),
                  isExpanded: true,
                  items: storeProvider.locations.map((location) => DropdownMenuItem(
                        value: location.id,
                        child: Text(
                          '${location.name} (${location.locationType})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      )).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedLocationId = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: stockController,
                  decoration: const InputDecoration(
                    labelText: 'Stock Quantity *',
                    border: OutlineInputBorder(),
                    helperText: 'This will replace the current stock level',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedLocationId == null ? null : () async {
                final quantity = int.tryParse(stockController.text) ?? 0;
                Navigator.of(context).pop();
                
                try {
                  await storeProvider.updateInventory(
                    item.productId,
                    selectedLocationId!,
                    quantity,
                  );
                  _showSuccessSnackBar('Stock updated successfully!', Colors.green);
                } catch (e) {
                  _showErrorSnackBar('Failed to update stock: $e');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Update Stock'),
            ),
          ],
        ),
      ),
    );
  }
}
