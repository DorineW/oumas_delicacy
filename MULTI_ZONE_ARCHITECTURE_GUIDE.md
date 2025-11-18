# Multi-Zone Architecture Solution

## Problem Summary
The system had several critical issues with multi-location support:
1. ❌ Customers could see items from ALL locations
2. ❌ Admins could manage ALL locations
3. ❌ Riders could be assigned to ANY order
4. ❌ Restaurant menu items incorrectly used inventory
5. ❌ No zone-based delivery calculation

## Solution Architecture

### **1. Location-Based User Assignment**

#### **Customers** (`users.serving_location_id`)
- Each customer is assigned to ONE serving location
- They can ONLY see menu/store items from their location
- Assignment happens automatically when they add their first address
- Uses `find_serving_location()` to find closest location within delivery radius

```
Customer at (-1.3090, 36.8107)
    ↓
Find closest active location within delivery_radius_km
    ↓
Set users.serving_location_id = location.id
    ↓
Customer now sees ONLY items from that location
```

#### **Admins** (`users.managed_location_ids[]`)
- Admins can manage MULTIPLE locations (array field)
- They can ONLY see/edit data for their managed locations
- Example: Admin manages [location_A, location_B]
  - Can see menu items WHERE location_id IN (location_A, location_B)
  - Can see inventory WHERE location_id IN (location_A, location_B)
  - Can see orders WHERE fulfillment_location_id IN (location_A, location_B)

#### **Riders** (`riders.assigned_location_id`)
- Each rider is assigned to ONE location/zone
- They can ONLY be assigned orders from their location
- Order assignment query: `WHERE rider.assigned_location_id = order.fulfillment_location_id`

### **2. Menu Items vs Store Items**

#### **Menu Items (Restaurant Food)**
- `menu_items.location_id` - Required field
- **NO INVENTORY TRACKING**
- Made-to-order items (prepared fresh)
- Use `available = false` to mark as unavailable
- Example: "Chicken Biryani" - cooked when ordered

#### **Store Items (Retail Products)**
- `StoreItems.location_id` - Required field
- **USES ProductInventory table**
- Physical stock tracked per location
- `ProductInventory.location_id` + `product_id` = stock level
- Example: "Coca Cola 500ml" - 50 units in stock at Location A

```sql
-- Restaurant item (no inventory)
INSERT INTO menu_items (name, location_id, available) 
VALUES ('Ugali', 'location_A_id', true);

-- Store item (with inventory)
INSERT INTO StoreItems (name, location_id, product_id) 
VALUES ('Bread', 'location_A_id', 'product_id');

INSERT INTO ProductInventory (product_id, location_id, quantity) 
VALUES ('product_id', 'location_A_id', 20);
```

### **3. "Not in Your Area" Feature**

When customer tries to browse without a valid serving location:

```dart
// In Flutter app
final servingLocation = await locationProvider.getServingLocation(userAddress);

if (servingLocation == null) {
  // Show "Not in Service Area" screen
  showDialog(
    context: context,
    builder: (_) => NotInServiceAreaDialog(
      message: "We don't serve your area yet",
      suggestNearestLocation: true,
      onSelectNewAddress: () {
        // Navigate to address picker
        // When they pick new address, check again
      },
    ),
  );
} else {
  // Load menu/store items for their serving location
  await menuProvider.loadMenuItems(servingLocation.id);
  await storeProvider.loadStoreItems(servingLocation.id);
}
```

### **4. Delivery Calculation Per Location**

Each location has its own delivery settings:
- `delivery_radius_km` - How far they deliver (default 10km)
- `delivery_base_fee` - Starting fee (e.g., KSh 50)
- `delivery_rate_per_km` - Per-kilometer charge (e.g., KSh 20/km)
- `minimum_order_amount` - Minimum order to deliver
- `free_delivery_threshold` - Free delivery above this amount

```sql
-- Calculate delivery for customer
SELECT calculate_delivery_fee(
  'location_id', 
  customer_lat, 
  customer_lon
) AS fee;

-- Returns: base_fee + (distance_km * rate_per_km)
-- Example: 50 + (3.5 * 20) = KSh 120
```

### **5. Admin Dashboard - Location Filtering**

Each admin sees ONLY their managed locations' data:

```dart
// Load admin's managed locations
final user = await supabase
  .from('users')
  .select('managed_location_ids')
  .eq('auth_id', currentUserId)
  .single();

final managedLocations = user['managed_location_ids'] as List;

// Load menu items for managed locations only
final menuItems = await supabase
  .from('menu_items')
  .select('*')
  .in_('location_id', managedLocations);

// Load inventory for managed locations only
final inventory = await supabase
  .from('ProductInventory')
  .select('*, products(*), locations(*)')
  .in_('location_id', managedLocations);
```

### **6. Order Placement Flow**

```
Customer places order
    ↓
1. Check customer.serving_location_id exists
    ↓ (if null, show "Please add delivery address first")
2. Verify all cart items belong to customer.serving_location_id
    ↓ (prevent cross-location ordering)
3. Calculate delivery_fee using location settings
    ↓
4. Create order with fulfillment_location_id = customer.serving_location_id
    ↓
5. Deduct inventory for store items at that location
    ↓ (menu items don't deduct inventory)
6. Find available rider WHERE assigned_location_id = order.fulfillment_location_id
    ↓
7. Assign order to rider from same location
```

### **7. Database Views for Easy Querying**

#### **customer_available_menu_items**
```sql
-- Shows only available menu items with location info
SELECT * FROM customer_available_menu_items
WHERE location_id = (
  SELECT serving_location_id FROM users WHERE auth_id = current_user_id
);
```

#### **customer_available_store_items**
```sql
-- Shows only in-stock store items with location info
SELECT * FROM customer_available_store_items
WHERE location_id = (
  SELECT serving_location_id FROM users WHERE auth_id = current_user_id
);
```

#### **admin_location_access**
```sql
-- Shows which locations admin can manage with stats
SELECT * FROM admin_location_access
WHERE admin_id = current_user_id;
```

## Implementation Steps

### **Step 1: Run Migration**
Run `MULTI_ZONE_ARCHITECTURE_FIX.sql` in Supabase SQL Editor

### **Step 2: Assign Locations to Users**

```sql
-- Assign serving location to existing customers
UPDATE users u
SET serving_location_id = find_serving_location(
  (SELECT latitude FROM "UserAddresses" WHERE user_auth_id = u.auth_id ORDER BY is_default DESC LIMIT 1),
  (SELECT longitude FROM "UserAddresses" WHERE user_auth_id = u.auth_id ORDER BY is_default DESC LIMIT 1)
)
WHERE role = 'customer' AND serving_location_id IS NULL;

-- Assign managed locations to admins
UPDATE users
SET managed_location_ids = ARRAY(SELECT id FROM locations WHERE is_active = true)
WHERE role = 'admin';
-- Or assign specific locations per admin

-- Assign location to riders
UPDATE riders
SET assigned_location_id = (SELECT id FROM locations LIMIT 1)
WHERE assigned_location_id IS NULL;
```

### **Step 3: Update Flutter Code**

#### **MenuProvider** - Filter by location
```dart
Future<void> loadMenuItems() async {
  final user = await _getUserServingLocation();
  
  if (user['serving_location_id'] == null) {
    _showNotInServiceArea();
    return;
  }
  
  final response = await _supabase
    .from('menu_items')
    .select('*')
    .eq('location_id', user['serving_location_id'])
    .eq('available', true);
    
  // ... rest of code
}
```

#### **StoreProvider** - Filter by location with stock check
```dart
Future<void> loadStoreItems() async {
  final user = await _getUserServingLocation();
  
  if (user['serving_location_id'] == null) {
    _showNotInServiceArea();
    return;
  }
  
  final response = await _supabase
    .from('customer_available_store_items') // Uses view
    .select('*')
    .eq('location_id', user['serving_location_id']);
    
  // ... rest of code
}
```

#### **Admin Screens** - Filter by managed locations
```dart
Future<void> loadAdminData() async {
  final user = await _supabase
    .from('users')
    .select('managed_location_ids')
    .eq('auth_id', _supabase.auth.currentUser!.id)
    .single();
    
  final managedLocations = List<String>.from(user['managed_location_ids']);
  
  // Load menu items for managed locations
  final menuItems = await _supabase
    .from('menu_items')
    .select('*, locations(name)')
    .in_('location_id', managedLocations);
    
  // Load inventory for managed locations
  final inventory = await _supabase
    .from('ProductInventory')
    .select('*, products(name), locations(name)')
    .in_('location_id', managedLocations);
}
```

#### **Checkout** - Calculate delivery from customer's location
```dart
Future<void> calculateDelivery() async {
  final user = await _getUserWithLocation();
  final address = await _getSelectedAddress();
  
  final result = await _supabase
    .rpc('calculate_delivery_fee', params: {
      'location_id_param': user['serving_location_id'],
      'customer_lat': address.latitude,
      'customer_lon': address.longitude,
    });
    
  setState(() {
    deliveryFee = result;
  });
}
```

## Benefits

✅ **Location Isolation** - Customers only see items from their zone  
✅ **Admin Access Control** - Admins only manage their locations  
✅ **Proper Inventory** - Only store items use inventory, not restaurant food  
✅ **Zone-Based Delivery** - Each location has its own delivery settings  
✅ **Rider Assignment** - Riders only get orders from their zone  
✅ **Scalability** - Easy to add new locations without conflicts  
✅ **"Not in Service Area"** - Clear messaging when outside zones  

## Testing Checklist

- [ ] Customer with address in Zone A only sees Zone A items
- [ ] Customer with address in Zone B only sees Zone B items
- [ ] Customer with address outside all zones sees "Not in Service Area"
- [ ] Admin managing Zone A only sees Zone A data
- [ ] Admin managing multiple zones sees combined data
- [ ] Menu items don't show inventory/stock count
- [ ] Store items show correct stock from ProductInventory
- [ ] Delivery fee calculated correctly per location
- [ ] Rider from Zone A only sees Zone A orders
- [ ] Order placed in Zone A gets rider from Zone A
