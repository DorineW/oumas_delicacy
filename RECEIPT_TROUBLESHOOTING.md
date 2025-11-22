# ================================================================
# RECEIPT TROUBLESHOOTING CHECKLIST
# ================================================================
# Run each step to diagnose why new orders aren't getting receipts
# ================================================================

## 🔍 STEP 1: Verify Edge Function is Deployed
```powershell
# Check when edge function was last deployed
supabase functions list
```

**Expected:** You should see `mpesa-query-status` in the list with a recent deployment time.

**If missing or old:** Deploy now:
```powershell
supabase functions deploy mpesa-query-status
```

---

## 🔍 STEP 2: Check Database Function Exists
Run this in Supabase SQL Editor:
```sql
SELECT generate_receipt_number();
```

**Expected:** Returns something like `RCP-20251121-000014`

**If error:** Run `database/create_receipt_number_function.sql` first

---

## 🔍 STEP 3: Run Complete System Verification
Run `database/verify_receipt_system.sql` in Supabase SQL Editor.

This will check:
- ✅ Function exists and works
- ✅ Tables have correct structure
- ✅ Permissions are correct
- ✅ Recent payments have receipts
- ❌ Any missing receipts

---

## 🔍 STEP 4: Check Edge Function Logs
1. Go to Supabase Dashboard
2. Navigate to **Edge Functions** → **mpesa-query-status**
3. Click **Logs** tab
4. Look for recent logs when you made a payment

**What to look for:**
- ✅ "✅ Receipt created: RCP-..." means success
- ❌ "Failed to create receipt:" means error (check error message)
- ❌ No logs = Edge function isn't being called

---

## 🔍 STEP 5: Test Manual Receipt Creation
Run this in Supabase SQL Editor to manually create a receipt for the newest payment:
```sql
-- Get the transaction_id of most recent payment without receipt
SELECT transaction_id, order_id 
FROM mpesa_transactions 
WHERE status = 'completed' 
  AND NOT EXISTS (SELECT 1 FROM receipts r WHERE r.transaction_id = mpesa_transactions.transaction_id)
ORDER BY created_at DESC 
LIMIT 1;
```

Then use the transaction_id to manually create:
```sql
-- Use the transaction_id from above query
WITH payment_data AS (
    SELECT 
        mt.transaction_id,
        mt.order_id,
        mt.created_at,
        o.subtotal,
        o.tax,
        o.total,
        COALESCE(u.name, 'Customer') as customer_name,
        COALESCE(u.phone, '') as customer_phone,
        COALESCE(u.email, '') as customer_email
    FROM mpesa_transactions mt
    JOIN orders o ON o.id = mt.order_id
    LEFT JOIN users u ON u.auth_id = COALESCE(mt.user_auth_id, o.user_auth_id)
    WHERE mt.transaction_id = 'REPLACE_WITH_TRANSACTION_ID'
)
INSERT INTO receipts (
    receipt_number,
    transaction_id,
    receipt_type,
    issue_date,
    customer_name,
    customer_phone,
    customer_email,
    subtotal,
    tax_amount,
    discount_amount,
    total_amount,
    currency,
    payment_method,
    business_name,
    business_email
)
SELECT
    generate_receipt_number(),
    transaction_id,
    'payment',
    created_at,
    customer_name,
    customer_phone,
    customer_email,
    CAST(ROUND(COALESCE(subtotal, 0)) AS INTEGER),
    CAST(ROUND(COALESCE(tax, 0)) AS INTEGER),
    0,
    CAST(ROUND(COALESCE(total, 0)) AS INTEGER),
    'KES',
    'M-Pesa',
    'Ouma''s Delicacy',
    'receipts@oumasdelicacy.com'
FROM payment_data
RETURNING receipt_number, id;
```

**If this works:** Edge function isn't being called. Check logs.
**If this fails:** Database permissions or function issue.

---

## 🔍 STEP 6: Check Environment Variables
Make sure these are set in Supabase Dashboard → Project Settings → Edge Functions → Environment Variables:

```
MPESA_CONSUMER_KEY=your_key
MPESA_CONSUMER_SECRET=your_secret
MPESA_SHORTCODE=your_shortcode
MPESA_PASSKEY=your_passkey
MPESA_ENVIRONMENT=sandbox (or production)
SUPABASE_URL=your_url
SUPABASE_SERVICE_ROLE_KEY=your_key
```

---

## 🔍 STEP 7: Test Complete Payment Flow
1. Make a test payment in your Flutter app
2. Wait for payment to complete (check M-Pesa)
3. Immediately check Supabase logs for Edge Function
4. Check if receipt appears in database:
```sql
SELECT * FROM receipts ORDER BY created_at DESC LIMIT 1;
```

---

## 📋 COMMON ISSUES & FIXES

### Issue 1: Edge Function Not Deployed
**Symptom:** No logs, no receipts created
**Fix:** `supabase functions deploy mpesa-query-status`

### Issue 2: Database Function Missing
**Symptom:** Error in logs: "function generate_receipt_number() does not exist"
**Fix:** Run `database/create_receipt_number_function.sql`

### Issue 3: Wrong Column Name
**Symptom:** Error in logs: "column item_name does not exist"
**Fix:** Already fixed in code (name, not item_name). Redeploy edge function.

### Issue 4: Permission Denied
**Symptom:** Error in logs: "permission denied for table receipts"
**Fix:** Run this in SQL editor:
```sql
GRANT ALL ON receipts TO service_role;
GRANT ALL ON receipt_items TO service_role;
GRANT USAGE, SELECT ON SEQUENCE receipts_id_seq TO service_role;
GRANT USAGE, SELECT ON SEQUENCE receipt_items_id_seq TO service_role;
```

### Issue 5: Edge Function Not Called
**Symptom:** Payment completes but no edge function logs
**Fix:** Check if your Flutter app is calling the query-status function. Should be automatic after STK push.

---

## ✅ SUCCESS CRITERIA
When working correctly, you should see:
1. Payment completes in Flutter app
2. Edge function logs show "✅ Receipt created: RCP-..."
3. Receipt appears in database within 5 seconds
4. Receipt button in app shows receipt immediately (with retry)
