import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // ADDED: Import for kDebugMode
import 'package:provider/provider.dart';

import '../../constants/colors.dart';
import '../../services/auth_service.dart';
import '../../models/order.dart'; // ADDED: Import Order model
import '../../providers/rider_provider.dart'; // ADDED: Import RiderProvider
import '../../providers/favorites_provider.dart'; // ADDED
import '../../providers/cart_provider.dart'; // ADDED
import 'rider_orders_screen.dart';
import 'rider_profile_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/phone_utils.dart';

class RiderDashboardScreen extends StatefulWidget {
  const RiderDashboardScreen({super.key});

  @override
  State<RiderDashboardScreen> createState() => _RiderDashboardScreenState();
}

class _RiderDashboardScreenState extends State<RiderDashboardScreen> {
  int _currentIndex = 0;
  Timer? _ordersUpdateTimer;

  @override
  void initState() {
    super.initState();
    
    // Load orders for this rider when dashboard opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthService>(context, listen: false);
      final riderId = auth.currentUser?.id;
      
      if (riderId != null) {
        debugPrint('🚴 Loading orders for rider: $riderId');
        final riderProvider = Provider.of<RiderProvider>(context, listen: false);
        riderProvider.loadOrdersForRider(riderId);
      }
    });
    
    // Start auto-refresh for orders every 30 seconds
    _ordersUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        final auth = Provider.of<AuthService>(context, listen: false);
        final riderId = auth.currentUser?.id;
        
        if (riderId != null) {
          final riderProvider = Provider.of<RiderProvider>(context, listen: false);
          riderProvider.refreshOrders(riderId);
        }
      }
    });
  }

  @override
  void dispose() {
    _ordersUpdateTimer?.cancel();
    super.dispose();
  }

  Widget _buildActiveOrders() {
    final auth = Provider.of<AuthService>(context, listen: false);
    final riderId = auth.currentUser?.id ?? '';
    final riderProvider = Provider.of<RiderProvider>(context);
    
    debugPrint('🚴 Rider Dashboard - Rider ID: $riderId');
    debugPrint('🚴 Total orders for rider: ${riderProvider.orders.length}');
    
    // Show loading indicator
    if (riderProvider.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading orders...'),
          ],
        ),
      );
    }
    
    // Show error if any
    if (riderProvider.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Unable to Load Orders',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                riderProvider.error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.darkText.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => riderProvider.refreshOrders(riderId),
                icon: const Icon(Icons.refresh),
                label: const Text('Try Refreshing'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // UPDATED: Get active orders (out for delivery)
    final myOrders = riderProvider.activeOrdersForRider(riderId);

    debugPrint('🚴 My active orders count: ${myOrders.length}');

    if (myOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.delivery_dining,
              size: 80,
              color: AppColors.darkText.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No Active Deliveries',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  Text(
                    'New delivery assignments will appear here',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.darkText.withOpacity(0.4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // ADDED: Debug info in development
                  if (kDebugMode)
                    Text(
                      'Rider ID: $riderId',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.darkText.withOpacity(0.3),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: myOrders.length,
      itemBuilder: (context, index) {
        return _OrderCard(order: myOrders[index]);
      },
    );
  }

  Widget _buildStatsCard() {
    final auth = Provider.of<AuthService>(context, listen: false);
    final riderId = auth.currentUser?.id ?? '';
    final riderProvider = Provider.of<RiderProvider>(context);
    
    final myOrders = riderProvider.ordersForRider(riderId);
    final activeCount = riderProvider.activeOrdersForRider(riderId).length;
    final completedCount = riderProvider.completedOrdersForRider(riderId).length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Active', activeCount.toString(), Icons.delivery_dining),
          _buildStatItem('Completed', completedCount.toString(), Icons.check_circle),
          _buildStatItem('Total', myOrders.length.toString(), Icons.receipt),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 32, color: Colors.white),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Ouma's Delicacy - Rider"),
        backgroundColor: AppColors.primary,
        elevation: 4,
        iconTheme: const IconThemeData(color: AppColors.white),
        titleTextStyle: const TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold),
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Orders',
            onPressed: () {
              final auth = Provider.of<AuthService>(context, listen: false);
              final riderId = auth.currentUser?.id;
              if (riderId != null) {
                final riderProvider = Provider.of<RiderProvider>(context, listen: false);
                riderProvider.refreshOrders(riderId);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              // Clear all provider data
              final favoritesProvider = Provider.of<FavoritesProvider>(context, listen: false);
              final cartProvider = Provider.of<CartProvider>(context, listen: false);
              favoritesProvider.clearFavorites();
              cartProvider.clearCart();
              
              final navigator = Navigator.of(context); // ADDED: Store navigator
              await Provider.of<AuthService>(context, listen: false).logout();
              if (!mounted) return; // FIXED: Check mounted before navigation
              navigator.pushNamedAndRemoveUntil(
                '/login',
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatsCard(),
          Expanded(child: _buildActiveOrders()),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RiderOrdersScreen()),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RiderProfileScreen()),
            );
          } else {
            setState(() {
              _currentIndex = index;
            });
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.darkText.withOpacity(0.6),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'All Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ADDED: Order card for rider
class _OrderCard extends StatelessWidget {
  final Order order;

  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    order.customerName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.1), // UPDATED
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.indigo), // UPDATED
                  ),
                  child: const Text(
                    'OUT FOR DELIVERY', // UPDATED
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo, // UPDATED
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // ADDED: Customer phone with call button
            if (order.deliveryPhone != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.phone, size: 16, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Customer Contact',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkText.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            PhoneUtils.toLocalDisplay(order.deliveryPhone!),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _callCustomer(context, order.deliveryPhone!),
                      icon: const Icon(Icons.call, size: 16),
                      label: const Text('Call'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            
            if (order.deliveryAddress != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    order.deliveryAddress!['address']?.toString() ?? 'N/A')), // FIXED: Extract address
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (order.deliveryPhone != null) ...[
              Row(
                children: [
                  const Icon(Icons.phone, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(PhoneUtils.toLocalDisplay(order.deliveryPhone!)),
                ],
              ),
              const SizedBox(height: 8),
            ],
            const Divider(),
            Text(
              'Items: ${order.items.map((i) => '${i.title} x${i.quantity}').join(', ')}',
              style: TextStyle(
                color: AppColors.darkText.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total: Ksh ${order.totalAmount}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.primary,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _markAsDelivered(context, order),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Mark as Delivered'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ADDED: Call customer method
  void _callCustomer(BuildContext context, String phoneNumber) {
    // REMOVED: unused cleanNumber variable - we're just showing UI feedback
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.phone, color: AppColors.success, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Call Customer', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Call this number?'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.phone, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    PhoneUtils.toLocalDisplay(phoneNumber),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _launchDialer(context, phoneNumber);
            },
            icon: const Icon(Icons.call, size: 18),
            label: const Text('Call Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchDialer(BuildContext context, String phoneNumber) async {
    final dialable = PhoneUtils.normalizeKenyan(phoneNumber);
    final uri = Uri(scheme: 'tel', path: dialable);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open phone dialer.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open dialer: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _markAsDelivered(BuildContext context, Order order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delivery'),
        content: Text('Mark order #${order.id} as delivered?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Update using RiderProvider
              await Provider.of<RiderProvider>(context, listen: false)
                  .updateOrderStatus(order.id, OrderStatus.delivered);
              
              if (context.mounted) {
                Navigator.pop(context);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Order marked as delivered',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.all(16),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
