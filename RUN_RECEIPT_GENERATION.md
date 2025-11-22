# Generate Missing Receipt - Instructions

## ✅ ISSUE FIXED
The SQL script had a bug - it was trying to use `o.customer_id` but the correct field is `o.user_auth_id`.

**Status**: ✅ **CORRECTED** in `database/generate_missing_receipt.sql`

---

## How to Run the Script

### Option 1: Supabase SQL Editor (Recommended)

1. **Open Supabase SQL Editor**:
   - URL: https://supabase.com/dashboard/project/hqfixpqwxmwftvhgdrxn/sql/new

2. **Copy the entire SQL**:
   - Open file: `database/generate_missing_receipt.sql`
   - Select all (Ctrl+A)
   - Copy (Ctrl+C)

3. **Paste into SQL Editor**:
   - Paste the SQL into the editor
   - Click "Run" (or press Ctrl+Enter)

4. **Check the output**:
   You should see messages like:
   ```
   NOTICE:  🔍 Found transaction without receipt: ...
   NOTICE:  📄 Creating receipt: RCP-...
   NOTICE:  ✅ Receipt created with ID: ...
   NOTICE:  ✅ Receipt items created for order ...
   NOTICE:  ==================================================
   NOTICE:  Receipt Generation Complete!
   ```

5. **Verify the receipt**:
   At the bottom, you'll see a SELECT query result showing:
   - Receipt number
   - Transaction ID
   - Customer name
   - Total amount
   - Number of items

---

## What the Script Does

1. ✅ Finds the most recent completed M-Pesa transaction **without a receipt**
2. ✅ Retrieves the order details
3. ✅ Generates a unique receipt number (RCP-YYYYMMDD-NNNNNN)
4. ✅ Creates receipt record with customer and business details
5. ✅ Creates receipt items from order items
6. ✅ Displays confirmation with receipt details

---

## Expected Output

```sql
-- If receipt needs to be created:
NOTICE: 🔍 Found transaction without receipt: [TRANSACTION_ID]
NOTICE:    Order ID: [ORDER_UUID]
NOTICE: 📄 Creating receipt: RCP-20251118-000001
NOTICE: ✅ Receipt created with ID: [RECEIPT_UUID]
NOTICE: ✅ Receipt items created for order [ORDER_UUID]
NOTICE: 
NOTICE: ==================================================
NOTICE: Receipt Generation Complete!
NOTICE: ==================================================
NOTICE: Receipt Number: RCP-20251118-000001
NOTICE: Transaction ID: [TRANSACTION_ID]
NOTICE: Customer: [CUSTOMER_NAME]
NOTICE: Total Amount: KSh [AMOUNT]
NOTICE: ==================================================

-- Then shows verification query result:
receipt_number     | transaction_id | customer_name | total_amount | issue_date | item_count
-------------------|----------------|---------------|--------------|------------|------------
RCP-20251118-000001| TEST123456     | John Doe      | 2500         | 2025-11-18 | 3
```

```sql
-- If no missing receipts:
NOTICE: ✅ No completed transactions without receipts found!
```

---

## Troubleshooting

### Error: "No completed transactions without receipts found"

**Cause**: All completed payments already have receipts!

**Solution**: Check if receipt already exists:
```sql
SELECT 
    r.receipt_number,
    r.transaction_id,
    r.customer_name,
    r.total_amount,
    COUNT(ri.id) as item_count
FROM receipts r
LEFT JOIN receipt_items ri ON r.id = ri.receipt_id
ORDER BY r.issue_date DESC
LIMIT 5;
```

### Error: "Order not found"

**Cause**: The transaction has an invalid `order_id`.

**Solution**: Check the transaction:
```sql
SELECT 
    mt.transaction_id,
    mt.order_id,
    mt.status,
    o.id as order_exists
FROM mpesa_transactions mt
LEFT JOIN orders o ON o.id = mt.order_id
WHERE mt.status = 'completed'
ORDER BY mt.updated_at DESC
LIMIT 1;
```

If `order_exists` is NULL, the order_id is invalid. You'll need to find the correct order and link it.

### Error: "column o.customer_id does not exist"

**Status**: ✅ **FIXED** - This was the bug. The script now correctly uses `o.user_auth_id`.

---

## After Running the Script

### Test Receipt Viewing in App

1. **Open your Flutter app**
2. **Navigate to Order History**
3. **Find the completed order**
4. **Click "Receipt" button**
5. **Verify receipt displays**:
   - Receipt number
   - Transaction ID
   - Customer details
   - Order items with prices
   - Total amount

### Verify in Database

```sql
-- Check the newly created receipt
SELECT 
    r.receipt_number,
    r.transaction_id,
    r.customer_name,
    r.customer_phone,
    r.total_amount,
    r.issue_date,
    COUNT(ri.id) as item_count
FROM receipts r
LEFT JOIN receipt_items ri ON r.id = ri.receipt_id
GROUP BY r.id
ORDER BY r.issue_date DESC
LIMIT 1;

-- Check receipt items
SELECT 
    ri.item_description,
    ri.quantity,
    ri.unit_price,
    ri.total_price
FROM receipt_items ri
JOIN receipts r ON r.id = ri.receipt_id
ORDER BY r.issue_date DESC
LIMIT 10;
```

---

## For Future Payments

✅ **No manual intervention needed!**

The `mpesa-query-status` Edge Function has been fixed and will automatically generate receipts for all new completed payments.

---

**Last Updated**: November 18, 2025
**Status**: ✅ Script corrected and ready to use
