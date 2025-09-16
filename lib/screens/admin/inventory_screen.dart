import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../models/inventory_item.dart';
import '../../services/inventory_service.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Management'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddEditInventoryDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search inventory...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _filter = value.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: Consumer<InventoryService>(
              builder: (context, inventoryService, child) {
                final items = inventoryService.items
                    .where((item) =>
                        item.name.toLowerCase().contains(_filter) ||
                        item.category.toLowerCase().contains(_filter))
                    .toList();
                
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _InventoryItemCard(
                      item: item,
                      onEdit: () => _showAddEditInventoryDialog(context, item: item),
                      onDelete: () => _showDeleteDialog(context, item),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddEditInventoryDialog(BuildContext context, {InventoryItem? item}) {
    final nameController = TextEditingController(text: item?.name ?? '');
    final categoryController = TextEditingController(text: item?.category ?? '');
    final quantityController = TextEditingController(text: item?.quantity.toString() ?? '');
    final unitController = TextEditingController(text: item?.unit ?? '');
    final thresholdController = TextEditingController(text: item?.lowStockThreshold.toString() ?? '5');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(item == null ? 'Add Inventory Item' : 'Edit Inventory Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Item Name'),
                ),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: quantityController,
                        decoration: const InputDecoration(labelText: 'Quantity'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: unitController,
                        decoration: const InputDecoration(labelText: 'Unit'),
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: thresholdController,
                  decoration: const InputDecoration(labelText: 'Low Stock Threshold'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newItem = InventoryItem(
                  id: item?.id ?? DateTime.now().toString(),
                  name: nameController.text,
                  category: categoryController.text,
                  quantity: double.tryParse(quantityController.text) ?? 0,
                  unit: unitController.text,
                  lowStockThreshold: double.tryParse(thresholdController.text) ?? 5,
                );
                
                if (item == null) {
                  Provider.of<InventoryService>(context, listen: false).addItem(newItem);
                } else {
                  Provider.of<InventoryService>(context, listen: false).updateItem(newItem);
                }
                
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteDialog(BuildContext context, InventoryItem item) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: Text('Are you sure you want to delete ${item.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Provider.of<InventoryService>(context, listen: false).deleteItem(item.id);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}

class _InventoryItemCard extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _InventoryItemCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isLowStock = item.quantity <= item.lowStockThreshold;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isLowStock ? Colors.red[50] : null,
      child: ListTile(
        title: Text(
          item.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isLowStock ? Colors.red : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Category: ${item.category}'),
            Text('Quantity: ${item.quantity} ${item.unit}'),
            if (isLowStock)
              Text(
                'LOW STOCK!',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: AppColors.primary),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}