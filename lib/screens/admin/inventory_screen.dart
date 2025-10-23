import 'package:flutter/material.dart';
import '../../constants/colors.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filter = '';
  String _selectedCategory = 'All';
  
  final List<String> _categories = ['All', 'Grains', 'Vegetables', 'Meat', 'Drinks', 'Spices', 'Dairy', 'Oils'];
  
  final List<InventoryItem> _items = [
    InventoryItem(
      id: '1',
      name: 'Ugali Flour',
      category: 'Grains',
      currentStock: 25.5,
      unit: 'kg',
      lowStockThreshold: 10.0,
      costPrice: 80.0,
      sellingPrice: 120.0,
      supplier: 'Nairobi Millers',
      lastRestocked: DateTime.now().subtract(const Duration(days: 2)),
    ),
    InventoryItem(
      id: '2',
      name: 'Beef (Prime Cut)',
      category: 'Meat',
      currentStock: 8.5,
      unit: 'kg',
      lowStockThreshold: 10.0,
      costPrice: 450.0,
      sellingPrice: 650.0,
      supplier: 'Fresh Meats Ltd',
      lastRestocked: DateTime.now().subtract(const Duration(days: 1)),
    ),
    InventoryItem(
      id: '3',
      name: 'Rice (Pishori)',
      category: 'Grains',
      currentStock: 45.0,
      unit: 'kg',
      lowStockThreshold: 20.0,
      costPrice: 120.0,
      sellingPrice: 180.0,
      supplier: 'Mwea Rice Co.',
      lastRestocked: DateTime.now().subtract(const Duration(days: 3)),
    ),
    InventoryItem(
      id: '4',
      name: 'Cooking Oil',
      category: 'Oils',
      currentStock: 15.0,
      unit: 'liters',
      lowStockThreshold: 8.0,
      costPrice: 180.0,
      sellingPrice: 250.0,
      supplier: 'Fresh Fri',
      lastRestocked: DateTime.now().subtract(const Duration(days: 4)),
    ),
    InventoryItem(
      id: '5',
      name: 'Tomatoes',
      category: 'Vegetables',
      currentStock: 3.0,
      unit: 'kg',
      lowStockThreshold: 5.0,
      costPrice: 50.0,
      sellingPrice: 80.0,
      supplier: 'Local Farm',
      lastRestocked: DateTime.now(),
    ),
  ];

  final List<StockHistory> _stockHistory = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<InventoryItem> get _filteredItems {
    return _items.where((item) {
      final matchesSearch = item.name.toLowerCase().contains(_filter.toLowerCase()) ||
          item.category.toLowerCase().contains(_filter.toLowerCase());
      final matchesCategory = _selectedCategory == 'All' || item.category == _selectedCategory;
      return matchesSearch && matchesCategory && item.isActive;
    }).toList();
  }

  List<InventoryItem> get _lowStockItems {
    return _items.where((item) => item.currentStock <= item.lowStockThreshold && item.isActive).toList();
  }

  Widget _buildStatsHeader() {
    final totalItems = _items.where((item) => item.isActive).length;
    final lowStockCount = _lowStockItems.length;
    final totalValue = _items.where((item) => item.isActive).fold<double>(
      0, (sum, item) => sum + (item.currentStock * item.costPrice)
    );
    final totalProfit = _items.where((item) => item.isActive).fold<double>(
      0, (sum, item) => sum + (item.currentStock * (item.sellingPrice - item.costPrice))
    );

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
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Total Items', totalItems.toString(), Icons.inventory_2, AppColors.primary),
              _buildStatItem('Low Stock', lowStockCount.toString(), Icons.warning, Colors.orange),
              _buildStatItem('Stock Value', 'Ksh ${totalValue.toStringAsFixed(0)}', Icons.attach_money, AppColors.success),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.success.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.trending_up, color: AppColors.success, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Potential Profit: Ksh ${totalProfit.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
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

  Widget _buildLowStockAlert() {
    if (_lowStockItems.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              Expanded(
                child: Text(
                  'Low Stock Alerts',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
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
                  '${_lowStockItems.length} items',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._lowStockItems.take(3).map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.circle, size: 8, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${item.name}: ${item.currentStock} ${item.unit} left',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Text(
                  'Need ${item.lowStockThreshold} ${item.unit}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.darkText.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          )),
          if (_lowStockItems.length > 3)
            TextButton(
              onPressed: () => _showLowStockDialog(),
              child: Text('View all ${_lowStockItems.length} items'),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: _buildQuickActionCard(
              Icons.add_circle,
              'Add Item',
              Colors.green,
              () => _showAddEditDialog(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildQuickActionCard(
              Icons.download,
              'Import',
              Colors.blue,
              () => _showImportDialog(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildQuickActionCard(
              Icons.analytics,
              'Report',
              Colors.purple,
              () => _generateStockReport(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: _categories.map((category) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(
            label: Text(category),
            selected: _selectedCategory == category,
            onSelected: (selected) {
              setState(() {
                _selectedCategory = selected ? category : 'All';
              });
            },
            selectedColor: AppColors.primary,
            labelStyle: TextStyle(
              color: _selectedCategory == category ? Colors.white : AppColors.darkText,
              fontWeight: FontWeight.w600,
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildInventoryCard(InventoryItem item, int index) {
    final isLowStock = item.currentStock <= item.lowStockThreshold;
    final profitMargin = ((item.sellingPrice - item.costPrice) / item.costPrice * 100);

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
                        Row(
                          children: [
                            _buildStockButton(Icons.remove, () => _adjustStock(index, -1)),
                            const SizedBox(width: 12),
                            Text(
                              '${item.currentStock} ${item.unit}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isLowStock ? Colors.orange : AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            _buildStockButton(Icons.add, () => _adjustStock(index, 1)),
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
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPriceTag('Cost', item.costPrice),
                _buildPriceTag('Price', item.sellingPrice),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Margin: ${profitMargin.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.local_shipping, size: 12, color: AppColors.darkText.withOpacity(0.5)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Supplier: ${item.supplier}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.darkText.withOpacity(0.6),
                    ),
                  ),
                ),
                Icon(Icons.access_time, size: 12, color: AppColors.darkText.withOpacity(0.5)),
                const SizedBox(width: 4),
                Text(
                  _formatRestockDate(item.lastRestocked),
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
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.inventory_2, size: 16),
                    label: const Text('Restock', style: TextStyle(fontSize: 12)),
                    onPressed: () => _showRestockDialog(index),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
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
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.history, size: 20),
                  color: AppColors.primary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _showStockHistory(item.id),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockButton(IconData icon, VoidCallback onPressed) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: IconButton(
        icon: Icon(icon, size: 16),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        color: AppColors.primary,
      ),
    );
  }

  Widget _buildPriceTag(String label, double price) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppColors.darkText.withOpacity(0.6),
          ),
        ),
        Text(
          'Ksh ${price.toStringAsFixed(0)}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
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

  void _adjustStock(int index, double adjustment) {
    setState(() {
      double newStock = _items[index].currentStock + adjustment;
      if (newStock >= 0) {
        final oldStock = _items[index].currentStock;
        _items[index].currentStock = newStock;
        
        _addToStockHistory(
          _items[index].id,
          'adjustment',
          adjustment,
          'Manual stock adjustment from $oldStock to $newStock ${_items[index].unit}',
        );
      }
    });
  }

  void _showRestockDialog(int index) {
    final item = _items[index];
    final quantityController = TextEditingController();
    final costController = TextEditingController(text: item.costPrice.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.inventory_2, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Restock Item', style: TextStyle(fontSize: 16)),
                  Text(
                    item.name,
                    style: TextStyle(fontSize: 12, color: AppColors.darkText.withOpacity(0.6)),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Quantity',
                suffixText: item.unit,
                prefixIcon: Icon(Icons.add_circle, color: AppColors.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: costController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Cost per ${item.unit}',
                prefixText: 'Ksh ',
                prefixIcon: Icon(Icons.attach_money, color: AppColors.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              double quantity = double.tryParse(quantityController.text) ?? 0;
              double cost = double.tryParse(costController.text) ?? 0;
              if (quantity > 0 && cost > 0) {
                _restockItem(index, quantity, cost);
                Navigator.pop(context);
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

  void _restockItem(int index, double quantity, double cost) {
    setState(() {
      _items[index].currentStock += quantity;
      _items[index].costPrice = cost;
      _items[index].lastRestocked = DateTime.now();
      
      _addToStockHistory(
        _items[index].id,
        'restock',
        quantity,
        'Restocked $quantity ${_items[index].unit} at Ksh $cost per ${_items[index].unit}',
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${_items[index].name} restocked successfully'),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showAddEditDialog({InventoryItem? item, int? index}) {
    final isEditing = item != null;
    final nameController = TextEditingController(text: item?.name ?? '');
    final categoryController = TextEditingController(text: item?.category ?? '');
    final stockController = TextEditingController(text: item?.currentStock.toString() ?? '');
    final thresholdController = TextEditingController(text: item?.lowStockThreshold.toString() ?? '');
    final costController = TextEditingController(text: item?.costPrice.toString() ?? '');
    final priceController = TextEditingController(text: item?.sellingPrice.toString() ?? '');
    final supplierController = TextEditingController(text: item?.supplier ?? '');
    
    String selectedUnit = item?.unit ?? 'kg';
    final formKey = GlobalKey<FormState>();

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
                        prefixIcon: Icon(Icons.inventory, color: AppColors.primary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _categories.contains(categoryController.text) ? categoryController.text : null,
                      items: _categories.skip(1).map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                      decoration: InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(Icons.category, color: AppColors.primary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (value) => categoryController.text = value ?? '',
                      validator: (value) => value == null ? 'Required' : null,
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
                            items: ['kg', 'pieces', 'liters', 'grams', 'boxes', 'packets', 'bottles']
                                .map((unit) => DropdownMenuItem(value: unit, child: Text(unit)))
                                .toList(),
                            onChanged: (value) => setDialogState(() => selectedUnit = value!),
                            decoration: InputDecoration(
                              labelText: 'Unit',
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
                        prefixIcon: Icon(Icons.warning, color: Colors.orange),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      validator: (value) => double.tryParse(value ?? '') == null ? 'Invalid' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: costController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Cost Price',
                              prefixText: 'Ksh ',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            validator: (value) => double.tryParse(value ?? '') == null ? 'Invalid' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: priceController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Selling Price',
                              prefixText: 'Ksh ',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            validator: (value) => double.tryParse(value ?? '') == null ? 'Invalid' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: supplierController,
                      decoration: InputDecoration(
                        labelText: 'Supplier',
                        prefixIcon: Icon(Icons.local_shipping, color: AppColors.primary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
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
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    final newItem = InventoryItem(
                      id: item?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameController.text,
                      category: categoryController.text,
                      currentStock: double.parse(stockController.text),
                      unit: selectedUnit,
                      lowStockThreshold: double.parse(thresholdController.text),
                      costPrice: double.parse(costController.text),
                      sellingPrice: double.parse(priceController.text),
                      supplier: supplierController.text,
                      lastRestocked: item?.lastRestocked ?? DateTime.now(),
                    );

                    setState(() {
                      if (isEditing && index != null) {
                        _items[index] = newItem;
                      } else {
                        _items.add(newItem);
                      }
                    });

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

  void _addToStockHistory(String itemId, String type, double quantity, String note) {
    _stockHistory.add(StockHistory(
      date: DateTime.now(),
      itemId: itemId,
      type: type,
      quantity: quantity,
      note: note,
    ));
  }

  void _showStockHistory(String itemId) {
    final history = _stockHistory.where((h) => h.itemId == itemId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final item = _items.firstWhere((i) => i.id == itemId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.history, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Stock History',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          item.name,
                          style: TextStyle(fontSize: 12, color: AppColors.darkText.withOpacity(0.6)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: history.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 60, color: AppColors.darkText.withOpacity(0.3)),
                          const SizedBox(height: 12),
                          Text(
                            'No history available',
                            style: TextStyle(color: AppColors.darkText.withOpacity(0.5)),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        final h = history[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _getHistoryColor(h.type).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getHistoryIcon(h.type),
                                color: _getHistoryColor(h.type),
                                size: 20,
                              ),
                            ),
                            title: Text(
                              h.note,
                              style: const TextStyle(fontSize: 13),
                            ),
                            subtitle: Text(
                              _formatDateTime(h.date),
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: Text(
                              '${h.quantity > 0 ? '+' : ''}${h.quantity} ${item.unit}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: h.quantity > 0 ? AppColors.success : Colors.red,
                              ),
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

  Color _getHistoryColor(String type) {
    switch (type) {
      case 'restock':
        return AppColors.success;
      case 'adjustment':
        return AppColors.primary;
      case 'sale':
        return Colors.red;
      default:
        return AppColors.darkText;
    }
  }

  IconData _getHistoryIcon(String type) {
    switch (type) {
      case 'restock':
        return Icons.inventory_2;
      case 'adjustment':
        return Icons.edit;
      case 'sale':
        return Icons.shopping_cart;
      default:
        return Icons.circle;
    }
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showLowStockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 8),
            const Text('Low Stock Items'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: _lowStockItems.length,
            itemBuilder: (context, index) {
              final item = _lowStockItems[index];
              return ListTile(
                leading: Icon(_getCategoryIcon(item.category), color: Colors.orange),
                title: Text(item.name),
                subtitle: Text('${item.currentStock} ${item.unit} left • Need ${item.lowStockThreshold} ${item.unit}'),
                trailing: IconButton(
                  icon: Icon(Icons.add_circle, color: AppColors.primary),
                  onPressed: () {
                    Navigator.pop(context);
                    final actualIndex = _items.indexWhere((i) => i.id == item.id);
                    _showRestockDialog(actualIndex);
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

  void _showImportDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.info, color: Colors.white),
            SizedBox(width: 8),
            Text('Import feature coming soon'),
          ],
        ),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _generateStockReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.analytics, color: Colors.white),
            SizedBox(width: 8),
            Text('Generating stock report...'),
          ],
        ),
        backgroundColor: Colors.purple,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _filteredItems;

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
          _buildStatsHeader(),
          _buildLowStockAlert(),
          _buildQuickActions(),
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
          _buildCategoryFilter(),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              children: [
                Text(
                  'Inventory Items',
                  style: TextStyle(
                    fontSize: 16,
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
                    '${filteredItems.length}',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filteredItems.isEmpty
                ? Center(
                    child: Column(
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
                      final actualIndex = _items.indexOf(filteredItems[index]);
                      return _buildInventoryCard(filteredItems[index], actualIndex);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showAddEditDialog(),
        tooltip: 'Add Item',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class InventoryItem {
  final String id;
  String name;
  String category;
  double currentStock;
  String unit;
  double lowStockThreshold;
  double costPrice;
  double sellingPrice;
  String supplier;
  DateTime lastRestocked;
  bool isActive;

  InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.currentStock,
    required this.unit,
    required this.lowStockThreshold,
    required this.costPrice,
    required this.sellingPrice,
    required this.supplier,
    required this.lastRestocked,
    this.isActive = true,
  });
}

class StockHistory {
  final DateTime date;
  final String itemId;
  final String type;
  final double quantity;
  final String note;

  StockHistory({
    required this.date,
    required this.itemId,
    required this.type,
    required this.quantity,
    required this.note,
  });
}