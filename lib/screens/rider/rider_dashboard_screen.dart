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
import '../../utils/responsive_helper.dart';

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
    final provider = Provider.of<OrderProvider>(context);
    final auth = Provider.of<AuthService>(context, listen: false);
    final riderId = auth.currentUser?.id ?? 'rider_1'; // Get current rider ID
    
    // CHANGED: Use activeOrdersForRider instead of ordersForRider
    final activeOrders = provider.activeOrdersForRider(riderId);
    final isLandscape = ResponsiveHelper.isLandscape(context);

    if (activeOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delivery_dining, size: 80, color: AppColors.primary.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('No Active Deliveries', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkText.withOpacity(0.5))),
            const SizedBox(height: 8),
            Text('Orders assigned to you will appear here', style: TextStyle(color: AppColors.darkText.withOpacity(0.4)), textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(isLandscape ? 12 : 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              children: activeOrders.map((order) => _OrderCard(
                order: order,
                onCallCustomer: () => _callCustomer(order.deliveryPhone ?? order.customerName),
                onOpenMaps: () => _openMaps(order.deliveryAddress ?? ''),
                onUpdateStatus: (newStatus) => _updateOrderStatus(order.id, newStatus),
              )).toList(),
            ),
          ),
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
    final provider = Provider.of<OrderProvider>(context);
    final auth = Provider.of<AuthService>(context, listen: false);
    final riderId = auth.currentUser?.id ?? 'rider_1';
    
    // FIXED: Use ordersForRider to get ALL orders, then filter
    final allRiderOrders = provider.ordersForRider(riderId);
    final deliveredToday = allRiderOrders.where((o) => 
      o.status == OrderStatus.delivered &&
      o.date.day == DateTime.now().day
    ).length;
    final earningsToday = allRiderOrders.where((o) => 
      o.status == OrderStatus.delivered &&
      o.date.day == DateTime.now().day
    ).fold<double>(0, (sum, o) => sum + 150.0); // Flat 150 per delivery
    
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
                  '$deliveredToday Deliveries',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.white.withOpacity(0.9),
                  ),
                ),
                Text(
                  'Ksh ${earningsToday.toStringAsFixed(0)} Earnings',
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
