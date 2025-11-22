# Receipt Generation Fix - Complete Guide

## 🔍 Problem Identified
Receipts are not being created in the database when M-Pesa payments complete successfully.

## 🎯 Root Causes
1. **Missing `generate_receipt_number()` function** - Edge function tries to call this but it doesn't exist
2. **Silent failures** - Receipt generation errors are logged but not thrown, so payments succeed but receipts fail
3. **Data type mismatches** - NUMERIC values from database might not convert properly to INTEGER

## ✅ Complete Fix (Run in Order)

### Step 1: Create Receipt Number Generator Function
Run in Supabase SQL Editor:
```sql
-- File: database/create_receipt_number_function.sql
```
This creates the `generate_receipt_number()` function that generates unique receipt numbers like `RCP-20251121-0001`.

### Step 2: Check Current Receipt Status
Run in Supabase SQL Editor:
```sql
-- File: database/check_receipt_generation.sql
```
This shows:
- If the function exists
- Recent M-Pesa transactions and their receipt status
- Which completed payments are missing receipts

### Step 3: Generate Missing Receipts
Run in Supabase SQL Editor:
```sql
-- File: database/generate_missing_receipts.sql
```
This:
- Creates receipts for all completed payments that don't have them
- Includes all receipt items
- Shows progress with NOTICE messages

### Step 4: Test New Payments
After running the above:
1. Hot reload your Flutter app
2. Make a test M-Pesa payment
3. Wait 6-10 seconds for payment to complete
4. Tap "Receipt" button
5. Receipt should now appear!

## 📊 How It Works Now

### Payment Flow with Receipt Generation
```
1. User completes checkout → Order created with pending_payment status
2. M-Pesa STK Push initiated → Transaction record created
3. User enters PIN and approves
4. Flutter app polls status every 3 seconds
5. mpesa-query-status edge function detects completion
6. Edge function:
   ✅ Updates transaction to 'completed'
   ✅ Updates order to 'confirmed' (via database trigger)
   ✅ Calls generateReceipt() function
   ✅ Creates receipt with unique number
   ✅ Creates receipt_items for all order items
7. Flutter app reloads orders (shows confirmed order)
8. User taps "Receipt" button
9. App fetches receipt with 3-retry logic (6 seconds total)
10. Receipt displays successfully!
```

## 🔧 What Was Fixed

### 1. Database Function Created
- `generate_receipt_number()` - Generates unique sequential receipt numbers per day
- Format: `RCP-YYYYMMDD-XXXX` (e.g., `RCP-20251121-0001`)

### 2. Flutter App Enhanced
- **3-retry mechanism** with 2-second delays between attempts
- **Smart error messages** based on order status
- **RETRY button** in error snackbar
- **Non-null receipt handling** to prevent crashes

### 3. Edge Function Improved
- Better error logging in `generateReceipt()`
- Safe number conversion with `parseFloat()` and `Math.round()`
- Null-safe user data access with `?.`

## 🧪 Verification Queries

### Check if function exists:
```sql
SELECT proname FROM pg_proc WHERE proname = 'generate_receipt_number';
```

### Check recent receipts:
```sql
SELECT 
    r.receipt_number,
    r.transaction_id,
    r.total_amount,
    r.created_at,
    COUNT(ri.id) as items_count
FROM receipts r
LEFT JOIN receipt_items ri ON ri.receipt_id = r.id
WHERE r.created_at > NOW() - INTERVAL '24 hours'
GROUP BY r.id
ORDER BY r.created_at DESC;
```

### Find payments without receipts:
```sql
SELECT 
    mt.transaction_id,
    mt.created_at,
    o.short_id as order_number
FROM mpesa_transactions mt
LEFT JOIN receipts r ON r.transaction_id = mt.transaction_id
JOIN orders o ON o.id = mt.order_id
WHERE mt.status = 'completed'
  AND r.id IS NULL
ORDER BY mt.created_at DESC;
```

## 📝 Files Modified

### Database Scripts (New)
1. `database/create_receipt_number_function.sql` - Creates the receipt number generator
2. `database/check_receipt_generation.sql` - Diagnostic queries
3. `database/generate_missing_receipts.sql` - Backfill missing receipts

### Flutter App (Modified)
1. `lib/screens/order_history_screen.dart` - Added retry logic and better errors
2. `lib/screens/dashboard_screen.dart` - Added retry logic and better errors

### Edge Functions (Already Correct)
1. `supabase/functions/mpesa-query-status/index.ts` - Has `generateReceipt()` function
2. `supabase/functions/mpesa-callback/index.ts` - Also has `generateReceipt()` function

## 🚨 Important Notes

1. **Run SQL scripts in order** - The function must exist before generating receipts
2. **Check edge function logs** - Go to Supabase → Edge Functions → Logs to see receipt generation
3. **Receipts take 2-6 seconds** - The callback is async, so receipts aren't instant
4. **Old payments need backfill** - Run `generate_missing_receipts.sql` for historical data

## ✅ Success Indicators

After fixing, you should see:
- ✅ Edge function logs: "✅ Receipt created: RCP-20251121-XXXX"
- ✅ Receipts table populated with new entries
- ✅ Receipt button in app works within 6 seconds
- ✅ No more "Payment may still be processing" for confirmed orders

## 🆘 Troubleshooting

### If receipts still don't generate:
1. Check edge function logs for errors
2. Verify `generate_receipt_number()` function exists
3. Check if orders have `order_items` (receipts need items)
4. Verify users table has required fields (name, phone, email)
5. Check receipts table permissions (service_role can insert)

### If "function generate_receipt_number() does not exist":
```sql
-- Run this in SQL Editor:
\i database/create_receipt_number_function.sql
```

### If old payments don't have receipts:
```sql
-- Run this in SQL Editor:
\i database/generate_missing_receipts.sql
```
