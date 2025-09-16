//lib/screens/cart_screen.dart
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:provider/provider.dart';

import '../models/cart_item.dart';
import '../constants/colors.dart';
import '../providers/cart_provider.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  int _subtotal(List<CartItem> items) =>
      items.fold(0, (sum, item) => sum + item.totalPrice);

  final int deliveryFee = 150;

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final cartItems = cartProvider.items;
    final subtotal = _subtotal(cartItems);
    final grandTotal = subtotal + deliveryFee;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Your Cart',
          style: TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      body: cartItems.isEmpty
          ? Center(
              child: Text(
                'Your cart is empty',
                style: TextStyle(
                  color: AppColors.primary.withAlpha((0.6 * 255).round()),
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(12),
              child: ListView.builder(
                itemCount: cartItems.length,
                itemBuilder: (_, index) {
                  final item = cartItems[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                    child: ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          item.mealImage,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 60,
                            height: 60,
                            color: AppColors.lightGray,
                            child: const Icon(Icons.fastfood),
                          ),
                        ),
                      ),
                      title: Text(
                        item.mealTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppColors.primary,
                        ),
                      ),
                      subtitle: Text(
                        'Quantity: ${item.quantity}',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.primary.withAlpha((0.7 * 255).round()),
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Ksh ${item.totalPrice}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.accent,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            color: Colors.red.shade700,
                            onPressed: () => cartProvider.removeItem(item.id),
                            tooltip: 'Remove item',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
      bottomNavigationBar: cartItems.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((0.1 * 255).round()),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildPriceRow('Subtotal', subtotal),
                  const SizedBox(height: 6),
                  _buildPriceRow('Delivery Fee', deliveryFee),
                  const Divider(height: 24, thickness: 1.5),
                  _buildPriceRow('Grand Total', grandTotal,
                      isBold: true, fontSize: 22),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CheckoutScreen(
                            selectedItems: List<CartItem>.from(cartItems),
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      'Checkout',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPriceRow(String label, int amount,
      {bool isBold = false, double fontSize = 18}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: fontSize,
            color: AppColors.primary,
          ),
        ),
        Text(
          'Ksh $amount',
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: fontSize,
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }
}