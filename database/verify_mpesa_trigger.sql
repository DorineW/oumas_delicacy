-- ================================================================
-- VERIFY M-PESA ORDER TRIGGER
-- ================================================================
-- Check if trigger exists and is working
-- ================================================================

-- 1. Check if trigger exists
SELECT 
    tgname as trigger_name,
    tgenabled as enabled,
    pg_get_triggerdef(oid) as trigger_definition
FROM pg_trigger
WHERE tgname = 'trg_update_order_status_on_payment';

-- 2. Check recent M-Pesa transactions
SELECT 
    mt.id,
    mt.transaction_id,
    mt.order_id,
    mt.status as payment_status,
    mt.amount,
    mt.created_at,
    o.short_id as order_number,
    o.status as order_status,
    o.total as order_total
FROM mpesa_transactions mt
LEFT JOIN orders o ON o.id = mt.order_id
ORDER BY mt.created_at DESC
LIMIT 10;

-- 3. Check for orders with completed payments but still pending_payment status
SELECT 
    o.id,
    o.short_id as order_number,
    o.status as order_status,
    o.total,
    o.placed_at,
    mt.transaction_id,
    mt.status as payment_status,
    mt.created_at as payment_time
FROM orders o
JOIN mpesa_transactions mt ON mt.order_id = o.id
WHERE mt.status = 'completed' 
  AND o.status = 'pending_payment'
ORDER BY o.placed_at DESC;
