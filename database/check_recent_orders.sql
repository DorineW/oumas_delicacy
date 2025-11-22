-- ============================================
-- CHECK RECENT ORDERS AND TRANSACTIONS
-- ============================================

-- 1. Check recent M-Pesa transactions
SELECT 
    'MPESA TRANSACTIONS' as table_name,
    transaction_id,
    checkout_request_id,
    order_id,
    user_auth_id,
    phone_number,
    amount,
    status,
    created_at,
    updated_at
FROM mpesa_transactions
ORDER BY created_at DESC
LIMIT 5;

-- 2. Check recent orders
SELECT 
    'ORDERS' as table_name,
    id,
    short_id,
    user_auth_id,
    status,
    total,
    payment_method_id,
    placed_at,
    updated_at
FROM orders
ORDER BY placed_at DESC
LIMIT 5;

-- 3. Check if specific order exists
SELECT 
    'SPECIFIC ORDER CHECK' as check_type,
    o.id,
    o.short_id,
    o.status,
    o.total,
    o.payment_method_id,
    o.placed_at,
    mt.transaction_id,
    mt.status as payment_status,
    mt.checkout_request_id
FROM orders o
LEFT JOIN mpesa_transactions mt ON mt.order_id = o.id
WHERE o.id = '3ba3f918-300f-4762-8fcc-e2ee593da1fc'
   OR o.short_id = 'ORD-1763484496';

-- 4. Check order items for this order
SELECT 
    'ORDER ITEMS' as table_name,
    oi.id,
    oi.order_id,
    oi.name,
    oi.quantity,
    oi.unit_price,
    oi.total_price
FROM order_items oi
WHERE oi.order_id = '3ba3f918-300f-4762-8fcc-e2ee593da1fc';

-- 5. Check latest transaction with order details
SELECT 
    'LATEST TRANSACTION WITH ORDER' as check_type,
    mt.transaction_id,
    mt.checkout_request_id,
    mt.status as payment_status,
    mt.amount as payment_amount,
    o.id as order_id,
    o.short_id,
    o.status as order_status,
    o.total as order_total,
    COUNT(oi.id) as item_count
FROM mpesa_transactions mt
LEFT JOIN orders o ON mt.order_id = o.id
LEFT JOIN order_items oi ON o.id = oi.order_id
WHERE mt.checkout_request_id = 'ws_CO_18112025194817799700182990'
GROUP BY mt.transaction_id, mt.checkout_request_id, mt.status, mt.amount, 
         o.id, o.short_id, o.status, o.total;
