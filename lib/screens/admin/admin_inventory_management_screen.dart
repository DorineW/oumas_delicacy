// lib/screens/admin/admin_inventory_management_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/store_provider.dart';
import '../../models/product_inventory.dart';
import '../../providers/menu_provider.dart';
import '../../models/menu_item.dart';

class AdminInventoryManagementScreen extends StatefulWidget {
  const AdminInventoryManagementScreen({super.key});

  @override
  State<AdminInventoryManagementScreen> createState() => _AdminInventoryManagementScreenState();
}

class _AdminInventoryManagementScreenState extends State<AdminInventoryManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showLowStockOnly = false;

  @override
  void initState() {
    super.initState();
    // Load data after the frame is built to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _loadInventory();
  }

  Future<void> _loadInventory() async {
    final inventoryProvider = context.read<InventoryProvider>();
    await inventoryProvider.loadInventory();
    await inventoryProvider.loadLowStockAlerts();
  }

  List<ProductInventory> _filterInventory(List<ProductInventory> inventory) {
    var filtered = inventory;

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((item) {
        final productName = item.productName?.toLowerCase() ?? '';
        final locationName = item.locationName?.toLowerCase() ?? '';
        final productId = item.productId.toLowerCase();
        final query = _searchQuery.toLowerCase();
        
        return productName.contains(query) || 
               locationName.contains(query) || 
               productId.contains(query);
      }).toList();
    }

    // Filter by low stock
    if (_showLowStockOnly) {
      filtered = filtered.where((item) => item.isLowStock).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final inventoryProvider = context.watch<InventoryProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Inventory Management'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInventory,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.warning_amber),
            onPressed: () => _showLowStockAlertsDialog(context),
            tooltip: 'Low Stock Alerts',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatsHeader(inventoryProvider),
          _buildSearchAndFilters(),
          Expanded(
            child: inventoryProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildInventoryList(inventoryProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddInventoryDialog(context),
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          FilterChip(
            label: const Text('Low Stock'),
            selected: _showLowStockOnly,
            onSelected: (selected) {
              setState(() {
                _showLowStockOnly = selected;
              });
            },
            selectedColor: Colors.orange[100],
            checkmarkColor: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(InventoryProvider provider) {
    final stats = provider.getStats();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.primary.withOpacity(0.05),
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatCard(
            'Total Products',
            stats['total_products'].toString(),
            Icons.inventory_2,
            AppColors.primary,
          ),
          _buildStatCard(
            'In Stock',
            stats['in_stock'].toString(),
            Icons.check_circle,
            AppColors.success,
          ),
          _buildStatCard(
            'Low Stock',
            stats['low_stock'].toString(),
            Icons.warning,
            Colors.orange,
          ),
          _buildStatCard(
            'Out of Stock',
            stats['out_of_stock'].toString(),
            Icons.remove_circle,
            Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildInventoryList(InventoryProvider provider) {
    final inventory = _filterInventory(provider.inventory);

    if (inventory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _showLowStockOnly
                  ? 'No low stock items'
                  : 'No inventory items',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            const Text('Add products to start tracking inventory'),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: inventory.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = inventory[index];
        return _buildInventoryCard(item);
      },
    );
  }

  Widget _buildInventoryCard(ProductInventory item) {
    final statusColor = item.isOutOfStock
        ? Colors.red
        : item.isLowStock
            ? Colors.orange
            : AppColors.success;

    final statusText = item.isOutOfStock
        ? 'Out of Stock'
        : item.isLowStock
            ? 'Low Stock'
            : 'In Stock';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showInventoryDetailsDialog(context, item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName ?? 'Unknown Product',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${item.productId.substring(0, 8)}...',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoColumn(
                      'Quantity',
                      item.quantity.toString(),
                      Icons.inventory,
                      statusColor,
                    ),
                  ),
                  Expanded(
                    child: _buildInfoColumn(
                      'Min Alert',
                      item.minimumStockAlert.toString(),
                      Icons.notification_important,
                      Colors.grey,
                    ),
                  ),
                  Expanded(
                    child: _buildInfoColumn(
                      'Last Restock',
                      item.lastRestockDate != null
                          ? _formatDate(item.lastRestockDate!)
                          : 'Never',
                      Icons.history,
                      Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showRestockDialog(context, item),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Restock'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _showEditDialog(context, item),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      side: const BorderSide(color: AppColors.accent),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }

  Future<void> _showRestockDialog(BuildContext context, ProductInventory item) async {
    final quantityController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restock Inventory'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current Quantity: ${item.quantity}'),
              const SizedBox(height: 16),
              TextFormField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Add Quantity',
                  hintText: 'Enter quantity to add',
                  prefixIcon: Icon(Icons.add),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter quantity';
                  }
                  final qty = int.tryParse(value);
                  if (qty == null || qty <= 0) {
                    return 'Please enter a valid positive number';
                  }
                  return null;
                },
              ),
            ],
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
                final qty = int.parse(quantityController.text);
                Navigator.pop(context);

                if (!mounted) return;
                final provider = context.read<InventoryProvider>();
                final success = await provider.restock(
                  item.productId,
                  qty,
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'Successfully restocked $qty units'
                            : 'Failed to restock inventory',
                      ),
                      backgroundColor: success ? AppColors.success : Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Restock'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context, ProductInventory item) async {
    final quantityController = TextEditingController(text: item.quantity.toString());
    final minAlertController = TextEditingController(text: item.minimumStockAlert.toString());
    final formKey = GlobalKey<FormState>();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Inventory'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  prefixIcon: Icon(Icons.inventory),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  final qty = int.tryParse(value);
                  if (qty == null || qty < 0) return 'Invalid number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: minAlertController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Minimum Stock Alert',
                  prefixIcon: Icon(Icons.warning),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  final qty = int.tryParse(value);
                  if (qty == null || qty < 0) return 'Invalid number';
                  return null;
                },
              ),
            ],
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
                final qty = int.parse(quantityController.text);
                final minAlert = int.parse(minAlertController.text);
                Navigator.pop(context);

                if (!mounted) return;
                final inventoryProvider = context.read<InventoryProvider>();
                final storeProvider = context.read<StoreProvider>();
                
                await inventoryProvider.updateInventoryItem(
                  inventoryId: item.id,
                  quantity: qty,
                  minimumStockAlert: minAlert,
                );

                // Reload store items to reflect updated stock
                await storeProvider.loadStoreItems();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Inventory updated successfully'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddInventoryDialog(BuildContext context) async {
    final menuProvider = Provider.of<MenuProvider>(context, listen: false);
    final inventoryProvider = context.read<InventoryProvider>();

    // Get productIds already in inventory
    final existingProductIds = inventoryProvider.inventory
        .map((inv) => inv.productId)
        .toSet();

    // Get menu items not yet in inventory for this location
    final availableMenuItems = menuProvider.menuItems
        .where((item) => item.productId != null && !existingProductIds.contains(item.productId))
        .toList();

    if (availableMenuItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All products are already in inventory for this location.')),
      );
      return;
    }

    MenuItem? selectedMenuItem = availableMenuItems.first;
    final quantityController = TextEditingController();
    final minAlertController = TextEditingController(text: '10');
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Product to Inventory'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<MenuItem>(
                value: selectedMenuItem,
                items: availableMenuItems.map((item) {
                  return DropdownMenuItem(
                    value: item,
                    child: Text(item.title),
                  );
                }).toList(),
                onChanged: (item) {
                  selectedMenuItem = item;
                },
                decoration: const InputDecoration(
                  labelText: 'Product',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Initial Quantity',
                  prefixIcon: Icon(Icons.inventory),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  final qty = int.tryParse(value);
                  if (qty == null || qty < 0) return 'Invalid number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: minAlertController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Minimum Stock Alert',
                  prefixIcon: Icon(Icons.warning),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  final qty = int.tryParse(value);
                  if (qty == null || qty < 0) return 'Invalid number';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate() && selectedMenuItem != null) {
                final qty = int.parse(quantityController.text);
                final minAlert = int.parse(minAlertController.text);
                Navigator.pop(context);

                final provider = context.read<InventoryProvider>();
                
                await provider.addInventoryItem(
                  productId: selectedMenuItem!.productId!,
                  initialQuantity: qty,
                  minimumStockAlert: minAlert,
                );
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Product added to inventory'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _showInventoryDetailsDialog(BuildContext context, ProductInventory item) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Inventory Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Product ID: ${item.productId}'),
            if (item.locationName != null) Text('Location: ${item.locationName}'),
            Text('Quantity: ${item.quantity}'),
            Text('Minimum Alert: ${item.minimumStockAlert}'),
            Text('Last Restock: ${item.lastRestockDate != null ? _formatDate(item.lastRestockDate!) : 'Never'}'),
            const SizedBox(height: 16),
            const Text('Inventory History:', style: TextStyle(fontWeight: FontWeight.bold)),
            const Text('(History feature coming soon)', style: TextStyle(color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showLowStockAlertsDialog(BuildContext context) async {
    final provider = context.read<InventoryProvider>();
    final alerts = provider.lowStockAlerts;

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 8),
            Text('Low Stock Alerts (${alerts.length})'),
          ],
        ),
        content: alerts.isEmpty
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text('No low stock alerts!'),
                ],
              )
            : SizedBox(
                width: double.maxFinite,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: alerts.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final alert = alerts[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange[100],
                        child: Text(
                          alert.unitsBelowMinimum.toString(),
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(alert.productName),
                      subtitle: Text(
                        '${alert.category ?? 'Store Item'}\n'
                        'Stock: ${alert.quantity} / Min: ${alert.minimumStockAlert}',
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.add_circle, color: AppColors.primary),
                        onPressed: () {
                          Navigator.pop(context);
                          _showRestockDialog(context, ProductInventory(
                            id: alert.id,
                            productId: alert.productId,
                            quantity: alert.quantity,
                            minimumStockAlert: alert.minimumStockAlert,
                            lastRestockDate: alert.lastRestockDate,
                            createdAt: alert.updatedAt,
                            updatedAt: alert.updatedAt,
                          ));
                        },
                      ),
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
