-- ================================================================
-- DIAGNOSE WHY RECEIPT NOT CREATED FOR TXN-1763751066745-ksmr4le
-- ================================================================

-- 1. Check the transaction details
SELECT 
    '1. Transaction Details' as section,
    mt.*
FROM mpesa_transactions mt
WHERE mt.transaction_id = 'TXN-1763751066745-ksmr4le';

-- 2. Check if order exists and has items
SELECT 
    '2. Order Details' as section,
    o.id,
    o.short_id,
    o.status,
    o.user_auth_id,
    o.subtotal,
    o.tax,
    o.total,
    o.placed_at
FROM orders o
WHERE o.id = (
    SELECT order_id FROM mpesa_transactions 
    WHERE transaction_id = 'TXN-1763751066745-ksmr4le'
);

-- 3. Check order items
SELECT 
    '3. Order Items' as section,
    oi.*
FROM order_items oi
WHERE oi.order_id = (
    SELECT order_id FROM mpesa_transactions 
    WHERE transaction_id = 'TXN-1763751066745-ksmr4le'
);

-- 4. Check user details
SELECT 
    '4. User Details' as section,
    u.auth_id,
    u.name,
    u.email,
    u.phone
FROM users u
WHERE u.auth_id = (
    SELECT COALESCE(mt.user_auth_id, o.user_auth_id)
    FROM mpesa_transactions mt
    LEFT JOIN orders o ON o.id = mt.order_id
    WHERE mt.transaction_id = 'TXN-1763751066745-ksmr4le'
);

-- 5. Simulate what the edge function would try to insert
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
    WHERE mt.transaction_id = 'TXN-1763751066745-ksmr4le'
)
SELECT
    '5. Simulated Receipt Data' as section,
    generate_receipt_number() as would_generate_receipt_number,
    transaction_id,
    'payment' as receipt_type,
    created_at as issue_date,
    customer_name,
    customer_phone,
    customer_email,
    CAST(ROUND(COALESCE(subtotal, 0)) AS INTEGER) as subtotal,
    CAST(ROUND(COALESCE(tax, 0)) AS INTEGER) as tax_amount,
    0 as discount_amount,
    CAST(ROUND(COALESCE(total, 0)) AS INTEGER) as total_amount,
    'KES' as currency,
    'M-Pesa' as payment_method
FROM payment_data;

-- 6. Check if generate_receipt_number function exists and works
SELECT 
    '6. Function Test' as section,
    generate_receipt_number() as test1,
    generate_receipt_number() as test2;

-- 7. Check permissions
SELECT 
    '7. Permissions' as section,
    'receipts' as table_name,
    has_table_privilege('service_role', 'public.receipts', 'INSERT') as service_can_insert,
    has_table_privilege('service_role', 'public.receipts', 'SELECT') as service_can_select,
    has_table_privilege('authenticated', 'public.receipts', 'INSERT') as auth_can_insert,
    has_table_privilege('authenticated', 'public.receipts', 'SELECT') as auth_can_select;

-- 8. Check receipt_items permissions
SELECT 
    '8. Receipt Items Permissions' as section,
    'receipt_items' as table_name,
    has_table_privilege('service_role', 'public.receipt_items', 'INSERT') as service_can_insert,
    has_table_privilege('service_role', 'public.receipt_items', 'SELECT') as service_can_select;

-- 9. Look for any error patterns in recent receipts
SELECT 
    '9. Recent Receipt Pattern' as section,
    r.receipt_number,
    r.created_at,
    r.transaction_id,
    COUNT(ri.id) as items_count
FROM receipts r
LEFT JOIN receipt_items ri ON ri.receipt_id = r.id
WHERE r.created_at > NOW() - INTERVAL '24 hours'
GROUP BY r.id, r.receipt_number, r.created_at, r.transaction_id
ORDER BY r.created_at DESC
LIMIT 5;
