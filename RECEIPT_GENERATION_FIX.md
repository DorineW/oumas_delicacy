# Receipt Generation Fix - Complete ✅

## Issue Summary
Receipts were not being generated after successful M-Pesa payments because the `mpesa-query-status` function had incorrect receipt generation code.

## Root Cause
The `mpesa-query-status` function was trying to create receipts with fields (`order_id`, `customer_id`) that **don't exist** in the `receipts` table. The receipts table only uses `transaction_id` as the foreign key to link to `mpesa_transactions`.

## What Was Fixed

### 1. Updated `mpesa-query-status` Function
**File**: `supabase/functions/mpesa-query-status/index.ts`

**Changes**:
- ✅ Removed incorrect receipt generation code
- ✅ Added proper `generateReceipt()` function (copied from mpesa-callback)
- ✅ Receipt generation now uses correct table schema
- ✅ Properly links receipts via `transaction_id` foreign key
- ✅ Creates receipt items with correct structure

### 2. Deployed Updated Function
```powershell
supabase functions deploy mpesa-query-status
```

## How Receipt Generation Works Now

### Correct Flow:
1. **Payment initiated** → M-Pesa STK Push sent
2. **User enters PIN** → M-Pesa processes payment
3. **Two ways receipt is created**:
   - **Option A (Preferred)**: M-Pesa calls `mpesa-callback` → Receipt auto-generated
   - **Option B (Fallback)**: App polls `mpesa-query-status` → Receipt generated when status = completed

### Receipt Table Structure:
```sql
receipts
├── id (uuid)
├── receipt_number (varchar) - RCP-YYYYMMDD-NNNNNN
├── transaction_id (varchar) ← FK to mpesa_transactions.transaction_id
├── customer_name, customer_phone, customer_email
├── subtotal, tax_amount, discount_amount, total_amount
├── business_name, business_address, business_phone
└── receipt_items (one-to-many)
    ├── item_description
    ├── quantity
    ├── unit_price
    └── total_price
```

## Verification Steps

### 1. Check if Receipt Exists for Recent Payment
Run the SQL script: `check_receipt_status.sql`

This will show:
- Most recent completed transaction
- Whether a receipt exists for it
- Order details if receipt is missing

### 2. Manually Generate Missing Receipt
If a receipt is missing for a completed payment:

```sql
-- Run this in Supabase SQL Editor
\i database/generate_missing_receipt.sql
```

This will:
- Find the most recent completed transaction without a receipt
- Create the receipt with proper structure
- Insert all receipt items from order_items
- Display confirmation message

### 3. Test Receipt Viewing in App

#### Customer Side (Order History):
1. Navigate to Order History
2. Find the completed order
3. Click "Receipt" button
4. Should display actual receipt from database

#### Admin Side (Dashboard):
1. Go to Admin Dashboard
2. View completed orders
3. Click on order to see details
4. Receipt should be available

## Troubleshooting

### If Receipt Still Not Showing

#### Problem: Receipt exists but not displaying in app
**Solution**: Check RLS policies
```sql
-- Verify user can read their receipts
SELECT * FROM receipts 
WHERE transaction_id IN (
    SELECT transaction_id FROM mpesa_transactions 
    WHERE user_auth_id = auth.uid()
);
```

#### Problem: Receipt table empty after payment
**Check Logs**:
```powershell
# View Edge Function logs
supabase functions logs mpesa-query-status
supabase functions logs mpesa-callback
```

**Look for**:
- "✅ Receipt created: RCP-..."
- "✅ Receipt items created: X items"
- Any error messages about receipt creation

#### Problem: Payment successful but no order_id
This happens if payment initiated outside normal checkout flow.

**Fix**: Link the transaction to an order first:
```sql
UPDATE mpesa_transactions
SET order_id = 'YOUR_ORDER_UUID'
WHERE checkout_request_id = 'YOUR_CHECKOUT_REQUEST_ID';

-- Then generate receipt
\i database/generate_missing_receipt.sql
```

## Manual Receipt Generation Commands

### Generate Receipt for Specific Transaction
```sql
-- Replace with your actual checkout request ID
WITH target_tx AS (
    SELECT transaction_id, order_id, user_auth_id
    FROM mpesa_transactions
    WHERE checkout_request_id = 'ws_CO_18112025184650604700182990'
    AND status = 'completed'
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
    total_amount,
    business_name,
    payment_method,
    currency
)
SELECT 
    generate_receipt_number(),
    t.transaction_id,
    'payment',
    NOW(),
    u.full_name,
    u.phone,
    u.email,
    ROUND(o.subtotal),
    ROUND(COALESCE(o.tax, 0)),
    ROUND(o.total),
    'Ouma''s Delicacy',
    'M-Pesa',
    'KES'
FROM target_tx t
JOIN orders o ON o.id = t.order_id
JOIN users u ON u.auth_id = o.customer_id
RETURNING *;
```

### Generate All Missing Receipts
```sql
-- Run the automated script
\i database/generate_missing_receipt.sql
```

## Testing Checklist

After the fix, test the following:

- [ ] Make a test payment
- [ ] Wait for "Transaction status: completed" log
- [ ] Check database for receipt:
  ```sql
  SELECT * FROM receipts ORDER BY created_at DESC LIMIT 1;
  ```
- [ ] View receipt in Order History
- [ ] Verify all fields are correct:
  - Receipt number
  - Transaction ID
  - Customer details
  - Order items
  - Pricing breakdown
- [ ] Test as admin viewing customer receipts

## Database Queries for Monitoring

### Check Recent Receipts
```sql
SELECT 
    r.receipt_number,
    r.transaction_id,
    r.customer_name,
    r.total_amount,
    r.issue_date,
    COUNT(ri.id) as items
FROM receipts r
LEFT JOIN receipt_items ri ON r.id = ri.receipt_id
GROUP BY r.id
ORDER BY r.issue_date DESC
LIMIT 10;
```

### Find Completed Payments Without Receipts
```sql
SELECT 
    mt.checkout_request_id,
    mt.transaction_id,
    mt.amount,
    mt.phone_number,
    o.short_id as order_number,
    mt.updated_at
FROM mpesa_transactions mt
LEFT JOIN receipts r ON r.transaction_id = mt.transaction_id
LEFT JOIN orders o ON o.id = mt.order_id
WHERE mt.status = 'completed'
AND r.id IS NULL
ORDER BY mt.updated_at DESC;
```

### Receipt Generation Success Rate
```sql
SELECT 
    COUNT(DISTINCT mt.transaction_id) as total_completed_payments,
    COUNT(DISTINCT r.transaction_id) as receipts_generated,
    ROUND(COUNT(DISTINCT r.transaction_id)::NUMERIC / 
          NULLIF(COUNT(DISTINCT mt.transaction_id), 0) * 100, 2) as success_rate_percent
FROM mpesa_transactions mt
LEFT JOIN receipts r ON r.transaction_id = mt.transaction_id
WHERE mt.status = 'completed';
```

## Files Modified/Created

### Modified:
1. `supabase/functions/mpesa-query-status/index.ts` - Fixed receipt generation

### Created:
1. `check_receipt_status.sql` - Check for missing receipts
2. `database/generate_missing_receipt.sql` - Manual receipt generation
3. `RECEIPT_GENERATION_FIX.md` - This documentation

## Next Steps

### Immediate:
1. ✅ Deploy updated function (DONE)
2. Run `generate_missing_receipt.sql` for your current completed payment
3. Test receipt viewing in app

### For Future Payments:
- Receipts will auto-generate on successful payments
- Monitor logs to ensure no errors
- Check database periodically for missing receipts

## Related Documentation
- `RECEIPT_SYSTEM_UPDATE.md` - Receipt display implementation
- `MPESA_FLUTTER_INTEGRATION_COMPLETE.md` - M-Pesa payment flow
- `TESTING_PRODUCTION_MPESA.md` - Production testing guide

---

**Status**: ✅ **FIXED**
**Date**: November 18, 2025
**Issue**: Receipts not generating after successful M-Pesa payments
**Solution**: Fixed mpesa-query-status function to use correct receipt table schema
