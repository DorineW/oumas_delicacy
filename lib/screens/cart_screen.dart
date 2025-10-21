//lib/screens/cart_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cart_item.dart';
import '../constants/colors.dart';
import '../providers/cart_provider.dart';
import 'checkout_screen.dart';
import 'home_screen.dart'; // add near other imports

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  int _subtotal(List<CartItem> items) => items.fold(0, (s, i) => s + i.totalPrice);

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final items = cartProvider.items;

    final subtotal = _subtotal(items);
    const int deliveryFee = 150;
    final grandTotal = subtotal + (items.isEmpty ? 0 : deliveryFee);

    // approximate bottom bar height to avoid content being hidden / overflowing
    final double bottomBarHeight = items.isEmpty ? 0.0 : 160.0;

    return Scaffold(
      // red header with back button that returns to previous (home) screen
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Replace navigation stack with HomeScreen to avoid landing on a blank route
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
            );
          },
          color: Colors.white,
        ),
        title: const Text('Cart', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
        elevation: 2,
      ),
      body: items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 72, color: AppColors.lightGray),
                  const SizedBox(height: 12),
                  Text('Your cart is empty', style: TextStyle(color: AppColors.lightGray, fontSize: 16)),
                ],
              ),
            )
          : ListView.separated(
              // make room at the bottom so last item won't be overlapped by the bottom bar
              padding: EdgeInsets.fromLTRB(12, 12, 12, bottomBarHeight + MediaQuery.of(context).padding.bottom),
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  leading: SizedBox(
                    width: 64,
                    height: 64,
                    child: item.mealImage.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(item.mealImage, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.fastfood)),
                          )
                        : const Icon(Icons.fastfood),
                  ),
                  title: Text(item.mealTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text('Ksh ${item.price}  •  Qty: ${item.quantity}'),
                  trailing: 
                    SizedBox(
                      width: 72, // give trailing a fixed, small width so it can't collapse and overflow vertically
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              'Ksh ${item.totalPrice}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent, fontSize: 13),
                            ),
                          ),
                          const SizedBox(height: 2),
                          // compact delete control: constrained icon size + zero padding
                          Flexible(
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              iconSize: 18,
                              icon: const Icon(Icons.delete),
                              color: Colors.red.shade700,
                              onPressed: () => cartProvider.removeItem(item.id),
                              tooltip: 'Remove item',
                            ),
                          ),
                        ],
                      ),
                    ),
                );
              },
              separatorBuilder: (_, __) => const Divider(height: 12),
              itemCount: items.length,
            ),
      bottomNavigationBar: items.isEmpty
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, -2))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Text('Subtotal'),
                        const Spacer(),
                        Text('Ksh $subtotal', style: TextStyle(color: AppColors.darkText)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Text('Delivery'),
                        const Spacer(),
                        Text(items.isEmpty ? 'Ksh 0' : 'Ksh $deliveryFee', style: TextStyle(color: AppColors.darkText)),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      children: [
                        Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        const Spacer(),
                        Text('Ksh $grandTotal', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent, fontSize: 18)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        minimumSize: const Size.fromHeight(44),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => CheckoutScreen(selectedItems: items)),
                        );
                      },
                      child: const Text('Checkout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}