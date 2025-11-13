//lib/screens/cart_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/cart_item.dart';
import '../constants/colors.dart';
import '../providers/cart_provider.dart';
import '../providers/menu_provider.dart'; // ADDED: Import menu provider
import 'checkout_screen.dart';
// Removed delivery fee from cart; no location dependency needed here

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  int _subtotal(List<CartItem> items) => items.fold(0, (s, i) => s + i.totalPrice);

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final menuProvider = context.watch<MenuProvider>();
    final items = cart.items;

    // FIXED: Check for unavailable items properly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Ensure the BuildContext is still valid before mutating providers / showing UI
      if (!context.mounted) return;

      final unavailableItems = <CartItem>[];
      
      for (final item in items) {
        if (!menuProvider.isItemAvailable(item.mealTitle)) {
          unavailableItems.add(item);
        }
      }

      if (unavailableItems.isNotEmpty) {
        // Remove unavailable items
        for (final item in unavailableItems) {
          cart.removeItem(item.id);
        }

        // Show notification
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Items removed from cart',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...unavailableItems.map((item) => Padding(
                  padding: const EdgeInsets.only(left: 32, top: 2),
                  child: Text(
                    '• ${item.mealTitle} (out of stock)',
                    style: const TextStyle(fontSize: 12),
                  ),
                )),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    });

    final subtotal = _subtotal(items);
    final grandTotal = subtotal; // Cart shows subtotal only; delivery fee calculated at checkout
    
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        // Let parent HomeScreen handle navigation
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('My Cart'),
          backgroundColor: AppColors.primary,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.white),
          titleTextStyle: const TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold),
          automaticallyImplyLeading: false,
          actions: items.isNotEmpty
              ? [
                  TextButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Clear Cart'),
                          content: const Text('Are you sure you want to remove all items?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                cart.clearCart();
                                Navigator.pop(ctx);
                              },
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              child: const Text('Clear All'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text(
                      'Clear All',
                      style: TextStyle(color: AppColors.white),
                    ),
                  ),
                ]
              : null,
        ),
        // FIXED: Wrap in SafeArea and use LayoutBuilder pattern
        body: items.isEmpty
            ? _buildEmptyState()
            : SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(16, isLandscape ? 12 : 16, 16, 16),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 16,
                        ),
                        child: Column(
                          children: [
                            // Summary Card
                            Container(
                              margin: EdgeInsets.only(bottom: isLandscape ? 12 : 16),
                              padding: EdgeInsets.all(isLandscape ? 14 : 16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.primary,
                                    AppColors.primary.withOpacity(0.8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Cart Summary',
                                        style: TextStyle(
                                          color: AppColors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppColors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '${items.length} ${items.length == 1 ? 'item' : 'items'}',
                                          style: const TextStyle(
                                            color: AppColors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _buildSummaryRow('Subtotal', 'Ksh $subtotal'),
                                  const SizedBox(height: 8),
                                  // Delivery fee removed from cart summary
                                  const Divider(color: AppColors.white, height: 24, thickness: 0.5),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Total',
                                        style: TextStyle(
                                          color: AppColors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Ksh $grandTotal',
                                        style: const TextStyle(
                                          color: AppColors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Items Title
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 0),
                              child: Row(
                                children: [
                                  Text(
                                    'Items in Cart',
                                    style: TextStyle(
                                      fontSize: isLandscape ? 16 : 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.darkText,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${items.length}',
                                    style: TextStyle(
                                      fontSize: isLandscape ? 14 : 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: isLandscape ? 10 : 12),

                            // Cart Items List
                            ...items.map((item) => _CartItemCard(
                              item: item,
                              onRemove: () => cart.removeItem(item.id),
                              onIncrement: () => HapticFeedback.lightImpact(),
                              onDecrement: () => HapticFeedback.lightImpact(),
                            )),
                            
                            // ADDED: Bottom spacing for checkout button
                            SizedBox(height: isLandscape ? 80 : 100),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
        bottomNavigationBar: items.isEmpty
            ? null
            : SafeArea(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CheckoutScreen(selectedItems: items),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Proceed to Checkout',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '• Ksh $grandTotal',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.white.withOpacity(0.9),
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 100,
              color: AppColors.darkText.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'Your Cart is Empty',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add some delicious meals to get started!',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.darkText.withOpacity(0.4),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Cart Item Card Widget
class _CartItemCard extends StatelessWidget {
  final CartItem item;
  final VoidCallback onRemove;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _CartItemCard({
    required this.item,
    required this.onRemove,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Image
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              image: item.mealImage.isNotEmpty
                  ? DecorationImage(
                      image: AssetImage(item.mealImage),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: item.mealImage.isEmpty
                ? const Icon(Icons.fastfood, size: 40, color: AppColors.primary)
                : null,
          ),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.mealTitle,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkText,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        iconSize: 20,
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          onRemove();
                        },
                        icon: const Icon(Icons.delete_outline),
                        color: Colors.red,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ksh ${item.price} each',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.darkText.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Quantity badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.shopping_bag_outlined,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Qty: ${item.quantity}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Total price
                      Text(
                        'Ksh ${item.totalPrice}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}