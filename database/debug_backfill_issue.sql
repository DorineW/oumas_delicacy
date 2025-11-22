-- ================================================================
-- DEBUG: Why aren't payments being found for receipt generation?
-- ================================================================

-- 1. Count completed payments
SELECT 
    'Total completed payments' as check_type,
    COUNT(*) as count
FROM mpesa_transactions mt
WHERE mt.status = 'completed'
  AND mt.created_at > NOW() - INTERVAL '7 days';

-- 2. Count completed payments WITH orders
SELECT 
    'Completed payments with orders' as check_type,
    COUNT(*) as count
FROM mpesa_transactions mt
JOIN orders o ON o.id = mt.order_id
WHERE mt.status = 'completed'
  AND mt.created_at > NOW() - INTERVAL '7 days';

-- 3. Count completed payments WITHOUT receipts
SELECT 
    'Completed payments WITHOUT receipts' as check_type,
    COUNT(*) as count
FROM mpesa_transactions mt
WHERE mt.status = 'completed'
  AND mt.created_at > NOW() - INTERVAL '7 days'
  AND NOT EXISTS (
    SELECT 1 FROM receipts r WHERE r.transaction_id = mt.transaction_id
  );

-- 4. Count completed payments with orders and WITHOUT receipts (what the script searches for)
SELECT 
    'Payments ready for receipt generation' as check_type,
    COUNT(*) as count
FROM mpesa_transactions mt
JOIN orders o ON o.id = mt.order_id
LEFT JOIN users u ON u.auth_id = COALESCE(mt.user_auth_id, o.user_auth_id)
WHERE mt.status = 'completed'
  AND mt.created_at > NOW() - INTERVAL '7 days'
  AND NOT EXISTS (
    SELECT 1 FROM receipts r WHERE r.transaction_id = mt.transaction_id
  );

-- 5. Show the actual payments that should get receipts
SELECT 
    mt.transaction_id,
    mt.order_id,
    mt.user_auth_id as mt_user_id,
    o.user_auth_id as order_user_id,
    COALESCE(mt.user_auth_id, o.user_auth_id) as resolved_user_id,
    u.name as user_name,
    mt.created_at
FROM mpesa_transactions mt
JOIN orders o ON o.id = mt.order_id
LEFT JOIN users u ON u.auth_id = COALESCE(mt.user_auth_id, o.user_auth_id)
WHERE mt.status = 'completed'
  AND mt.created_at > NOW() - INTERVAL '7 days'
  AND NOT EXISTS (
    SELECT 1 FROM receipts r WHERE r.transaction_id = mt.transaction_id
  )
ORDER BY mt.created_at DESC;
