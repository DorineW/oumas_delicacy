# ADDRESS, ORDER, AND DELIVERY SYSTEM - COMPLETE INTEGRATION GUIDE

## Overview
This document explains the complete data flow from customer address management through order placement to rider delivery.

---

## 1. DATABASE SCHEMA RELATIONSHIPS

### Tables and Their Connections

```
UserAddresses (Customer saved addresses)
    ↓ (FK: orders.delivery_address_id)
orders (Order records)
    ↓ (FK: Deliveries.order_id)
Deliveries (Delivery tracking)
    ↓ (FK: Deliveries.assigned_rider_id)
riders (Delivery personnel)
```

### UserAddresses Table
**Purpose**: Store customer's saved delivery addresses

**Key Fields**:
- `id` (uuid) - Primary key
- `user_auth_id` (uuid) - FK to users.auth_id
- `label` (text) - e.g., "Home", "Work", "Mom's Place"
- `latitude` (numeric) - GPS coordinate
- `longitude` (numeric) - GPS coordinate
- `descriptive_directions` (text) - Landmark-based directions
- `street_address` (text, nullable) - Optional formal address
- `is_default` (boolean) - Only one per user can be true

**Indexes**:
- `idx_useraddresses_user_auth_id` - Find user's addresses
- `idx_useraddresses_is_default` - Quick default lookup
- `idx_useraddresses_one_default_per_user` - Unique constraint on default

**RLS Policies**:
- Users can CRUD their own addresses
- Admins can view all addresses
- Riders can view addresses for their assigned orders

---

### orders Table
**Purpose**: Store order information with delivery details

**Key Fields**:
- `id` (uuid) - Primary key
- `short_id` (text) - Human-readable order number
- `user_auth_id` (uuid) - Customer FK
- `customer_name` (text) - Customer display name
- `delivery_phone` (text) - Contact phone for delivery
- `status` (text) - Order status (confirmed, preparing, outForDelivery, delivered, cancelled)
- `subtotal`, `delivery_fee`, `tax`, `total` (integers) - Money in cents
- `delivery_type` (text) - 'delivery' or 'pickup'
- `delivery_address` (jsonb) - **Snapshot of address at order time**
- `delivery_address_id` (uuid) - **FK to UserAddresses** (optional, if from saved address)
- `delivery_lat` (numeric) - **Latitude for rider navigation**
- `delivery_lon` (numeric) - **Longitude for rider navigation**
- `placed_at` (timestamptz) - Order creation time
- `delivered_at` (timestamptz) - Delivery completion time
- `cancelled_at` (timestamptz) - Cancellation time

**Why Both delivery_address AND delivery_address_id?**
- `delivery_address_id`: Links to saved address for reference
- `delivery_address` (jsonb): **Preserves address snapshot** even if user later modifies/deletes the saved address
- `delivery_lat/lon`: Direct coordinates for rider navigation (auto-populated from UserAddresses via trigger)

**Indexes**:
- `idx_orders_delivery_address_id` - FK lookup
- `idx_orders_delivery_coordinates` - Geospatial queries (find orders near rider)

---

### Deliveries Table
**Purpose**: Track delivery fulfillment and rider assignment

**Key Fields**:
- `id` (uuid) - Primary key
- `order_id` (uuid) - FK to orders.id
- `fulfillment_step` (text) - 'Preparation', 'Picking', 'Delivery'
- `status` (text) - 'Pending', 'In Transit', 'Delivered', etc.
- `assigned_rider_id` (uuid) - FK to riders.id
- `warehouse_location_id` (uuid) - FK to locations.id (restaurant/warehouse)
- `estimated_completion_time` (timestamptz) - ETA

**Indexes**:
- `idx_deliveries_assigned_rider_id` - Find rider's deliveries
- `idx_deliveries_order_rider` - Composite for order-rider lookups
- `idx_deliveries_status` - Filter active deliveries

---

### riders Table
**Purpose**: Store rider information and real-time location

**Key Fields**:
- `id` (uuid) - Primary key
- `auth_id` (uuid) - FK to auth.users (login account)
- `name`, `phone`, `vehicle` (text)
- `is_available` (boolean) - Ready for assignments
- `location_lat`, `location_lon` (numeric) - **Current rider position**
- `last_seen_at` (timestamptz) - Last GPS update

**Indexes**:
- `idx_riders_location_available` - Find nearby available riders

---

## 2. DATA FLOW - CUSTOMER TO RIDER

### Phase 1: Customer Address Management

**Registration (register_screen.dart)**:
```dart
// After successful registration, user is prompted to add first address
await addressProvider.addAddress(
  label: 'Home',
  latitude: lat,
  longitude: lon,
  descriptiveDirections: address,
  setAsDefault: true, // First address = default
);
```
→ Inserts into `UserAddresses` table
→ `is_default = true` constraint ensures only one default per user

**Address Management (customer_address_management_screen.dart)**:
- View all saved addresses
- Add new addresses with GPS capture
- Edit existing addresses
- Delete addresses
- Set default address

**Access Points**:
1. Profile Screen → "My Addresses"
2. Edit Profile Screen → "Manage" in Delivery Addresses section
3. Checkout Screen → "Manage" button

---

### Phase 2: Order Placement with Address Selection

**Checkout Flow (checkout_screen.dart)**:

```dart
// User selects saved address from dropdown
_selectSavedAddress(UserAddress address) {
  // 1. Find nearest restaurant/warehouse
  final nearestLocation = locationManagementProvider.getNearestLocation(
    address.latitude,
    address.longitude,
  );
  
  // 2. Validate delivery zone
  final deliveryInfo = await addressProvider.getDeliveryInfo(
    address: address,
    location: nearestLocation,
  );
  
  if (!deliveryInfo.isInZone) {
    // Show error: Address outside delivery zone
    return;
  }
  
  // 3. Set address for order
  setState(() {
    _selectedAddressId = address.id; // FK to UserAddresses
    _deliveryLatLng = LatLng(address.latitude, address.longitude);
    _deliveryAddressController.text = address.displayAddress;
    _deliveryFee = deliveryInfo.deliveryFee;
  });
}

// When placing order
final orderDetails = {
  'deliveryAddress': {
    'address': _deliveryAddressController.text,
    'latitude': _deliveryLatLng.latitude,
    'longitude': _deliveryLatLng.longitude,
    'address_id': _selectedAddressId,
  },
  'deliveryAddressId': _selectedAddressId, // Direct FK
  'deliveryLat': _deliveryLatLng.latitude, // For rider
  'deliveryLon': _deliveryLatLng.longitude, // For rider
  'deliveryPhone': normalizedPhone,
  ...
};
```

**Backend Order Creation**:
```sql
INSERT INTO orders (
  id,
  user_auth_id,
  delivery_address_id, -- FK to UserAddresses
  delivery_address, -- JSONB snapshot
  delivery_lat, -- For rider navigation
  delivery_lon, -- For rider navigation
  delivery_phone,
  ...
) VALUES (...);
```

**Database Trigger** (`sync_address_to_order()`):
- When `delivery_address_id` is set
- Automatically fetches UserAddresses record
- Populates `delivery_lat`, `delivery_lon`, and `delivery_address` JSONB
- **Ensures order has complete address even if UserAddress is later deleted**

---

### Phase 3: Delivery Assignment & Tracking

**Admin Dashboard**:
1. Views orders via `order_delivery_details` VIEW
2. Assigns rider to order → Creates `Deliveries` record
3. Sets `warehouse_location_id` (closest restaurant to customer)

**Deliveries Record**:
```sql
INSERT INTO "Deliveries" (
  order_id,
  assigned_rider_id,
  warehouse_location_id,
  fulfillment_step,
  status
) VALUES (
  '<order_uuid>',
  '<rider_uuid>',
  '<location_uuid>',
  'Preparation',
  'Pending'
);
```

---

### Phase 4: Rider Navigation

**Rider App**:
1. Queries assigned deliveries:
```sql
SELECT * FROM order_delivery_details
WHERE assigned_rider_id = '<rider_id>'
  AND delivery_status IN ('Pending', 'In Transit');
```

2. Gets:
   - `delivery_lat`, `delivery_lon` - Customer destination
   - `delivery_address_text` - Full address description
   - `delivery_phone` - Contact number
   - `warehouse_lat`, `warehouse_lon` - Pickup location
   - `distance_km` - Calculated distance

3. Uses coordinates for:
   - Google Maps navigation
   - ETA calculation
   - Route optimization

---

## 3. KEY INTEGRATION POINTS

### Registration → UserAddresses
✅ `register_screen.dart` saves first address with `setAsDefault: true`
✅ Address stored in UserAddresses table
✅ Available in home_screen via AddressProvider

### Checkout → Orders
✅ Saved addresses shown in dropdown
✅ Delivery zone validation before order
✅ Order created with:
   - `delivery_address_id` (FK)
   - `delivery_address` (JSONB snapshot)
   - `delivery_lat/lon` (coordinates)
   - `delivery_phone`

### Orders → Deliveries
✅ Admin creates Delivery record
✅ Links: order_id + assigned_rider_id + warehouse_location_id
✅ Tracks fulfillment_step and status

### Deliveries → Riders
✅ Riders query via RLS policy (see only their orders)
✅ Access full address via `order_delivery_details` VIEW
✅ Navigate using `delivery_lat/lon`

---

## 4. MODELS REFERENCE

### Order Model Fields
```dart
class Order {
  final String id;
  final String? shortId; // Human-readable
  final String customerId; // user_auth_id
  final String? deliveryPhone; // ✅ For rider contact
  final Map<String, dynamic>? deliveryAddress; // ✅ JSONB snapshot
  final String? deliveryAddressId; // ✅ FK to UserAddresses
  final double? deliveryLat; // ✅ For rider nav
  final double? deliveryLon; // ✅ For rider nav
  final String? riderId;
  final String? riderName;
  ...
}
```

### UserAddress Model Fields
```dart
class UserAddress {
  final String id;
  final String userAuthId;
  final String label; // "Home", "Work"
  final double latitude; // GPS
  final double longitude; // GPS
  final String descriptiveDirections; // Landmarks
  final String? streetAddress; // Optional
  final bool isDefault;
  
  String get displayAddress => // Formatted display
}
```

---

## 5. DATABASE VIEW FOR ADMIN/RIDER

**order_delivery_details** VIEW provides complete information:

```sql
SELECT * FROM order_delivery_details;
```

Returns:
- Order details (id, number, status, total, dates)
- Customer info (name, phone)
- Delivery address (text, label, coordinates)
- Rider info (name, phone, current location)
- Warehouse info (name, address, coordinates)
- **Calculated distance** (warehouse → customer)

---

## 6. MIGRATION CHECKLIST

Run this SQL migration:
```
database/FIX_ADDRESS_ORDER_DELIVERY_FLOW.sql
```

This ensures:
✅ orders.delivery_address_id FK exists
✅ orders.delivery_lat/lon columns exist
✅ Trigger auto-populates address from UserAddresses
✅ order_delivery_details VIEW created
✅ Indexes for performance
✅ RLS policies for riders
✅ Backfill for existing orders

---

## 7. TESTING GUIDE

### Test 1: Address Management
1. Register new user
2. Add address with GPS location
3. Verify in UserAddresses table
4. Add 2nd address, set as default
5. Check only one has is_default=true

### Test 2: Order with Saved Address
1. Go to checkout
2. Select saved address from dropdown
3. Verify delivery zone validation
4. Complete order
5. Check orders table has:
   - delivery_address_id populated
   - delivery_lat/lon populated
   - delivery_address JSONB snapshot

### Test 3: Rider Navigation
1. Admin assigns rider to order
2. Rider views order in app
3. Verify rider sees:
   - Full address text
   - Coordinates for navigation
   - Customer phone
   - Warehouse pickup location

---

## 8. TROUBLESHOOTING

**Problem**: Order has no coordinates
**Solution**: Run migration to add trigger + backfill existing orders

**Problem**: Rider can't see order addresses
**Solution**: Check RLS policy "Riders can view assigned order addresses"

**Problem**: Delivery fee not calculated
**Solution**: Verify locations table has delivery_radius_km and coordinates

**Problem**: Address deleted, order broken
**Solution**: This is OK! delivery_address JSONB preserves snapshot

---

## SUMMARY

The system now has **complete end-to-end integration**:

1. **Customer** saves addresses → UserAddresses
2. **Checkout** validates zone, creates order → orders (with FK + snapshot + coordinates)
3. **Admin** assigns delivery → Deliveries
4. **Rider** navigates to customer → Uses delivery_lat/lon
5. **All parties** see consistent address data via database relationships

**Key Benefit**: Even if customer deletes/modifies saved address later, the order preserves the address snapshot from order time!
