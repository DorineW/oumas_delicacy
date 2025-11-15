# Phase 3: Multi-Location Inventory Management - Implementation Guide

## Overview
Phase 3 extends the location system to include inventory tracking per location, enabling:
- Stock levels per product per location
- Low stock alerts
- Location-based product filtering
- Automatic stock updates on orders

## Database Schema

### ✅ Created: `phase3_inventory_management.sql`

**Key Components:**

1. **ProductInventory Table**
   - Tracks stock quantity per product per location
   - Unique constraint: one record per product-location pair
   - Fields: quantity, minimum_stock_alert, last_restock_date
   - Constraints: quantity >= 0, minimum_stock_alert >= 0

2. **Added Columns:**
   - `menu_items.location_id` - Optional location assignment for menu items
   - `StoreItems.location_id` - Optional location assignment for store items
   - `orders.fulfillment_location_id` - Which location fulfilled the order

3. **Database Functions:**
   - `get_available_products_at_location()` - Get products with stock at location
   - `update_inventory_on_order()` - Reduce stock when order placed
   - `restock_inventory()` - Add stock to inventory

4. **Views:**
   - `low_stock_alerts` - Products below minimum stock threshold

5. **RLS Policies:**
   - Admins: Full access
   - Riders: View only
   - Customers: View available stock only

## Models

### ✅ Updated: `product_inventory.dart`
- `ProductInventory` - Main inventory model with location link
- `LowStockAlert` - Low stock view model
- `AvailableProduct` - Products available at location

### ✅ Existing: `inventory_provider.dart`
Provider for managing inventory operations (already created).

## Implementation Steps

### Step 1: Run Database Migration ✅ READY
```sql
-- Run this file in your Supabase SQL Editor:
database/phase3_inventory_management.sql
```

This will:
- Create ProductInventory table
- Add location columns to menu_items, StoreItems, orders
- Create helper functions and views
- Set up RLS policies

### Step 2: Initialize Sample Data (After Migration)
```sql
-- Run this to populate inventory for existing products:
DO $$ 
DECLARE
  v_first_location_id uuid;
BEGIN
  SELECT id INTO v_first_location_id
  FROM public.locations
  WHERE is_active = true
  ORDER BY created_at
  LIMIT 1;

  IF v_first_location_id IS NOT NULL THEN
    INSERT INTO public."ProductInventory" (product_id, location_id, quantity, minimum_stock_alert)
    SELECT 
      p.id,
      v_first_location_id,
      50, -- Default quantity
      10  -- Default minimum alert
    FROM public.products p
    WHERE NOT EXISTS (
      SELECT 1 FROM public."ProductInventory" pi
      WHERE pi.product_id = p.id AND pi.location_id = v_first_location_id
    );
  END IF;
END $$;
```

### Step 3: Register InventoryProvider (If Not Already Done)

Add to `main.dart` providers list:
```dart
ChangeNotifierProvider(create: (_) => InventoryProvider()),
```

### Step 4: Create Admin Screens

#### Option A: Update Existing Inventory Screen
The existing `inventory_screen.dart` uses `InventoryItem` model.
Need to update it to use `ProductInventory` with location selection.

#### Option B: Create New Multi-Location Inventory Screen
Create `admin_multi_location_inventory_screen.dart` that:
- Shows location selector dropdown
- Displays inventory for selected location
- Allows restocking per location
- Shows low stock alerts per location

### Step 5: Update Store/Menu Screens

Update product display to show:
- Stock availability at nearest location
- "In Stock" / "Out of Stock" badges
- Filter out items with 0 stock (optional)

### Step 6: Update Order Flow

1. **Checkout Screen:**
   - Determine fulfillment location (nearest to customer)
   - Check stock availability before order creation
   - Store `fulfillment_location_id` in order

2. **Order Creation:**
   - Call `update_inventory_on_order()` after successful order
   - Reduce stock at fulfillment location

## Admin Features to Implement

### 1. Inventory Dashboard
- **Location Selector** - Dropdown to select location
- **Stats Cards:**
  - Total products at location
  - In stock / Out of stock count
  - Low stock alerts
  - Total units

### 2. Inventory List View
- Product name and category
- Current quantity
- Minimum stock alert threshold
- Status badge (In Stock / Low Stock / Out of Stock)
- Last restock date
- Quick restock button

### 3. Restock Dialog
- Product selector
- Location selector
- Add quantity input
- Updates last_restock_date automatically

### 4. Low Stock Alerts
- Separate screen or section
- Shows all products below threshold across all locations
- Grouped by location
- Quick restock action

### 5. Bulk Operations
- Import inventory from CSV
- Bulk restock for multiple products
- Copy inventory from one location to another

## Customer-Facing Features

### 1. Product Availability
Update `StoreScreen` / `MenuScreen`:
```dart
// Show only products available at nearest location
final availableProducts = await inventoryProvider
    .getAvailableProductsAtLocation(nearestLocationId);

// Display stock status
Container(
  child: availableProduct.inStock
      ? Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 16),
            Text('In Stock', style: TextStyle(color: Colors.green)),
          ],
        )
      : Text('Out of Stock', style: TextStyle(color: Colors.red)),
)
```

### 2. Order Validation
Update `OrderProvider`:
```dart
// Before creating order
final stockCheck = await inventoryProvider.checkStockAvailability(
  fulfillmentLocationId,
  orderItems,
);

if (!stockCheck['available']) {
  // Show error with unavailable items
  showDialog(...);
  return;
}

// After order created successfully
await inventoryProvider.updateInventoryOnOrder(orderId);
```

## Testing Checklist

### Database
- [ ] Run migration SQL successfully
- [ ] Verify ProductInventory table created
- [ ] Check RLS policies working
- [ ] Test database functions (restock, update_on_order)
- [ ] Verify low_stock_alerts view

### Admin Functions
- [ ] Load inventory for location
- [ ] Create new inventory record
- [ ] Update quantity
- [ ] Restock (add quantity)
- [ ] Delete inventory record
- [ ] View low stock alerts
- [ ] Check stock statistics

### Customer Flow
- [ ] Products show stock status
- [ ] Out of stock items filtered/marked
- [ ] Order validates stock before creation
- [ ] Inventory reduces after order
- [ ] Correct location assigned to order

### Edge Cases
- [ ] Order with insufficient stock (should fail gracefully)
- [ ] Concurrent orders reducing same stock
- [ ] Restock with negative quantity (should fail)
- [ ] Delete location with inventory (cascade delete)

## Next Steps After Implementation

1. **Notifications:**
   - Email/push alerts for low stock
   - Daily inventory reports

2. **Analytics:**
   - Stock movement reports
   - Best/worst selling items per location
   - Restock frequency analysis

3. **Advanced Features:**
   - Automatic reorder when stock low
   - Transfer stock between locations
   - Expiration date tracking
   - Batch/lot tracking

## Notes

- Existing `InventoryScreen` and `InventoryItem` model are for single-location setup
- New `ProductInventory` model is for multi-location setup
- Can keep both systems or migrate fully to multi-location
- Consider adding `is_multi_location` flag to toggle behavior

## Quick Start

1. Run `database/phase3_inventory_management.sql` in Supabase
2. Initialize sample data for your first location
3. Test inventory functions in Supabase SQL Editor
4. Update admin inventory screen to use new models
5. Test full flow: add stock → place order → verify stock reduced

---

**Status:** Database schema ready ✅ | Models ready ✅ | Admin UI needed 🔨 | Integration needed 🔨
