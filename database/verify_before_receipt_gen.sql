-- Quick verification before running the receipt generator
-- Run this first to see your transaction status

-- 1. Check most recent transaction
SELECT 
    mt.checkout_request_id,
    mt.transaction_id,
    mt.status,
    mt.result_code,
    mt.amount,
    mt.phone_number,
    mt.order_id,
    mt.created_at,
    mt.updated_at,
    CASE 
        WHEN r.id IS NOT NULL THEN '✅ Receipt exists'
        ELSE '❌ No receipt'
    END as receipt_status
FROM mpesa_transactions mt
LEFT JOIN receipts r ON r.transaction_id = mt.transaction_id
WHERE mt.status = 'completed'
ORDER BY mt.updated_at DESC
LIMIT 1;

-- 2. Check if order exists and has correct structure
SELECT 
    o.id as order_id,
    o.short_id,
    o.user_auth_id,
    o.status,
    o.total,
    o.subtotal,
    o.tax,
    u.full_name as customer_name,
    u.phone as customer_phone,
    u.email as customer_email,
    COUNT(oi.id) as item_count
FROM orders o
JOIN users u ON o.user_auth_id = u.auth_id
LEFT JOIN order_items oi ON oi.order_id = o.id
WHERE o.id = (
    SELECT order_id 
    FROM mpesa_transactions 
    WHERE status = 'completed'
    ORDER BY updated_at DESC 
    LIMIT 1
)
GROUP BY o.id, u.full_name, u.phone, u.email;

-- 3. Check order items details
SELECT 
    oi.item_name,
    oi.item_type,
    oi.quantity,
    oi.unit_price,
    oi.total_price
FROM order_items oi
WHERE oi.order_id = (
    SELECT order_id 
    FROM mpesa_transactions 
    WHERE status = 'completed'
    ORDER BY updated_at DESC 
    LIMIT 1
)
ORDER BY oi.created_at;

-- 4. Summary
SELECT 
    'Transaction Info' as check_type,
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ Found completed transaction'
        ELSE '❌ No completed transaction found'
    END as status
FROM mpesa_transactions 
WHERE status = 'completed'

UNION ALL

SELECT 
    'Order Link' as check_type,
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ Order exists and linked'
        ELSE '❌ No order found for transaction'
    END as status
FROM mpesa_transactions mt
JOIN orders o ON o.id = mt.order_id
WHERE mt.status = 'completed'

UNION ALL

SELECT 
    'Order Items' as check_type,
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ Order has items (' || COUNT(*) || ')'
        ELSE '❌ No order items found'
    END as status
FROM order_items oi
WHERE oi.order_id IN (
    SELECT order_id 
    FROM mpesa_transactions 
    WHERE status = 'completed'
)

UNION ALL

SELECT 
    'Receipt Status' as check_type,
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ Receipt already exists - no need to generate'
        ELSE '❌ Receipt missing - run generate_missing_receipt.sql'
    END as status
FROM receipts r
WHERE r.transaction_id IN (
    SELECT transaction_id 
    FROM mpesa_transactions 
    WHERE status = 'completed'
);
