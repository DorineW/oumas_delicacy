# Inventory System: How It Works

## Overview
The inventory system connects **Store Management** and **Inventory Management** to track products across multiple locations (warehouses, stores, restaurants).

---

## Data Flow Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    DATABASE LAYER                            │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  products table (catalog)                                    │
│     ├── id, name, price, category                           │
│     └── Global product definitions                           │
│                                                               │
│  ProductInventory table (inventory per location)             │
│     ├── product_id → products.id                            │
│     ├── location_id → locations.id                          │
│     ├── quantity (current stock)                            │
│     ├── minimum_stock_alert (threshold)                     │
│     └── last_restock_date                                   │
│                                                               │
│  StoreItems table (store display)                            │
│     ├── product_id → products.id                            │
│     ├── location_id → locations.id (optional)               │
│     ├── name, price, description, image                     │
│     └── available (boolean)                                 │
│                                                               │
└─────────────────────────────────────────────────────────────┘
           ↓                                    ↓
┌──────────────────────┐          ┌──────────────────────┐
│   StoreProvider      │          │  InventoryProvider   │
│  (Manages Display)   │          │  (Manages Stock)     │
└──────────────────────┘          └──────────────────────┘
           ↓                                    ↓
┌──────────────────────┐          ┌──────────────────────┐
│ Store Management     │←────────→│ Inventory Management │
│ Screen               │          │ Screen               │
└──────────────────────┘          └──────────────────────┘
```

---

## Two Screens Explained

### 1. **Admin Store Management Screen** (`admin_store_management_screen.dart`)

**Purpose:** Manage what customers see in the store

**What it does:**
- ✅ Add/Edit/Delete store items (products for sale)
- ✅ Set prices, descriptions, images, categories
- ✅ Toggle item availability (show/hide from customers)
- ✅ **Initial stock setup** when creating a new item

**Data Source:** 
- Reads from: `StoreItems` table (via `StoreProvider`)
- Also reads: `ProductInventory` table to show current stock levels

**Key Features:**
```dart
// When you add a new store item:
1. Creates entry in products table (catalog)
2. Creates entry in StoreItems table (display)
3. OPTIONALLY creates ProductInventory entry with initial stock
   - If you select a location and set initial stock > 0
   - This connects to Inventory Management

// When you click "Manage Stock" button:
- Opens dialog showing current stock per location
- Updates ProductInventory table
- This change is IMMEDIATELY visible in Inventory Management screen
```

**Example Flow:**
```
Admin adds "Ugali - KES 50" with initial stock of 100 at "Main Kitchen"
   ↓
1. products table: { id: uuid-1, name: "Ugali", price: 50 }
2. StoreItems table: { product_id: uuid-1, available: true }
3. ProductInventory table: { product_id: uuid-1, location_id: kitchen-1, quantity: 100 }
   ↓
Customer sees "Ugali - KES 50" on store
Inventory Manager sees "Ugali: 100 units at Main Kitchen"
```

---

### 2. **Admin Inventory Management Screen** (`admin_inventory_management_screen.dart`)

**Purpose:** Track and manage stock levels per location

**What it does:**
- ✅ View all inventory items at selected location
- ✅ Restock items (add quantity)
- ✅ Adjust stock levels
- ✅ View low stock alerts
- ✅ Track restock history
- ✅ Set minimum stock thresholds

**Data Source:**
- Reads from: `ProductInventory` table (via `InventoryProvider`)
- Joins with: `products` table (for product names), `locations` table (for location names)

**Key Features:**
```dart
// When screen loads:
1. Fetches all locations from LocationManagementProvider
2. Auto-selects first location
3. Queries: 
   SELECT * FROM ProductInventory 
   WHERE location_id = <selected-location>
   JOIN products, locations

// When you click "Restock":
- Adds quantity to existing stock
- Updates last_restock_date
- Records transaction in stock_history table (if exists)

// Low Stock Alerts:
- Shows items where: quantity <= minimum_stock_alert
- Red badge if critical (quantity = 0)
```

---

## How They Work Together

### Scenario 1: Admin adds NEW product to store

**In Store Management Screen:**
```
1. Click "Add Item"
2. Fill form: Name="Chapati", Price=20, Category="Food"
3. Select Location: "Main Kitchen"
4. Set Initial Stock: 200
5. Click Save

BACKEND ACTION:
- INSERT INTO products (name, price, category)
- INSERT INTO StoreItems (product_id, available=true)
- INSERT INTO ProductInventory (product_id, location_id, quantity=200)
```

**Result:**
- ✅ Store Management: Shows "Chapati" in item list
- ✅ Inventory Management: Shows "Chapati: 200 units at Main Kitchen"
- ✅ Customer App: Sees "Chapati - KES 20" in store

---

### Scenario 2: Admin restocks existing product

**In Inventory Management Screen:**
```
1. Select Location: "Main Kitchen"
2. Find item: "Ugali (Current: 25 units)" - shows LOW STOCK
3. Click "Restock"
4. Enter: +50 units
5. Click Confirm

BACKEND ACTION:
- UPDATE ProductInventory 
  SET quantity = quantity + 50,
      last_restock_date = NOW()
  WHERE product_id=xxx AND location_id=yyy
```

**Result:**
- ✅ Inventory Management: Now shows "Ugali: 75 units"
- ✅ Store Management: Stock indicator updates to "75"
- ✅ Customer App: Item remains available (wasn't out of stock)

---

### Scenario 3: Stock runs out

**What Happens:**
```
When ProductInventory.quantity reaches 0:
1. Inventory Management shows RED "Out of Stock" badge
2. Store Management shows "0" in stock column
3. Item is still VISIBLE in customer app (unless you toggle "available" to false)

Manual Action Needed:
- Either: Restock the item (Inventory Management)
- Or: Hide item from customers (Store Management → toggle available=false)
```

---

## Is the Data Dummy or Real?

### ❌ **NOT Dummy Data** - It's Real Database Records

**Source of Data:**

1. **When you first setup:**
   - Run `database/initialize_inventory_data.sql`
   - This script finds your first location and creates ProductInventory records
   - Default: 50 units per product, minimum alert at 10

2. **When you add items via Store Management:**
   - Real records inserted into `products`, `StoreItems`, `ProductInventory`
   - Saved in Supabase PostgreSQL database

3. **When you restock via Inventory Management:**
   - Real UPDATE queries to `ProductInventory` table
   - Persisted permanently

**To Verify:**
```sql
-- Run in Supabase SQL Editor:
SELECT 
  p.name AS product,
  l.name AS location,
  pi.quantity AS stock,
  pi.minimum_stock_alert AS min_alert,
  pi.last_restock_date
FROM public."ProductInventory" pi
JOIN public.products p ON pi.product_id = p.id
JOIN public.locations l ON pi.location_id = l.id
ORDER BY pi.updated_at DESC;
```

---

## Interface Synchronization

### ✅ **They ARE Connected** - Here's How:

**Shared Data Layer:**
```dart
// Both screens use the same database tables:
StoreProvider → StoreItems table ← StoreManagementScreen
                      ↓
                ProductInventory table
                      ↑
InventoryProvider → ProductInventory table ← InventoryManagementScreen
```

**Stock Management Button (Store Screen):**
```dart
// In admin_store_management_screen.dart line ~1122
void _showStockManagementDialog(StoreItem item) {
  // When you update stock here:
  await storeProvider.updateInventory(
    item.productId,
    selectedLocationId,
    quantity,
  );
  
  // ALSO refreshes InventoryProvider:
  if (inventoryProvider.currentLocationId == selectedLocationId) {
    await inventoryProvider.loadInventoryForLocation(selectedLocationId);
  }
}
```

**Result:** Both screens stay in sync!

---

## Testing the Connection

### Test 1: Verify Store → Inventory Link

1. **Store Management Screen:**
   - Add new item "Test Product" with 100 initial stock at "Main Kitchen"
   
2. **Inventory Management Screen:**
   - Select Location: "Main Kitchen"
   - Should see "Test Product: 100 units"

### Test 2: Verify Inventory → Store Link

1. **Inventory Management Screen:**
   - Find "Test Product: 100 units"
   - Click "Restock" → Add 50 units
   
2. **Store Management Screen:**
   - Find "Test Product"
   - Stock column should show "150"

### Test 3: Low Stock Alert

1. **Inventory Management:**
   - Find item with quantity = 8 (below minimum alert of 10)
   - Should show YELLOW "Low Stock" badge
   
2. **Store Management:**
   - Same item shows low stock indicator

---

## Current Issues & Fixes Needed

### ⚠️ Issue 1: Search Not Working
**Location:** `admin_inventory_management_screen.dart` line 65
```dart
// Current code is placeholder:
if (_searchQuery.isNotEmpty) {
  filtered = filtered.where((item) {
    return true; // ❌ This doesn't actually filter!
  }).toList();
}
```

**Fix:**
```dart
if (_searchQuery.isNotEmpty) {
  filtered = filtered.where((item) {
    final productName = item.productName?.toLowerCase() ?? '';
    final locationName = item.locationName?.toLowerCase() ?? '';
    final query = _searchQuery.toLowerCase();
    return productName.contains(query) || locationName.contains(query);
  }).toList();
}
```

### ⚠️ Issue 2: Product Names Not Showing
**Root Cause:** ProductInventory model needs proper JSON parsing

**Check:** `lib/models/product_inventory.dart`
```dart
factory ProductInventory.fromJson(Map<String, dynamic> json) {
  return ProductInventory(
    // ...
    productName: json['products']?['name'], // ✅ Should extract from nested join
    locationName: json['locations']?['name'], // ✅ Should extract from nested join
  );
}
```

---

## Summary

| Feature | Store Management | Inventory Management |
|---------|-----------------|---------------------|
| **Purpose** | What customers see | Track stock levels |
| **Primary Table** | `StoreItems` | `ProductInventory` |
| **Actions** | Add/Edit/Delete products | Restock/Adjust stock |
| **Data Type** | Display info (name, price, image) | Quantity tracking per location |
| **Customer Impact** | Direct (shows in app) | Indirect (availability) |
| **Stock Updates** | Via "Manage Stock" button | Via "Restock" button |

**They ARE connected** through:
- ✅ Shared `product_id` foreign key
- ✅ Both read/write `ProductInventory` table
- ✅ Real-time provider refresh
- ✅ Same Supabase database

**Data is REAL** - sourced from:
- ✅ Supabase PostgreSQL database
- ✅ `ProductInventory` table
- ✅ Created via SQL initialization or admin panel
- ✅ Persisted permanently (not dummy/mock data)
