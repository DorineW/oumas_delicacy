import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/colors.dart';
import '../../services/auth_service.dart';
import '../../models/order.dart';
import '../../providers/order_provider.dart';
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
    // REMOVED: seedDemoData() call - no longer needed with new flow
    
    // REMOVED: Fake order generation - admin assigns orders now
  }

  @override
  void dispose() {
    _ordersUpdateTimer?.cancel();
    super.dispose();
  }

  Widget _buildActiveOrders() {
    final auth = Provider.of<AuthService>(context, listen: false);
    final riderId = auth.currentUser?.id ?? 'rider_1'; // Use actual rider ID
    
    return Consumer<OrderProvider>(
      builder: (context, orderProvider, child) {
        // UPDATED: Get orders assigned to this specific rider
        final myOrders = orderProvider.activeOrdersForRider(riderId);
        
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
                Text(
                  'Waiting for new orders...',
                  style: TextStyle(
                    color: AppColors.darkText.withOpacity(0.4),
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
            final order = myOrders[index];
            return _OrderCard(
              order: order,
              onCallCustomer: () => _callCustomer(order.deliveryPhone ?? ''),
              onOpenMaps: () => _openMaps(order.deliveryAddress ?? ''),
              onUpdateStatus: (status) => _updateOrderStatus(order.id, status),
            );
          },
        );
      },
    );
  }

  void _updateOrderStatus(String orderId, OrderStatus newStatus) {
    final provider = Provider.of<OrderProvider>(context, listen: false);
    provider.updateStatus(orderId, newStatus);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Order #$orderId status updated'),
        backgroundColor: AppColors.success,
      ),
    );
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

  Widget _buildStatsCard() {
    final auth = Provider.of<AuthService>(context, listen: false);
    final riderId = auth.currentUser?.id ?? 'rider_1'; // Use actual rider ID
    
    return Consumer<OrderProvider>(
      builder: (context, orderProvider, child) {
        final myOrders = orderProvider.ordersForRider(riderId);
        final activeCount = orderProvider.activeOrdersForRider(riderId).length;
        final completedToday = myOrders.where((o) {
          final now = DateTime.now();
          final isToday = o.date.year == now.year &&
              o.date.month == now.month &&
              o.date.day == now.day;
          return isToday && o.status == OrderStatus.delivered;
        }).length;
        final totalEarnings = myOrders
            .where((o) => o.status == OrderStatus.delivered)
            .fold<double>(0, (sum, order) => sum + (order.totalAmount * 0.1)); // 10% commission

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
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Active', activeCount.toString(), Icons.delivery_dining),
                  Container(width: 1, height: 40, color: Colors.white24),
                  _buildStatItem('Today', completedToday.toString(), Icons.check_circle),
                  Container(width: 1, height: 40, color: Colors.white24),
                  _buildStatItem('Earnings', 'Ksh ${totalEarnings.toStringAsFixed(0)}', Icons.attach_money),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);
    final auth = Provider.of<AuthService>(context, listen: false);
    final riderId = auth.currentUser?.id ?? 'rider_1';
    final activeOrders = provider.activeOrdersForRider(riderId); // FIXED: Use activeOrdersForRider
    
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
                    '${activeOrders.length}', // FIXED: Show active orders count
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
  final Order order;
  final VoidCallback onCallCustomer;
  final VoidCallback onOpenMaps;
  final Function(OrderStatus) onUpdateStatus;

  const _OrderCard({
    required this.order,
    required this.onCallCustomer,
    required this.onOpenMaps,
    required this.onUpdateStatus,
  });

  Widget _buildActionButton(OrderStatus status) {
    switch (status) {
      case OrderStatus.assigned:
        return ElevatedButton.icon(
          icon: const Icon(Icons.restaurant, size: 18),
          label: const Text('Pick Up Order'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: AppColors.white),
          onPressed: () => onUpdateStatus(OrderStatus.pickedUp),
        );
      case OrderStatus.pickedUp:
        return ElevatedButton.icon(
          icon: const Icon(Icons.directions_bike, size: 18),
          label: const Text('Start Delivery'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: AppColors.white),
          onPressed: () => onUpdateStatus(OrderStatus.onRoute),
        );
      case OrderStatus.onRoute:
        return ElevatedButton.icon(
          icon: const Icon(Icons.check_circle, size: 18),
          label: const Text('Mark Delivered'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: AppColors.white),
          onPressed: () => onUpdateStatus(OrderStatus.delivered),
        );
      default:
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
            // Order ID and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(order.id, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getStatusColor(order.status)),
                  ),
                  child: Text(_getStatusText(order.status), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _getStatusColor(order.status))),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Customer info
            Row(
              children: [
                Icon(Icons.person, size: 16, color: AppColors.darkText.withOpacity(0.6)),
                const SizedBox(width: 8),
                Text(order.customerName, style: TextStyle(fontWeight: FontWeight.w500)),
                const Spacer(),
                IconButton(icon: Icon(Icons.phone, size: 18, color: AppColors.primary), onPressed: onCallCustomer, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              ],
            ),
            const SizedBox(height: 8),
            
            // Delivery address
            if (order.deliveryAddress != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on, size: 16, color: AppColors.darkText.withOpacity(0.6)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(order.deliveryAddress!, style: TextStyle(color: AppColors.darkText))),
                  IconButton(icon: Icon(Icons.directions, size: 18, color: AppColors.primary), onPressed: onOpenMaps, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                ],
              ),
              const SizedBox(height: 12),
            ],
            
            // Order items
            Text('Order Items:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            ...order.items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('• ${item.quantity}x ${item.title} - Ksh ${(item.price * item.quantity).toStringAsFixed(0)}', style: TextStyle(fontSize: 12, color: AppColors.darkText.withOpacity(0.8))),
            )),
            const SizedBox(height: 8),
            
            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total: Ksh ${order.totalAmount.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            
            _buildActionButton(order.status),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.assigned: return Colors.orange;
      case OrderStatus.pickedUp: return Colors.blue;
      case OrderStatus.onRoute: return Colors.purple;
      case OrderStatus.delivered: return AppColors.success;
      default: return AppColors.darkText;
    }
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.assigned: return 'Assigned';
      case OrderStatus.pickedUp: return 'Picked Up';
      case OrderStatus.onRoute: return 'On Route';
      case OrderStatus.delivered: return 'Delivered';
      default: return status.toString().split('.').last;
    }
  }
}
