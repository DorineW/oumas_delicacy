# Fix Receipt Generation - Step by Step

## Issue
Receipts aren't being created in the database for completed M-Pesa payments.

## Root Causes Found
1. `generate_receipt_number()` function has wrong return type or doesn't exist
2. NULL values in business_address/business_phone causing inserts to fail
3. Edge function fails silently without proper error logging

## Fix Steps (Run in Supabase SQL Editor)

### Step 1: Drop and Recreate the Function
```sql
-- Run: database/create_receipt_number_function.sql
-- This will DROP the old function and create it with correct return type
```

### Step 2: Diagnose Current State
```sql
-- Run: database/diagnose_receipt_issue.sql
-- This shows:
-- - Does function exist?
-- - Which payments are missing receipts?
-- - Any data quality issues (missing names, phones, etc)?
```

### Step 3: Generate Missing Receipts
```sql
-- Run: database/generate_missing_receipts.sql
-- This will:
-- - Create receipts for ALL completed payments without receipts
-- - Handle NULL values properly (COALESCE)
-- - Show progress with NOTICE messages
-- - Count total receipts generated
```

### Step 4: Verify Results
```sql
-- Run the verification query at the bottom of generate_missing_receipts.sql
-- Should show all completed payments now have receipts
```

## What Changed in the Scripts

### 1. create_receipt_number_function.sql
- Added `DROP FUNCTION IF EXISTS` to handle type mismatches
- Function returns TEXT (was maybe returning something else before)

### 2. generate_missing_receipts.sql
**Fixed NULL handling:**
- `LEFT JOIN users` instead of `JOIN` (user might be null)
- `COALESCE(u.name, 'Customer')` - default name if null
- `COALESCE(u.phone, '')` - empty string if null
- `NULL` for business_address/business_phone (these are nullable columns)
- `CAST(ROUND(COALESCE(value, 0)) AS INTEGER)` - safe number conversion

**Better error reporting:**
- Shows SQLSTATE code with errors
- Counts total receipts generated
- Shows progress: `[1] Created receipt...`, `[2] Created receipt...`

### 3. diagnose_receipt_issue.sql (NEW)
**Comprehensive diagnostics:**
- Checks if function exists and its return type
- Lists all completed payments and their receipt status
- Counts data quality issues:
  - Missing orders
  - Missing users
  - Orders with no items
  - Users with no name/phone
- Shows a DRY RUN of what would be inserted
- Shows table structures

## Expected Output

### After Step 1 (Function Creation):
```
Query 1 OK: DROP FUNCTION
Query 2 OK: CREATE FUNCTION
Query 3 Result: sample_receipt_number = "RCP-20251121-0001"
```

### After Step 3 (Backfill):
```
NOTICE: ✅ [1] Created receipt RCP-20251121-0001 for transaction TXN-xxx with 3 items
NOTICE: ✅ [2] Created receipt RCP-20251121-0002 for transaction TXN-yyy with 5 items
...
NOTICE: ========================================
NOTICE: ✅ COMPLETE: Generated 15 receipts
NOTICE: ========================================
```

### Verification Query Result:
Should show all transactions with receipt_number and items_count populated.

## Common Errors and Fixes

### Error: "cannot change return type of existing function"
**Solution:** The script now includes `DROP FUNCTION IF EXISTS` - just re-run it.

### Error: "null value in column violates not-null constraint"
**Solutions:**
- Check which column is failing
- If it's `business_name`: Make sure there's a default in the INSERT
- If it's `customer_name`: Script now uses `COALESCE(u.name, 'Customer')`
- If it's `subtotal/total`: Script now uses `COALESCE(value, 0)`

### Error: "function generate_receipt_number() does not exist"
**Solution:** Run Step 1 first (create_receipt_number_function.sql)

### Error: "foreign key violation on transaction_id"
**Solution:** Transaction ID in mpesa_transactions doesn't match. Check:
```sql
SELECT transaction_id FROM mpesa_transactions WHERE status = 'completed' LIMIT 5;
```

## Testing New Payments

After fixing:
1. Hot reload Flutter app
2. Make a test M-Pesa payment (use sandbox)
3. Check Supabase Edge Functions logs:
   - Should see: "✅ Receipt created: RCP-20251121-XXXX"
4. Check receipts table:
   ```sql
   SELECT * FROM receipts ORDER BY created_at DESC LIMIT 1;
   ```
5. In app, tap "Receipt" button
6. Receipt should appear within 6 seconds

## Permanent Fix for Future Payments

The edge function (`mpesa-query-status`) already has the `generateReceipt()` function. Once the database function exists, all new payments will automatically generate receipts.

No code changes needed - just ensure the database function exists!
