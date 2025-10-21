import 'package:flutter/foundation.dart';
import '../models/delivery_order.dart';

class RiderProvider with ChangeNotifier {
  final List<DeliveryOrder> _orders = [];
  bool _isDemoSeeded = false;

  List<DeliveryOrder> get orders => List.unmodifiable(_orders);

  List<DeliveryOrder> get activeOrders => 
    _orders.where((o) => o.status != OrderStatus.delivered).toList();

  List<DeliveryOrder> get completedOrders => 
    _orders.where((o) => o.status == OrderStatus.delivered).toList();

  List<DeliveryOrder> get todayOrders => 
    _orders.where((o) => 
      o.orderTime.day == DateTime.now().day &&
      o.orderTime.month == DateTime.now().month &&
      o.orderTime.year == DateTime.now().year
    ).toList();

  int get totalDeliveriesToday => todayOrders.where((o) => 
    o.status == OrderStatus.delivered).length;

  double get todayEarnings => todayOrders
    .where((o) => o.status == OrderStatus.delivered)
    .fold(0.0, (sum, order) => sum + (order.amount * 0.1)); // 10% commission

  void seedDemoData() {
    if (_isDemoSeeded) return;

    _orders.clear();
    _orders.addAll([
      DeliveryOrder(
        id: 'ORD-1001',
        customerName: 'John Kamau',
        customerPhone: '+254712345678',
        customerAddress: '123 Main Street, Nairobi',
        deliveryAddress: '456 Business Plaza, 3rd Floor, Room 304',
        amount: 1250.00,
        orderTime: DateTime.now().subtract(const Duration(minutes: 15)),
        status: OrderStatus.assigned,
        items: [
          OrderItem('UGALI NYAMA CHOMA', 2, 210.0),
          OrderItem('SODA 500ml', 2, 70.0),
        ],
        specialInstructions: 'Call when arriving at gate',
        paymentMethod: 'M-Pesa',
        distance: 2.5,
        estimatedTime: 20,
      ),
      DeliveryOrder(
        id: 'ORD-1002',
        customerName: 'Mary Wanjiku',
        customerPhone: '+254723456789',
        customerAddress: '789 Kibera Drive',
        deliveryAddress: 'Westlands Towers, 5th Floor',
        amount: 890.00,
        orderTime: DateTime.now().subtract(const Duration(minutes: 5)),
        status: OrderStatus.pickedUp,
        items: [
          OrderItem('PILAU LIVER', 1, 230.0),
          OrderItem('CHAPATI PLAIN', 4, 20.0),
          OrderItem('JUICE 300ml', 1, 100.0),
        ],
        specialInstructions: 'No contact delivery - leave at door',
        paymentMethod: 'Cash',
        distance: 4.2,
        estimatedTime: 25,
      ),
      DeliveryOrder(
        id: 'ORD-1003',
        customerName: 'David Ochieng',
        customerPhone: '+254734567890',
        customerAddress: '321 Karen Road',
        deliveryAddress: 'Karen Shopping Center',
        amount: 1560.00,
        orderTime: DateTime.now().subtract(const Duration(hours: 2)),
        status: OrderStatus.delivered,
        items: [
          OrderItem('MATOKE BEEF', 3, 230.0),
          OrderItem('SAMOSA', 6, 20.0),
          OrderItem('WATER 500ml', 3, 50.0),
        ],
        specialInstructions: 'Gate code: 1234',
        paymentMethod: 'M-Pesa',
        distance: 3.8,
        estimatedTime: 18,
      ),
      DeliveryOrder(
        id: 'ORD-1004',
        customerName: 'Sarah Auma',
        customerPhone: '+254745678901',
        customerAddress: '654 Lavington Green',
        deliveryAddress: 'Lavington Apartments, Block B',
        amount: 720.00,
        orderTime: DateTime.now().subtract(const Duration(hours: 1)),
        status: OrderStatus.onRoute,
        items: [
          OrderItem('UGALI SAMAKI', 2, 300.0),
          OrderItem('SODA 500ml', 2, 70.0),
        ],
        specialInstructions: 'Call upon arrival',
        paymentMethod: 'Cash',
        distance: 5.1,
        estimatedTime: 30,
      ),
      DeliveryOrder(
        id: 'ORD-1005',
        customerName: 'Peter Mwangi',
        customerPhone: '+254756789012',
        customerAddress: '987 Eastleigh Estate',
        deliveryAddress: 'Eastleigh Mall, Ground Floor',
        amount: 980.00,
        orderTime: DateTime.now().subtract(const Duration(hours: 3)),
        status: OrderStatus.delivered,
        items: [
          OrderItem('BEEF BURGER', 2, 350.0),
          OrderItem('CHIPS', 2, 140.0),
        ],
        specialInstructions: '',
        paymentMethod: 'M-Pesa',
        distance: 3.2,
        estimatedTime: 22,
      ),
    ]);

    _isDemoSeeded = true;
    notifyListeners();
  }

  void updateOrderStatus(String orderId, OrderStatus newStatus) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      _orders[index] = _orders[index].copyWith(status: newStatus);
      notifyListeners();
    }
  }

  void addOrder(DeliveryOrder order) {
    _orders.insert(0, order);
    notifyListeners();
  }

  void removeOrder(String orderId) {
    _orders.removeWhere((o) => o.id == orderId);
    notifyListeners();
  }
}
