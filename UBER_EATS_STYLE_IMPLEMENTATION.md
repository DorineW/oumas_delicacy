# Simplified Uber Eats Style Implementation

## Timeline: Less than 1 week ✅

## The Simple Flow (Like Uber Eats/Bolt Food)

```
1. User opens app
   ↓
2. Select/confirm delivery address
   ↓
3. See list of restaurants/stores that deliver to that address
   ↓
4. Click on a location to see its menu/items
   ↓
5. Add items to cart (all from same location)
   ↓
6. Checkout (system validates location can still deliver)
   ↓
7. Place order
```

## UI Changes Needed

### **1. Home Screen - Location Selection First**

```dart
// home_screen.dart - Modified initState
@override
void initState() {
  super.initState();
  _checkAndSetDeliveryAddress();
}

Future<void> _checkAndSetDeliveryAddress() async {
  final addressProvider = context.read<AddressProvider>();
  
  // Load saved addresses
  await addressProvider.loadAddresses();
  
  // Get current/default address
  final currentAddress = addressProvider.addresses.firstWhere(
    (a) => a.isDefault,
    orElse: () => addressProvider.addresses.isNotEmpty 
      ? addressProvider.addresses.first 
      : null,
  );
  
  if (currentAddress == null) {
    // No address - show address selector
    _showAddressRequiredDialog();
  } else {
    // Have address - load available locations
    await _loadAvailableLocations(currentAddress);
  }
}

Future<void> _loadAvailableLocations(UserAddress address) async {
  final result = await supabase.rpc(
    'get_available_locations_for_address',
    params: {
      'customer_lat': address.latitude,
      'customer_lon': address.longitude,
    },
  );
  
  setState(() {
    availableLocations = (result as List)
      .map((json) => Location.fromJson(json))
      .toList();
  });
  
  if (availableLocations.isEmpty) {
    _showNoLocationsAvailableDialog();
  }
}
```

### **2. New Screen - Location List (Like Uber Eats)**

```dart
// screens/location_selection_screen.dart
class LocationSelectionScreen extends StatelessWidget {
  final UserAddress deliveryAddress;
  final List<Location> availableLocations;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Available Restaurants & Stores'),
        actions: [
          // Show current delivery address with option to change
          IconButton(
            icon: Icon(Icons.location_on),
            onPressed: () => _changeAddress(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Current address banner
          _buildAddressBanner(),
          
          // Tabs for Restaurant / Store
          TabBar(
            tabs: [
              Tab(text: 'Restaurants'),
              Tab(text: 'Stores'),
            ],
          ),
          
          // Location cards
          Expanded(
            child: ListView.builder(
              itemCount: availableLocations.length,
              itemBuilder: (context, index) {
                final location = availableLocations[index];
                return LocationCard(
                  location: location,
                  onTap: () => _openLocation(context, location),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLocationCard(Location location) {
    return Card(
      child: ListTile(
        leading: Icon(
          location.locationType == 'Restaurant' 
            ? Icons.restaurant 
            : Icons.store,
          size: 40,
          color: AppColors.primary,
        ),
        title: Text(location.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.delivery_dining, size: 16),
                SizedBox(width: 4),
                Text('KSh ${location.deliveryFee}'),
                SizedBox(width: 12),
                Icon(Icons.location_on, size: 16),
                SizedBox(width: 4),
                Text('${location.distanceKm} km'),
              ],
            ),
            Text('${location.menuItemCount + location.storeItemCount} items'),
          ],
        ),
        trailing: Icon(Icons.arrow_forward_ios),
        onTap: () => _openLocation(context, location),
      ),
    );
  }
  
  void _openLocation(BuildContext context, Location location) {
    // Navigate to location's menu/store screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LocationMenuScreen(
          location: location,
          deliveryAddress: deliveryAddress,
        ),
      ),
    );
  }
}
```

### **3. Location Menu Screen (Individual Restaurant/Store)**

```dart
// screens/location_menu_screen.dart
class LocationMenuScreen extends StatefulWidget {
  final Location location;
  final UserAddress deliveryAddress;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(location.name),
        actions: [
          // Cart icon
          IconButton(
            icon: Badge(
              label: Text('$cartItemCount'),
              child: Icon(Icons.shopping_cart),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CheckoutScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Location info header
          _buildLocationHeader(),
          
          // Menu/Store items
          Expanded(
            child: _buildItemsList(),
          ),
        ],
      ),
      floatingActionButton: cartItemCount > 0
        ? FloatingActionButton.extended(
            onPressed: () => _goToCheckout(),
            icon: Icon(Icons.shopping_cart),
            label: Text('Checkout (KSh $cartTotal)'),
          )
        : null,
    );
  }
  
  Widget _buildLocationHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            location.name,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.delivery_dining, size: 20),
              SizedBox(width: 4),
              Text('Delivery: KSh ${location.deliveryFee}'),
              SizedBox(width: 16),
              Icon(Icons.location_on, size: 20),
              SizedBox(width: 4),
              Text('${location.distanceKm} km away'),
            ],
          ),
          if (location.minimumOrderAmount > 0)
            Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Min. order: KSh ${location.minimumOrderAmount}',
                style: TextStyle(color: Colors.orange),
              ),
            ),
        ],
      ),
    );
  }
  
  Future<void> _loadItems() async {
    if (location.locationType == 'Restaurant') {
      // Load menu items
      final response = await supabase
        .from('menu_items')
        .select('*')
        .eq('location_id', location.id)
        .eq('available', true);
        
      setState(() {
        items = (response as List)
          .map((json) => MenuItem.fromJson(json))
          .toList();
      });
    } else {
      // Load store items with stock
      final response = await supabase
        .from('StoreItems')
        .select('''
          *,
          ProductInventory!inner(quantity)
        ''')
        .eq('location_id', location.id)
        .eq('available', true)
        .gt('ProductInventory.quantity', 0);
        
      setState(() {
        items = (response as List)
          .map((json) => StoreItem.fromJson(json))
          .toList();
      });
    }
  }
}
```

### **4. Checkout Validation**

```dart
// screens/checkout_screen.dart
Future<void> _validateAndPlaceOrder() async {
  try {
    // Validate location can still deliver
    final validation = await supabase.rpc(
      'validate_order_location',
      params: {
        'location_id_param': cartLocation.id,
        'customer_lat': deliveryAddress.latitude,
        'customer_lon': deliveryAddress.longitude,
      },
    );
    
    if (validation['valid'] == false) {
      // Show error - location can't deliver anymore
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Cannot Deliver'),
          content: Text(validation['error']),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Back to location list
              },
              child: Text('Choose Different Location'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                // Navigate to address change
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => LocationScreen()),
                );
              },
              child: Text('Change Address'),
            ),
          ],
        ),
      );
      return;
    }
    
    // Check minimum order amount
    final minOrder = validation['minimum_order_amount'];
    if (cartSubtotal < minOrder) {
      _showError('Minimum order is KSh $minOrder for this location');
      return;
    }
    
    // Update delivery fee from validation
    final deliveryFee = validation['delivery_fee'];
    
    // Place order
    await _placeOrder(deliveryFee);
    
  } catch (e) {
    _showError('Failed to validate order: $e');
  }
}
```

## Database Migration

Run this in Supabase SQL Editor:

1. ✅ Already done: `fix_locations_updated_at.sql`
2. 🆕 Run now: `SIMPLIFIED_LOCATION_DELIVERY.sql`

## Code Changes Summary

### Minimal Changes Needed:

1. **home_screen.dart** - Add address check at start, load available locations
2. **New: location_selection_screen.dart** - Show restaurants/stores that deliver
3. **New: location_menu_screen.dart** - Show items from selected location
4. **checkout_screen.dart** - Add `validate_order_location()` call before placing order

### What DOESN'T Need to Change:

- ✅ Cart logic stays the same
- ✅ Order placement stays the same (just add validation)
- ✅ Menu item / Store item displays stay the same
- ✅ Payment flow stays the same

## User Experience

### Scenario 1: User in Service Area
```
1. User opens app
2. App detects saved address (-1.3090, 36.8107)
3. Shows: "2 locations deliver to you"
   - Ouma's Kitchen - KSh 80 delivery - 3.5 km
   - Quick Store - KSh 60 delivery - 2.1 km
4. User clicks "Ouma's Kitchen"
5. Sees menu items from that location
6. Adds to cart, checkout works ✅
```

### Scenario 2: User Changes Address (Still in Area)
```
1. User changes address to new location
2. App recalculates: "3 locations deliver to you now"
   - Shows updated list with new delivery fees
3. Cart cleared (different locations available)
4. User selects new location, orders ✅
```

### Scenario 3: User Changes to Non-Delivery Area
```
1. User changes address to far location
2. App shows: "No locations deliver to this address"
3. Shows message: "Try a different address" with change button
4. User changes back or tries new address
5. Cannot checkout until valid address ✅
```

### Scenario 4: User Tries Checkout After Moving (Edge Case)
```
1. User adds items to cart
2. User changes address to non-delivery area
3. User tries to checkout
4. validate_order_location() returns valid=false
5. Shows error: "This location cannot deliver to your new address"
6. Options: "Change Address" or "Choose Different Location"
7. Cart saved, user can fix and retry ✅
```

## Timeline Estimate

- **Day 1**: Run SQL migrations, test functions
- **Day 2**: Create location_selection_screen.dart
- **Day 3**: Modify home_screen.dart flow
- **Day 4**: Add checkout validation
- **Day 5**: Testing and bug fixes
- **Day 6**: Polish UI, add loading states
- **Day 7**: Final testing, deploy

## This Approach is Better Because:

1. ✅ **Familiar UX** - Users understand it (like Uber Eats)
2. ✅ **Quick to implement** - Minimal code changes
3. ✅ **No complex migrations** - Simple database functions
4. ✅ **Clear user flow** - Address → Locations → Menu → Checkout
5. ✅ **Prevents errors** - Validation at checkout
6. ✅ **Scales easily** - Add more locations anytime

Ready to implement! 🚀
