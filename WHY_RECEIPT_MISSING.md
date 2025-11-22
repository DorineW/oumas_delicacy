# 🔍 WHY IS RECEIPT MISSING FOR TXN-1763751066745-ksmr4le?

## Payment Timeline:
- **Created**: 2025-11-21 18:51:06 UTC
- **Completed**: 2025-11-21 18:51:27 UTC (20 seconds after creation)
- **Edge Function Deployed**: 2025-11-21 18:48:31 UTC (3 minutes BEFORE payment)
- **Receipt Created**: ❌ NEVER

## ✅ What We Know Works:
1. ✅ `generate_receipt_number()` function exists and works (returns RCP-20251121-0010)
2. ✅ Edge function has correct code (column name fixed: `name` not `item_name`)
3. ✅ Edge function is deployed and active (version 7, updated 18:48:31)
4. ✅ Flutter app polls `checkPaymentStatus()` every 3 seconds for up to 3 minutes
5. ✅ Previous receipts work (RCP-20251121-000013 created at 18:46:45)
6. ✅ Order exists (ed9574ac-6d91-4e4f-b0b5-9b44cef7800d)

## ❓ Possible Reasons:

### 1️⃣ Edge Function Was Never Called
**Check**: Go to Supabase Dashboard → Edge Functions → `mpesa-query-status` → Logs tab

Look for logs between **18:51:27 and 18:54:00** (3 minutes after payment completed)

**Expected logs if called**:
```
🔍 Querying M-Pesa transaction status: CH_...
📡 Querying production M-Pesa API...
📊 M-Pesa query response: {...}
✅ Transaction updated: ...
📦 Updating order status to paid...
✅ Receipt created: RCP-20251121-000014
```

**If you see NO logs**: Edge function was never invoked
- **Cause**: Flutter app's `checkPaymentStatus()` call might have failed silently
- **Fix**: Check Flutter console logs during payment (look for "🔍 Querying M-Pesa")

**If you see logs but no "✅ Receipt created"**: Edge function ran but receipt creation failed
- **Cause**: Database error, permission issue, or missing order data
- **Fix**: Look at the error message in the logs

### 2️⃣ Edge Function Called But Failed
**Check**: Run `database/diagnose_specific_missing_receipt.sql` to see:
- Transaction details
- Order and order items data
- User information
- Simulated receipt data
- Permissions

**Common errors**:
- ❌ `generate_receipt_number() does not exist` - Function not in database
- ❌ `permission denied for table receipts` - Service role needs permissions
- ❌ `null value violates not-null constraint` - Missing required data
- ❌ `column "item_name" does not exist` - Old edge function code still cached

### 3️⃣ Transaction Status Check Timed Out
**Check**: Flutter logs during payment

Look for:
```
🔄 Manual status check (1/36)...
🔄 Manual status check (2/36)...
...
⏱️ Payment timeout after 3 minutes
```

**If timed out**: Payment might have completed AFTER the 3-minute window
- **Cause**: M-Pesa STK push was slow, user entered PIN late
- **Fix**: Receipt should still be created when edge function is called, but Flutter app stopped polling

### 4️⃣ Database Transaction Rollback
**Check**: Run the "Simulated Receipt Data" query in `diagnose_specific_missing_receipt.sql`

If the simulation works but actual insert didn't, it might be:
- Edge function had multiple insert statements and one failed, rolling back all
- Concurrent insert conflict (unlikely with unique receipt numbers)

## 🎯 IMMEDIATE ACTIONS:

### Action 1: Check Edge Function Logs (2 minutes)
1. Go to Supabase Dashboard
2. Edge Functions → `mpesa-query-status` → Logs
3. Filter by time: **18:51:00 to 18:55:00**
4. Look for the transaction ID: `TXN-1763751066745-ksmr4le`

### Action 2: Run Diagnostic SQL (1 minute)
Run `database/diagnose_specific_missing_receipt.sql` in SQL Editor
- This will show ALL data needed to create the receipt
- Tests if manual creation would work

### Action 3: Manually Create the Receipt (30 seconds)
If diagnosis shows all data is present, run:
`database/fix_missing_receipt_manual.sql`

This will:
- Create receipt with proper receipt number
- Add receipt items from order
- Verify creation

### Action 4: Test New Payment (5 minutes)
After manually fixing:
1. Make a new test payment in Flutter app
2. Watch the Supabase Edge Function logs in real-time
3. Watch Flutter console logs
4. See if receipt is auto-created this time

## 📋 MOST LIKELY CAUSE:

Based on the pattern (other receipts work, edge function is deployed), I suspect:

**🎯 The edge function was never called for this specific payment**

Why? Possible reasons:
1. Flutter app's network request to edge function failed
2. Flutter app stopped polling before payment completed
3. M-Pesa callback was delayed and Flutter timeout occurred

**Solution**: 
- Check Flutter logs during payment
- Manually create this one receipt
- Monitor next payment carefully

## 🔧 QUICK FIX NOW:

```sql
-- Run this in Supabase SQL Editor to create the missing receipt:
-- (This is safe - it will only create if it doesn't exist)
```
Then run the contents of `database/fix_missing_receipt_manual.sql`
