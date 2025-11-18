# Store Items Favorites Implementation

## Overview
Extended the favorites system to support both menu items (food) and store items (groceries), allowing users to favorite items from both the restaurant menu and the store.

## Database Changes

### Migration Script: `add_favorites_item_type.sql`

**Changes made:**
1. Added `item_type` column to `favorites` table
   - Type: `TEXT NOT NULL DEFAULT 'menu_item'`
   - Constraint: Must be either `'menu_item'` or `'store_item'`

2. Updated unique constraint
   - Old: `(user_auth_id, product_id)`
   - New: `(user_auth_id, product_id, item_type)`
   - This allows the same product_id to be favorited if it's a different type

3. Removed foreign key constraint
   - Old: `product_id` referenced `menu_items(id)` only
   - New: No FK constraint (polymorphic relationship)
   - Reason: PostgreSQL doesn't support polymorphic FKs

4. Added validation trigger
   - Function: `validate_favorite_reference()`
   - Validates that menu_item references exist in `menu_items` table
   - Validates that store_item references exist in `StoreItems` table
   - Runs BEFORE INSERT/UPDATE on favorites table

5. Added indexes for performance
   - `idx_favorites_item_type` on `item_type`
   - `idx_favorites_product_type` on `(product_id, item_type)`

**Run this SQL in Supabase SQL Editor:**
```bash
# Open Supabase dashboard > SQL Editor > New query
# Copy contents of database/add_favorites_item_type.sql
# Execute
```

## Code Changes

### 1. FavoritesProvider (`lib/providers/favorites_provider.dart`)

**Added enum:**
```dart
enum FavoriteItemType {
  menuItem('menu_item'),
  storeItem('store_item');
}
```

**Updated Favorite model:**
```dart
class Favorite {
  final String id;
  final String userAuthId;
  final String productId;
  final FavoriteItemType itemType; // NEW
  final DateTime createdAt;
}
```

**Updated methods:**
- `isFavorite(userId, productId, {type = menuItem})` - Check if specific type is favorited
- `getFavoriteIds(userId, {type?})` - Get favorite IDs optionally filtered by type
- `getFavoritesForUser(userId, {type?})` - Get favorites optionally filtered by type
- `getCountForUser(userId, {type?})` - Count favorites optionally filtered by type
- `toggleFavorite(userId, productId, {type = menuItem})` - Toggle with type specification

**Database operations updated:**
- INSERT now includes `item_type` field
- DELETE matches on `product_id` AND `item_type`
- SELECT includes `item_type` column

### 2. Store Screen (`lib/screens/store_screen.dart`)

**Added imports:**
```dart
import '../providers/favorites_provider.dart';
import '../services/auth_service.dart';
```

**Updated ProductDetailSheet:**
- Removed local `_isFavorite` state
- Now uses `FavoritesProvider` to check real-time favorite status
- Uses `FavoriteItemType.storeItem` for all store item favorites
- Integrated with auth to check user ID
- Shows snackbar feedback when favoriting/unfavoriting

**Favorite button functionality:**
```dart
final isFavorite = favoritesProvider.isFavorite(
  userId, 
  widget.item.id, 
  type: FavoriteItemType.storeItem
);

onPressed: () async {
  await favoritesProvider.toggleFavorite(
    userId, 
    widget.item.id, 
    type: FavoriteItemType.storeItem,
  );
}
```

### 3. Dashboard Screen (`lib/screens/dashboard_screen.dart`)

**Updated to explicitly use menu item type:**
- `getCountForUser(userId, type: FavoriteItemType.menuItem)` - Only count menu favorites
- `getFavoritesForUser(userId, type: FavoriteItemType.menuItem)` - Only show menu favorites
- `toggleFavorite(userId, mealId, type: FavoriteItemType.menuItem)` - Toggle menu favorites

**Rationale:** Dashboard shows food favorites only to avoid mixing food and grocery items in the same list.

### 4. Home Screen (`lib/screens/home_screen.dart`)

**Updated MealDetailSheet:**
- All favorite operations explicitly use `type: FavoriteItemType.menuItem`
- Ensures meal favorites are tracked separately from store favorites

### 5. Meal Detail Screen (`lib/screens/meal_detail_screen.dart`)

**Updated favorite operations:**
- `isFavorite` check includes `type: FavoriteItemType.menuItem`
- `toggleFavorite` call includes `type: FavoriteItemType.menuItem`

## Usage

### For Menu Items (Food)
```dart
// Check if menu item is favorited
final isFavorite = favoritesProvider.isFavorite(
  userId, 
  menuItemId,
  type: FavoriteItemType.menuItem, // Default
);

// Toggle menu item favorite
await favoritesProvider.toggleFavorite(
  userId, 
  menuItemId,
  type: FavoriteItemType.menuItem,
);

// Get menu favorites count
final count = favoritesProvider.getCountForUser(
  userId,
  type: FavoriteItemType.menuItem,
);
```

### For Store Items (Groceries)
```dart
// Check if store item is favorited
final isFavorite = favoritesProvider.isFavorite(
  userId, 
  storeItemId,
  type: FavoriteItemType.storeItem,
);

// Toggle store item favorite
await favoritesProvider.toggleFavorite(
  userId, 
  storeItemId,
  type: FavoriteItemType.storeItem,
);

// Get store favorites count
final count = favoritesProvider.getCountForUser(
  userId,
  type: FavoriteItemType.storeItem,
);
```

### Get All Favorites (Mixed)
```dart
// Get all favorites regardless of type
final allFavoriteIds = favoritesProvider.getFavoriteIds(userId);

// Or get count of all favorites
final totalCount = favoritesProvider.getCountForUser(userId);
```

## Architecture Notes

### Why Polymorphic Favorites?
- Menu items and store items are in separate tables (`menu_items` vs `StoreItems`)
- Users want to favorite items from both categories
- Single favorites table with `item_type` discriminator is cleaner than two separate tables

### Why No Foreign Key?
PostgreSQL doesn't support conditional foreign keys. We use:
1. Database trigger for validation (enforces referential integrity)
2. Application-level checks (provider validates IDs exist)
3. Indexed queries (fast lookups despite no FK)

### Data Integrity
- Trigger `validate_favorite_reference_trigger` ensures:
  - `menu_item` favorites reference valid `menu_items.id`
  - `store_item` favorites reference valid `StoreItems.id`
- Constraint ensures `item_type` is valid enum value
- Unique constraint prevents duplicate favorites of same type

## Testing Checklist

### Database Migration
- [ ] Run `add_favorites_item_type.sql` in Supabase SQL Editor
- [ ] Verify `item_type` column exists: `SELECT * FROM favorites LIMIT 1;`
- [ ] Verify trigger exists: `SELECT * FROM pg_trigger WHERE tgname = 'validate_favorite_reference_trigger';`

### Menu Item Favorites (Existing Functionality)
- [ ] Favorite a meal from home screen
- [ ] See it appear in dashboard favorites
- [ ] Unfavorite from dashboard - should disappear
- [ ] Favorite count updates correctly

### Store Item Favorites (New Functionality)
- [ ] Open store screen
- [ ] Tap a product to open detail sheet
- [ ] Tap heart icon - should show "Added to favorites"
- [ ] Heart should fill in red
- [ ] Close and reopen - heart should stay filled
- [ ] Tap again - should show "Removed from favorites"
- [ ] Heart should become outlined

### Cross-Type Independence
- [ ] Favorite 3 menu items, 2 store items
- [ ] Dashboard shows only 3 menu favorites (correct)
- [ ] Database should have 5 total favorites with different types
- [ ] Query: `SELECT product_id, item_type FROM favorites WHERE user_auth_id = '<your-user-id>';`

### Edge Cases
- [ ] Try favoriting without login (should not crash)
- [ ] Favorite same item multiple times (should toggle, not duplicate)
- [ ] Network offline - should cache state
- [ ] Delete menu item - favorite should be cascade deleted
- [ ] Delete store item - favorite should be cascade deleted

## Database Queries for Verification

### Check all favorites with types
```sql
SELECT 
  f.id,
  f.product_id,
  f.item_type,
  f.created_at,
  u.name as user_name,
  CASE 
    WHEN f.item_type = 'menu_item' THEN m.name
    WHEN f.item_type = 'store_item' THEN s.name
  END as product_name
FROM favorites f
LEFT JOIN users u ON f.user_auth_id = u.auth_id
LEFT JOIN menu_items m ON f.product_id = m.id AND f.item_type = 'menu_item'
LEFT JOIN "StoreItems" s ON f.product_id = s.id AND f.item_type = 'store_item'
ORDER BY f.created_at DESC
LIMIT 20;
```

### Count favorites by type
```sql
SELECT 
  item_type,
  COUNT(*) as count
FROM favorites
GROUP BY item_type;
```

### Find orphaned favorites (should return 0 rows)
```sql
-- Menu item favorites with no matching menu item
SELECT f.* 
FROM favorites f
WHERE f.item_type = 'menu_item' 
  AND NOT EXISTS (SELECT 1 FROM menu_items m WHERE m.id = f.product_id);

-- Store item favorites with no matching store item
SELECT f.* 
FROM favorites f
WHERE f.item_type = 'store_item' 
  AND NOT EXISTS (SELECT 1 FROM "StoreItems" s WHERE s.id = f.product_id);
```

## Migration Steps for Existing Data

If you have existing favorites (all are menu_item type by default):

```sql
-- All existing favorites default to 'menu_item' type
-- No migration needed - the DEFAULT value handles it

-- Verify all existing favorites got the default
SELECT item_type, COUNT(*) FROM favorites GROUP BY item_type;
-- Should show: menu_item | <count>
```

## Future Enhancements

### Potential additions:
1. **Favorites Screen**: Dedicated screen showing all favorites grouped by type
2. **Favorites Sync**: Real-time sync across devices
3. **Favorite Collections**: Group favorites into custom lists
4. **Share Favorites**: Share favorite items with other users
5. **Favorite Notifications**: Alert when favorited items go on sale
6. **Analytics**: Track most favorited items for recommendations

### Database improvements:
1. Add `favorited_at` timestamp for sorting
2. Add `notes` field for personal notes on favorites
3. Add `priority` field for ranking favorites
4. Create materialized view for fast favorite counts

## Troubleshooting

### Issue: "column item_type does not exist"
**Solution:** Run the migration script `add_favorites_item_type.sql`

### Issue: Favorites not saving
**Check:**
1. User is logged in: `auth.currentUser?.id`
2. Product ID is valid UUID
3. Database trigger isn't failing (check Supabase logs)

### Issue: Duplicate favorites
**Check:** Unique constraint exists:
```sql
SELECT constraint_name, constraint_type 
FROM information_schema.table_constraints 
WHERE table_name = 'favorites';
```

### Issue: Can't favorite deleted items
**Expected behavior:** Trigger validates item exists before allowing favorite

## References

- Database schema: `database/add_favorites_item_type.sql`
- Favorites provider: `lib/providers/favorites_provider.dart`
- Store screen: `lib/screens/store_screen.dart`
- Dashboard screen: `lib/screens/dashboard_screen.dart`
