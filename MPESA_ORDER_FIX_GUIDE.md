# 🔧 M-Pesa Order Creation Issue - Complete Fix Guide

## 🎯 Problem Summary

**Symptom:** M-Pesa payments complete successfully but no orders appear in the orders table.

**Root Cause:** The trigger that updates order status when M-Pesa payments complete may have issues with:
1. Status checking logic
2. Error handling
3. Missing `order_id` links in completed transactions
4. RLS policies blocking updates

---

## 📊 Current Flow (How It Should Work)

```
1. User goes to checkout
   ↓
2. Flutter app creates ORDER with status='pending_payment'
   ↓
3. Flutter app initiates M-Pesa payment WITH order_id
   ↓
4. M-Pesa transaction created in database (status='pending')
   ↓
5. User enters PIN on phone → Payment completes
   ↓
6. M-Pesa callback updates transaction status to 'completed'
   ↓
7. TRIGGER fires → Updates order status to 'confirmed'
   ↓
8. User sees order in app ✅
```

---

## 🔍 Diagnosis

### Step 1: Run Diagnostic Queries

Run the PowerShell script:
```powershell
.\fix_mpesa_order_issue.ps1
```

Or manually run queries from `database\diagnose_mpesa_order_issue.sql`

### Key Things to Check:

1. **Do completed payments have `order_id`?**
   ```sql
   SELECT transaction_id, order_id, status 
   FROM mpesa_transactions 
   WHERE status = 'completed';
   ```
   - ❌ If `order_id` is NULL → Flutter app not passing order_id
   - ✅ If `order_id` exists → Check order status

2. **What status are the orders?**
   ```sql
   SELECT o.id, o.short_id, o.status, mt.status as payment_status
   FROM orders o
   JOIN mpesa_transactions mt ON mt.order_id = o.id
   WHERE mt.status = 'completed';
   ```
   - ❌ If still `pending_payment` → Trigger not firing
   - ✅ If `confirmed` → Orders ARE being created, check your app query

3. **Is the trigger enabled?**
   ```sql
   SELECT trigger_name, event_object_table, action_timing
   FROM information_schema.triggers
   WHERE trigger_name = 'trg_update_order_status_on_payment';
   ```
   - Should return 1 row showing AFTER INSERT OR UPDATE

---

## 🔧 The Fix

### Option 1: Automated Fix (Recommended)

Run the PowerShell script:
```powershell
.\fix_mpesa_order_issue.ps1
```

Choose option 3 (Both - diagnostics and fix)

### Option 2: Manual Fix

Run this SQL in Supabase SQL Editor:
```sql
-- Copy contents from: database\fix_mpesa_order_trigger.sql
```

---

## ✨ What the Fix Does

### 1. **Improved Trigger Function**

**Before:**
```sql
IF NEW.status = 'completed' AND OLD.status IS DISTINCT FROM 'completed' THEN
  UPDATE orders SET status = 'confirmed' WHERE id = NEW.order_id;
END IF;
```

**After:**
```sql
-- ✅ Better status checking (handles both pending_payment and pending)
-- ✅ Detailed logging for debugging
-- ✅ Error handling (doesn't fail on errors)
-- ✅ Works for both INSERT and UPDATE operations
```

### 2. **Backfill Script**

Automatically finds completed payments without `order_id` and:
- Matches them to orders by user, amount, and timestamp
- Links the transaction to the order
- Updates order status to 'confirmed'

### 3. **Verification Queries**

Shows the status of all completed payments and their orders

---

## 📱 Testing the Fix

### 1. Clear Test

1. **Check before:**
   ```sql
   SELECT COUNT(*) FROM orders WHERE status = 'confirmed';
   ```

2. **Make a test payment:**
   - Add items to cart
   - Go to checkout
   - Use test phone: `254708374149`
   - Complete payment
   - Wait 5-10 seconds

3. **Check after:**
   ```sql
   SELECT * FROM orders 
   WHERE status = 'confirmed' 
   ORDER BY placed_at DESC 
   LIMIT 1;
   ```

### 2. Check Logs

In Supabase Dashboard → Database → Logs:

Look for messages like:
```
NOTICE: M-Pesa payment completed for order xxx. Current status: pending_payment
NOTICE: Updated 1 order(s) to confirmed status
```

### 3. Check in Flutter App

1. Go to "My Orders" screen
2. You should see the new order with status "Confirmed"

---

## 🐛 Troubleshooting

### Issue: Orders still not appearing

**Possible Causes:**

#### 1. **RLS (Row Level Security) Policies**

Check if RLS is blocking your queries:

```sql
-- Check RLS status
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'orders';

-- Check policies
SELECT * FROM pg_policies 
WHERE tablename = 'orders';
```

**Solution:** Make sure you have a SELECT policy:
```sql
CREATE POLICY "Users can view their own orders"
ON public.orders
FOR SELECT
USING (auth.uid() = user_auth_id);
```

#### 2. **App Query Filter**

Check your Flutter app query in `OrderProvider`:

```dart
// Make sure you're querying for 'confirmed' status
final orders = await Supabase.instance.client
  .from('orders')
  .select()
  .eq('user_auth_id', userId)
  .in_('status', ['pending', 'confirmed', 'preparing', 'ready'])  // Include 'confirmed'!
  .order('placed_at', ascending: false);
```

#### 3. **Transaction Not Completing**

Check M-Pesa transaction status:

```sql
SELECT 
  checkout_request_id,
  status,
  result_code,
  result_desc
FROM mpesa_transactions
WHERE checkout_request_id = 'YOUR_CHECKOUT_REQUEST_ID';
```

- `result_code = 0` → Success
- `result_code = 1032` → Cancelled by user
- `result_code = 1037` → Timeout
- Other codes → Check M-Pesa error codes

#### 4. **Order ID Not Passed**

Check Flutter logs for:
```
✅ Order created: <uuid>
💳 Initiating M-Pesa payment...
```

Make sure the order UUID is passed to `initiatePayment()`:

```dart
final paymentSuccess = await mpesaProvider.initiatePayment(
  phoneNumber: mpesaPhone,
  amount: totalAmount,
  orderId: orderId,  // ← Must not be null!
  accountReference: 'ORDER-${orderId.substring(0, 8)}',
);
```

---

## 📝 Understanding the Code Flow

### Flutter Side (checkout_screen.dart)

```dart
Future<void> _processOrderAndPayment() async {
  // 1. Create order in database
  final orderId = await orderProvider.createOrder(
    customerId: currentUser.id,
    items: orderItems,
    // ... other params
  );
  
  // 2. Initiate M-Pesa payment WITH order_id
  final paymentSuccess = await mpesaProvider.initiatePayment(
    phoneNumber: mpesaPhone,
    amount: totalAmount,
    orderId: orderId,  // ← Links payment to order
    accountReference: 'ORDER-${orderId.substring(0, 8)}',
  );
  
  // 3. Show payment dialog
  showDialog(context: context, builder: (context) => PaymentDialog());
}
```

### Database Side (PostgreSQL Trigger)

```sql
-- When mpesa_transactions INSERT/UPDATE happens:
CREATE TRIGGER trg_update_order_status_on_payment
AFTER INSERT OR UPDATE OF status ON mpesa_transactions
FOR EACH ROW
EXECUTE FUNCTION update_order_status_on_payment();

-- The function does:
CREATE FUNCTION update_order_status_on_payment()
BEGIN
  IF NEW.status = 'completed' AND NEW.order_id IS NOT NULL THEN
    -- Update the linked order
    UPDATE orders 
    SET status = 'confirmed' 
    WHERE id = NEW.order_id 
      AND status IN ('pending_payment', 'pending');
  END IF;
END;
```

---

## ✅ Expected Results After Fix

1. **Trigger is active and logging**
   - Check Supabase logs for NOTICE messages

2. **Completed payments have order_id**
   ```sql
   SELECT order_id FROM mpesa_transactions WHERE status = 'completed';
   -- All should have a valid UUID
   ```

3. **Orders update to 'confirmed' automatically**
   ```sql
   SELECT status FROM orders WHERE id IN (
     SELECT order_id FROM mpesa_transactions WHERE status = 'completed'
   );
   -- All should be 'confirmed'
   ```

4. **Orders appear in Flutter app**
   - "My Orders" screen shows the order
   - Order has correct items and total
   - Status shows as "Confirmed"

---

## 🚀 Next Steps After Fix

1. **Test thoroughly** with multiple payments
2. **Monitor database logs** for any warnings
3. **Add app-side logging** to track order creation flow
4. **Consider adding order notifications** (push/email)
5. **Update order status workflow** (confirmed → preparing → ready → completed)

---

## 📞 Still Having Issues?

If the fix doesn't work, gather this info:

```sql
-- 1. Recent payment
SELECT * FROM mpesa_transactions 
ORDER BY created_at DESC LIMIT 1;

-- 2. Recent order
SELECT * FROM orders 
ORDER BY placed_at DESC LIMIT 1;

-- 3. Trigger status
SELECT * FROM information_schema.triggers 
WHERE trigger_name = 'trg_update_order_status_on_payment';

-- 4. Database logs
-- Go to Supabase Dashboard → Database → Logs
-- Look for errors around the payment timestamp
```

Share these results for further debugging.

---

## 📚 Related Files

- **Diagnostic SQL:** `database/diagnose_mpesa_order_issue.sql`
- **Fix SQL:** `database/fix_mpesa_order_trigger.sql`
- **PowerShell Script:** `fix_mpesa_order_issue.ps1`
- **Flutter Checkout:** `lib/screens/checkout_screen.dart`
- **Order Provider:** `lib/providers/order_provider.dart`
- **M-Pesa Provider:** `lib/providers/mpesa_provider.dart`

---

**Last Updated:** November 21, 2025  
**Status:** ✅ Ready to apply
