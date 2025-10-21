import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/colors.dart';
import '../../services/auth_service.dart';
import '../../models/delivery_order.dart';
import '../../providers/rider_provider.dart';
import 'rider_orders_screen.dart';
import 'rider_profile_screen.dart';
import 'rider_earnings_screen.dart';

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
    // Seed demo data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RiderProvider>(context, listen: false).seedDemoData();
    });

    // Simulate new orders arriving
    _ordersUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _simulateNewOrder();
    });
  }

  @override
  void dispose() {
    _ordersUpdateTimer?.cancel();
    super.dispose();
  }

  void _simulateNewOrder() {
    final provider = Provider.of<RiderProvider>(context, listen: false);
    if (provider.activeOrders.length < 3) {
      final newOrder = DeliveryOrder(
        id: 'ORD-${DateTime.now().millisecondsSinceEpoch}',
        customerName: 'New Customer',
        customerPhone: '+254700000000',
        customerAddress: 'New Address',
        deliveryAddress: 'New Delivery Location',
        amount: 850.00,
        orderTime: DateTime.now(),
        status: OrderStatus.assigned,
        items: [
          OrderItem('UGALI NYAMA', 1, 210.0),
          OrderItem('CHAPATI', 3, 60.0),
        ],
        specialInstructions: 'New order',
        paymentMethod: 'M-Pesa',
        distance: 2.8,
        estimatedTime: 18,
      );
      provider.addOrder(newOrder);
    }
  }

  void _updateOrderStatus(String orderId, OrderStatus newStatus) {
    final provider = Provider.of<RiderProvider>(context, listen: false);
    provider.updateOrderStatus(orderId, newStatus);
    
    if (newStatus == OrderStatus.delivered) {
      Timer(const Duration(seconds: 2), () {
        provider.removeOrder(orderId);
      });
    }
  }

  void _callCustomer(String phoneNumber) async {
    final url = 'tel:$phoneNumber';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  void _openMaps(String address) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  Widget _buildActiveOrders() {
    final provider = Provider.of<RiderProvider>(context);
    final activeOrders = provider.activeOrders;

    if (activeOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.delivery_dining,
              size: 80,
              color: AppColors.primary.withOpacity(0.3),
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
            Text(
              'New orders will appear here automatically',
              style: TextStyle(
                color: AppColors.darkText.withOpacity(0.4),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: activeOrders.length,
      itemBuilder: (context, index) {
        final order = activeOrders[index];
        return _OrderCard(
          order: order,
          onCallCustomer: () => _callCustomer(order.customerPhone),
          onOpenMaps: () => _openMaps(order.deliveryAddress),
          onUpdateStatus: (newStatus) => _updateOrderStatus(order.id, newStatus),
        );
      },
    );
  }

  Widget _buildStatsCard() {
    final provider = Provider.of<RiderProvider>(context);
    
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
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today\'s Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${provider.totalDeliveriesToday} Deliveries',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.white.withOpacity(0.9),
                  ),
                ),
                Text(
                  'Ksh ${provider.todayEarnings.toStringAsFixed(0)} Earnings',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.directions_bike,
              size: 30,
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RiderProvider>(context);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Ouma's Delicacy - Rider"),
        backgroundColor: AppColors.primary,
        elevation: 4,
        iconTheme: const IconThemeData(color: AppColors.white),
        titleTextStyle: const TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await Provider.of<AuthService>(context, listen: false).logout();
              if (!mounted) return;
              Navigator.of(context).pushNamedAndRemoveUntil(
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Text(
                  'Active Deliveries',
                  style: TextStyle(
                    fontSize: 18,
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
                    '${provider.activeOrders.length}',
                    style: const TextStyle(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
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
              MaterialPageRoute(builder: (_) => const RiderEarningsScreen()),
            );
          } else if (index == 3) {
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
            icon: Icon(Icons.attach_money),
            label: 'Earnings',
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

class _OrderCard extends StatelessWidget {
  final DeliveryOrder order;
  final VoidCallback onCallCustomer;
  final VoidCallback onOpenMaps;
  final Function(OrderStatus) onUpdateStatus;

  const _OrderCard({
    required this.order,
    required this.onCallCustomer,
    required this.onOpenMaps,
    required this.onUpdateStatus,
  });

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.assigned:
        return Colors.orange;
      case OrderStatus.pickedUp:
        return Colors.blue;
      case OrderStatus.onRoute:
        return Colors.purple;
      case OrderStatus.delivered:
        return AppColors.success;
    }
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.assigned:
        return 'Assigned';
      case OrderStatus.pickedUp:
        return 'Picked Up';
      case OrderStatus.onRoute:
        return 'On Route';
      case OrderStatus.delivered:
        return 'Delivered';
    }
  }

  Widget _buildActionButton(OrderStatus status) {
    switch (status) {
      case OrderStatus.assigned:
        return ElevatedButton.icon(
          icon: const Icon(Icons.restaurant, size: 18),
          label: const Text('Pick Up Order'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: AppColors.white,
          ),
          onPressed: () => onUpdateStatus(OrderStatus.pickedUp),
        );
      case OrderStatus.pickedUp:
        return ElevatedButton.icon(
          icon: const Icon(Icons.directions_bike, size: 18),
          label: const Text('Start Delivery'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: AppColors.white,
          ),
          onPressed: () => onUpdateStatus(OrderStatus.onRoute),
        );
      case OrderStatus.onRoute:
        return ElevatedButton.icon(
          icon: const Icon(Icons.check_circle, size: 18),
          label: const Text('Mark Delivered'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: AppColors.white,
          ),
          onPressed: () => onUpdateStatus(OrderStatus.delivered),
        );
      case OrderStatus.delivered:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  order.id,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getStatusColor(order.status)),
                  ),
                  child: Text(
                    _getStatusText(order.status),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(order.status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.person, size: 16, color: AppColors.darkText.withOpacity(0.6)),
                const SizedBox(width: 8),
                Text(
                  order.customerName,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppColors.darkText,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.phone, size: 18, color: AppColors.primary),
                  onPressed: onCallCustomer,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on, size: 16, color: AppColors.darkText.withOpacity(0.6)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.deliveryAddress,
                        style: TextStyle(
                          color: AppColors.darkText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 14, color: AppColors.darkText.withOpacity(0.5)),
                          const SizedBox(width: 4),
                          Text(
                            '${order.estimatedTime} min • ${order.distance} km',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.darkText.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.directions, size: 18, color: AppColors.primary),
                  onPressed: onOpenMaps,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Order Items:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            ...order.items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '• ${item.quantity}x ${item.name} - Ksh ${(item.price * item.quantity).toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.darkText.withOpacity(0.8),
                ),
              ),
            )),
            const SizedBox(height: 8),
            if (order.specialInstructions.isNotEmpty) ...[
              Text(
                'Instructions: ${order.specialInstructions}',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: AppColors.darkText.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Payment: ${order.paymentMethod}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.darkText.withOpacity(0.7),
                  ),
                ),
                Text(
                  'Total: Ksh ${order.amount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildActionButton(order.status),
          ],
        ),
      ),
    );
  }
}
