-- ================================================================
-- TEST EDGE FUNCTION ORDER QUERY
-- ================================================================
-- This simulates exactly what the edge function does
-- ================================================================

-- Simulate the exact query the edge function uses
SELECT 
    o.*,
    u.email,
    u.name,
    u.phone,
    jsonb_agg(
        jsonb_build_object(
            'quantity', oi.quantity,
            'unit_price', oi.unit_price,
            'total_price', oi.total_price,
            'name', oi.name,
            'item_type', oi.item_type
        )
    ) as order_items
FROM orders o
INNER JOIN users u ON u.auth_id = o.user_auth_id
LEFT JOIN order_items oi ON oi.order_id = o.id
WHERE o.id IN (
    SELECT order_id 
    FROM mpesa_transactions 
    WHERE transaction_id IN (
        '4d20015a-dbc8-4a35-be61-0abb39c82c4a',
        'd6837a25-f5bc-45f1-9d75-430ec9d08148'
    )
)
GROUP BY o.id, u.email, u.name, u.phone;

-- Check if the query would fail
SELECT 
    'Order-User Join Test' as test,
    o.id as order_id,
    o.user_auth_id,
    u.auth_id as user_auth_id_from_users,
    CASE 
        WHEN u.auth_id IS NULL THEN '❌ User not found'
        ELSE '✅ User found'
    END as status
FROM mpesa_transactions mt
JOIN orders o ON o.id = mt.order_id
LEFT JOIN users u ON u.auth_id = o.user_auth_id
WHERE mt.transaction_id IN (
    '4d20015a-dbc8-4a35-be61-0abb39c82c4a',
    'd6837a25-f5bc-45f1-9d75-430ec9d08148'
);
