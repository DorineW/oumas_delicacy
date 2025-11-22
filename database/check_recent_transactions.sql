-- ================================================================
-- CHECK RECENT TRANSACTIONS AND RECEIPT STATUS
-- ================================================================

-- 1. Check the two test transactions from just now
SELECT 
    '1. Recent Test Transactions' as section,
    mt.transaction_id,
    mt.checkout_request_id,
    mt.order_id,
    mt.status,
    mt.result_code,
    mt.result_desc,
    mt.created_at,
    mt.updated_at,
    r.receipt_number,
    r.id as receipt_id,
    CASE 
        WHEN r.id IS NOT NULL THEN '✅ HAS RECEIPT'
        ELSE '❌ NO RECEIPT'
    END as receipt_status
FROM mpesa_transactions mt
LEFT JOIN receipts r ON r.transaction_id = mt.transaction_id
WHERE mt.transaction_id IN (
    '4d20015a-dbc8-4a35-be61-0abb39c82c4a',
    'd6837a25-f5bc-45f1-9d75-430ec9d08148',
    'TXN-1763751066745-ksmr4le'
)
ORDER BY mt.created_at DESC;

-- 2. Check the orders for these transactions
SELECT 
    '2. Orders for Recent Transactions' as section,
    o.id,
    o.short_id,
    o.status,
    o.total,
    o.placed_at,
    mt.transaction_id,
    (SELECT COUNT(*) FROM order_items WHERE order_id = o.id) as items_count
FROM orders o
JOIN mpesa_transactions mt ON mt.order_id = o.id
WHERE mt.transaction_id IN (
    '4d20015a-dbc8-4a35-be61-0abb39c82c4a',
    'd6837a25-f5bc-45f1-9d75-430ec9d08148'
)
ORDER BY o.placed_at DESC;

-- 3. Check order items
SELECT 
    '3. Order Items' as section,
    oi.order_id,
    oi.name,
    oi.quantity,
    oi.unit_price,
    oi.total_price,
    mt.transaction_id
FROM order_items oi
JOIN mpesa_transactions mt ON mt.order_id = oi.order_id
WHERE mt.transaction_id IN (
    '4d20015a-dbc8-4a35-be61-0abb39c82c4a',
    'd6837a25-f5bc-45f1-9d75-430ec9d08148'
)
ORDER BY mt.created_at DESC;

-- 4. All completed payments in last hour without receipts
SELECT 
    '4. All Missing Receipts (Last Hour)' as section,
    mt.transaction_id,
    mt.order_id,
    mt.status,
    mt.created_at,
    CASE 
        WHEN mt.order_id IS NULL THEN '❌ No order_id'
        WHEN EXISTS (SELECT 1 FROM receipts WHERE transaction_id = mt.transaction_id) THEN '✅ Has receipt'
        ELSE '❌ Missing receipt'
    END as issue
FROM mpesa_transactions mt
WHERE mt.status = 'completed'
  AND mt.created_at > NOW() - INTERVAL '1 hour'
ORDER BY mt.created_at DESC;

-- 5. Check if generate_receipt_number function still works
SELECT 
    '5. Function Test' as section,
    generate_receipt_number() as test_number;
