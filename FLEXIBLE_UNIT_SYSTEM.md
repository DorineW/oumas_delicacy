# Flexible Unit System for Store Items

## Overview
The store management system now uses **flexible unit descriptions** instead of rigid dropdown options. This allows you to specify exact sizes, weights, and quantities for each product variant.

## The Problem We Solved
Previously, the system only allowed 5 fixed units:
- ❌ Piece, Kilogram, Liter, Packet, Set

This was impractical because:
- Salt comes in 250g, 500g, 1kg packets
- Soda comes in 150ml, 300ml, 500ml, 1L, 2L bottles/cans
- Cabbage can be sold as Quarter, Half, or Whole
- Potatoes can be sold by piece, kilogram, or sack

## The Solution
Each store item now has a **Unit Description** field where you can enter:
- Exact weights: `500g`, `1kg`, `2.5kg`
- Exact volumes: `300ml`, `1L`, `2L`
- Portions: `Half`, `Quarter`, `Whole`
- Bulk quantities: `1 Sack`, `Bundle of 6`, `Dozen`
- Any combination: `500ml Bottle`, `2kg Bag`, `250g Pack`

## Database Changes
Run this SQL migration to update your database:
```sql
-- See: database/add_flexible_unit_description.sql
```

Key changes:
1. ✅ Added `unit_description` column (flexible text field)
2. ✅ Migrated existing data (e.g., "Kilogram" → "1 Kg")
3. ✅ Made `unit_of_measure` optional (legacy field)
4. ✅ Removed the rigid constraint limiting to 5 values

## How to Use in Admin Panel

### Adding a New Product
1. Click **"+ Add Item"**
2. Fill in the **Name** (e.g., "Coca-Cola")
3. Fill in the **Price** (e.g., 100)
4. Select/Add **Category** (e.g., "Beverages")
5. **Unit Description**: Enter the specific size (e.g., "500ml Bottle")
6. Add description and image as usual

### Example: Creating Product Variants

#### Salt in Different Sizes
| Name | Price | Unit Description |
|------|-------|-----------------|
| Salt - Small | KSh 25 | `250g` |
| Salt - Medium | KSh 45 | `500g` |
| Salt - Large | KSh 85 | `1kg` |

#### Soda in Different Sizes
| Name | Price | Unit Description |
|------|-------|-----------------|
| Coca-Cola Can | KSh 60 | `300ml Can` |
| Coca-Cola Bottle | KSh 100 | `500ml Bottle` |
| Coca-Cola Family | KSh 180 | `1.5L Bottle` |
| Coca-Cola Party | KSh 250 | `2L Bottle` |

#### Cabbage by Portion
| Name | Price | Unit Description |
|------|-------|-----------------|
| Cabbage - Quarter | KSh 25 | `Quarter` |
| Cabbage - Half | KSh 45 | `Half` |
| Cabbage - Whole | KSh 80 | `Whole` |

#### Potatoes by Measurement
| Name | Price | Unit Description |
|------|-------|-----------------|
| Potatoes - Small Pack | KSh 50 | `1 Kg` |
| Potatoes - Medium Pack | KSh 120 | `2.5 Kg` |
| Potatoes - Sack | KSh 800 | `25 Kg Sack` |

## Best Practices

### ✅ DO:
- Be specific: `500ml Bottle` instead of just `500ml`
- Use common abbreviations: `g`, `kg`, `ml`, `L`
- Be consistent within category
- Use descriptive portions: `Half`, `Quarter`, `Whole`
- Include packaging: `Can`, `Bottle`, `Pack`, `Sack`

### ❌ DON'T:
- Use vague terms: "Small", "Medium", "Large" alone
- Mix different measurement systems inconsistently
- Leave it empty
- Use special characters excessively

## Common Unit Examples

### Weight-based Products
- `250g`, `500g`, `1kg`, `2kg`, `5kg`
- `250g Pack`, `1kg Bag`, `5kg Sack`

### Volume-based Products
- `150ml`, `250ml`, `300ml`, `500ml`, `1L`, `1.5L`, `2L`
- `300ml Can`, `500ml Bottle`, `2L Bottle`

### Count-based Products
- `1 Piece`, `2 Pieces`, `6 Pieces`
- `Half Dozen`, `Dozen`, `Bundle of 12`

### Portion-based Products
- `Quarter`, `Half`, `Whole`
- `Slice`, `Portion`, `Serving`

### Bulk/Packaging
- `1 Packet`, `1 Bundle`, `1 Sack`
- `Small Pack`, `Family Pack`, `Bulk Pack`

## Code Changes Summary

### Model Updates (`lib/models/store_item.dart`)
- Added `unitDescription` field (optional String)
- Kept `unitOfMeasure` for backward compatibility
- Updated `fromJson`, `toJson`, `copyWith` methods

### Provider Updates (`lib/providers/store_provider.dart`)
- Added `unit_description` to create/update operations
- Both fields sent to database for compatibility

### Admin Screen Updates (`lib/screens/admin/admin_store_management_screen.dart`)
- Removed rigid dropdown with 5 options
- Added flexible `TextFormField` with helpful hints
- Shows examples: "e.g., 500g, 2L, Half, 1 Sack, 250ml"
- Displays unit in item list using `unitDescription ?? unitOfMeasure`

## Migration Steps

1. **Backup your database** first!

2. **Run the SQL migration:**
   ```bash
   # In Supabase SQL Editor, run:
   database/add_flexible_unit_description.sql
   ```

3. **Hot reload your app** or restart:
   ```bash
   r  # Hot reload in terminal
   ```

4. **Test the changes:**
   - Go to Admin → Store Management
   - Edit an existing item to see migrated unit
   - Add a new item with custom unit (e.g., "500ml")
   - Verify it displays correctly in the list

## Troubleshooting

### "Column 'unit_description' does not exist"
- Run the SQL migration first
- Check Supabase logs to ensure it executed successfully

### Existing items show "1 Piece", "1 Kg", etc.
- This is expected! The migration converted old data
- Edit each item to update to specific units (e.g., "500g")

### Unit not displaying in app
- Make sure you hot reloaded after code changes
- Check that `unitDescription` field is populated in database
- Falls back to `unitOfMeasure` if `unitDescription` is null

## Benefits of This System

✅ **Real-world flexibility**: Handle any product variation
✅ **Better pricing**: Different prices for different sizes
✅ **Customer clarity**: Clear size information ("500ml Bottle")
✅ **Inventory accuracy**: Track each variant separately
✅ **Scalability**: Add new sizes without code changes
✅ **Professional**: Matches how real stores operate

---

**Need Help?** Check `database/add_flexible_unit_description.sql` for SQL examples and verification queries.
