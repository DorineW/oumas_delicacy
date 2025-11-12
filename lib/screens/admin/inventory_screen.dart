import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../providers/inventory_provider.dart';
import '../../models/inventory_item.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filter = '';
  
  // ADDED: State for showing/hiding low stock section
  bool _showLowStockSection = false;

  @override
  void initState() {
    super.initState();
    // Load inventory items when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().loadInventoryItems();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<InventoryItem> _getFilteredItems(List<InventoryItem> items) {
    return items.where((item) {
      final matchesSearch = item.name.toLowerCase().contains(_filter.toLowerCase()) ||
          item.category.toLowerCase().contains(_filter.toLowerCase());
      return matchesSearch;
    }).toList();
  }

  List<InventoryItem> _getLowStockItems(List<InventoryItem> items) {
    return items.where((item) => item.quantity <= item.lowStockThreshold).toList();
  }

  Widget _buildStatsHeader(List<InventoryItem> items) {
    final totalItems = items.length;
    final lowStockItems = _getLowStockItems(items);
    final lowStockCount = lowStockItems.length;
    final totalQuantity = items.fold<double>(0, (sum, item) => sum + item.quantity);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withOpacity(0.1), AppColors.primary.withOpacity(0.05)],
        ),
        border: Border(
          bottom: BorderSide(color: AppColors.primary.withOpacity(0.1)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total Items', totalItems.toString(), Icons.inventory_2, AppColors.primary),
          _buildStatItem('Low Stock', lowStockCount.toString(), Icons.warning, Colors.orange),
          _buildStatItem('Total Quantity', totalQuantity.toStringAsFixed(0), Icons.inventory, AppColors.success),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    final isLowStock = label == 'Low Stock';
    
    return GestureDetector(
      onTap: isLowStock ? () {
        setState(() {
          _showLowStockSection = !_showLowStockSection;
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
              if (isLowStock) ...[
                const SizedBox(width: 4),
                Icon(
                  _showLowStockSection ? Icons.visibility_off : Icons.visibility,
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

  // ADDED: New collapsible low stock section (like chart in admin dashboard)
  Widget _buildLowStockSection(List<InventoryItem> items) {
    final lowStockItems = _getLowStockItems(items);
    if (!_showLowStockSection || lowStockItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
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
                  color: Colors.orange.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning, color: Colors.orange, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Low Stock Items',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.orange,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${lowStockItems.length}',
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
          
          // Low stock items list - UPDATED: Removed restock button
          ...lowStockItems.map((item) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                // Item icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getCategoryIcon(item.category),
                    size: 20,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                
                // Item details - UPDATED: Takes full width without restock button
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '${item.quantity} ${item.unit}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            ' / ${item.lowStockThreshold} ${item.unit}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.darkText.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // REMOVED: Restock button - users can restock from cards below
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildInventoryCard(InventoryItem item, int index) {
    final isLowStock = item.quantity <= item.lowStockThreshold;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isLowStock
                        ? Colors.orange.withOpacity(0.1)
                        : AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getCategoryIcon(item.category),
                    color: isLowStock ? Colors.orange : AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        item.category,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.darkText.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isLowStock)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: const Text(
                      'LOW',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // FIXED: Stock section with proper constraints
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Stock',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.darkText.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Stock quantity display (adjustment buttons feature not implemented yet)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // TODO: Implement stock adjustment buttons with provider
                            // _buildStockButton(Icons.remove, () => adjustStock(item, -1)),
                            // const SizedBox(width: 8),
                            Text(
                              '${item.quantity} ${item.unit}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isLowStock ? Colors.orange : AppColors.primary,
                              ),
                            ),
                            // const SizedBox(width: 8),
                            // _buildStockButton(Icons.add, () => adjustStock(item, 1)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: AppColors.lightGray,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Alert Level',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.darkText.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.lowStockThreshold} ${item.unit}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis, // ADDED: Handle long text
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time, size: 12, color: AppColors.darkText.withOpacity(0.5)),
                const SizedBox(width: 4),
                Text(
                  'Last updated: ${item.updatedAt != null ? _formatRestockDate(item.updatedAt!) : 'Never'}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.darkText.withOpacity(0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Restock feature not implemented yet
                // Expanded(
                //   child: OutlinedButton.icon(
                //     icon: const Icon(Icons.inventory_2, size: 16),
                //     label: const Text('Restock', style: TextStyle(fontSize: 12)),
                //     onPressed: () => _showRestockDialog(index),
                //     style: OutlinedButton.styleFrom(
                //       padding: const EdgeInsets.symmetric(vertical: 8),
                //     ),
                //   ),
                // ),
                // const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit', style: TextStyle(fontSize: 12)),
                    onPressed: () => _showAddEditDialog(item: item, index: index),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                // Stock history feature not yet implemented
                // const SizedBox(width: 8),
                // IconButton(
                //   icon: const Icon(Icons.history, size: 20),
                //   color: AppColors.primary,
                //   padding: EdgeInsets.zero,
                //   constraints: const BoxConstraints(),
                //   onPressed: () => _showStockHistory(item.id),
                // ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Grains':
        return Icons.grain;
      case 'Meat':
        return Icons.set_meal;
      case 'Vegetables':
        return Icons.eco;
      case 'Drinks':
        return Icons.local_drink;
      case 'Spices':
        return Icons.spa;
      case 'Dairy':
        return Icons.emoji_food_beverage;
      case 'Oils':
        return Icons.water_drop;
      default:
        return Icons.inventory_2;
    }
  }

  String _formatRestockDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  // Stock adjustment feature - needs to be reimplemented using provider
  // void _adjustStock(int index, double adjustment) {
  //   // TODO: Implement using InventoryProvider.updateStock()
  // }

  // Restock dialog - needs to be reimplemented using provider
  // void _showRestockDialog(int index) {
  //   // TODO: Implement using InventoryProvider.updateStock()
  // }

  void _showAddEditDialog({InventoryItem? item, int? index}) async {
    final isEditing = item != null;
    final nameController = TextEditingController(text: item?.name ?? '');
    final categoryController = TextEditingController(text: item?.category ?? '');
    final stockController = TextEditingController(text: item?.quantity.toString() ?? '');
    final thresholdController = TextEditingController(text: item?.lowStockThreshold.toString() ?? '');
    
    String selectedUnit = item?.unit ?? 'kg';
    final formKey = GlobalKey<FormState>();
    
    final inventoryProvider = Provider.of<InventoryProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isEditing ? Icons.edit : Icons.add,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  isEditing ? 'Edit Item' : 'Add New Item',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Item Name',
                        prefixIcon: const Icon(Icons.inventory, color: AppColors.primary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: categoryController,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        prefixIcon: const Icon(Icons.category, color: AppColors.primary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: stockController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Stock',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            validator: (value) => double.tryParse(value ?? '') == null ? 'Invalid' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedUnit,
                            isExpanded: true,
                            isDense: true,
                            items: ['kg', 'pieces', 'liters', 'grams', 'boxes', 'packets', 'bottles']
                                .map((unit) => DropdownMenuItem(
                                  value: unit, 
                                  child: Text(
                                    unit, 
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ))
                                .toList(),
                            onChanged: (value) => setDialogState(() => selectedUnit = value!),
                            decoration: InputDecoration(
                              labelText: 'Unit',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: thresholdController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Low Stock Alert Level',
                        prefixIcon: const Icon(Icons.warning, color: Colors.orange),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      validator: (value) => double.tryParse(value ?? '') == null ? 'Invalid' : null,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    final newItem = InventoryItem(
                      id: item?.id, // null for new items, existing id for updates
                      name: nameController.text,
                      category: categoryController.text,
                      quantity: double.parse(stockController.text),
                      unit: selectedUnit,
                      lowStockThreshold: double.parse(thresholdController.text),
                      updatedAt: DateTime.now(),
                    );

                    try {
                      if (isEditing) {
                        await inventoryProvider.updateInventoryItem(newItem);
                      } else {
                        await inventoryProvider.addInventoryItem(newItem);
                      }
                      
                      if (context.mounted) {
                        Navigator.pop(context);
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.white),
                                const SizedBox(width: 8),
                                Text(isEditing ? 'Item updated' : 'Item added'),
                              ],
                            ),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(isEditing ? 'Update' : 'Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Stock history feature not implemented yet (not in database schema)
  // void _addToStockHistory(String itemId, String type, double quantity, String note) {
  //   // TODO: Implement stock history tracking
  // }

  // void _showStockHistory(String itemId) {
  //   // TODO: Implement stock history view
  // }

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryProvider>(
      builder: (context, inventoryProvider, child) {
        final allItems = inventoryProvider.items;
        final filteredItems = _getFilteredItems(allItems);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Inventory Management'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 4,
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
          _buildStatsHeader(allItems),
          _buildLowStockSection(allItems), // Uses inline collapsible section instead of dialog
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search inventory...',
                hintStyle: const TextStyle(fontSize: 14),
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                isDense: true,
              ),
              onChanged: (value) {
                setState(() {
                  _filter = value;
                });
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filteredItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2,
                          size: 80,
                          color: AppColors.darkText.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Items Found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkText.withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _filter.isEmpty
                              ? 'Add items to get started'
                              : 'Try adjusting your search',
                          style: TextStyle(
                            color: AppColors.darkText.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      return _buildInventoryCard(filteredItems[index], index);
                    },
                  ),
          ),
        ],
      ),
      );
    });
  }
}