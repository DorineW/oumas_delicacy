-- ================================================================
-- COMPREHENSIVE RECEIPT DIAGNOSTIC - NEW ORDERS
-- ================================================================
-- Check EVERYTHING that could prevent receipt generation
-- ================================================================

-- 1. Check the most recent completed payment
SELECT 
    '1. MOST RECENT PAYMENT' as check_section,
    mt.transaction_id,
    mt.order_id,
    mt.status,
    mt.created_at as payment_time,
    mt.updated_at as payment_updated,
    r.id as receipt_id,
    r.receipt_number,
    r.created_at as receipt_time,
    CASE 
        WHEN r.id IS NULL THEN '❌ NO RECEIPT'
        ELSE '✅ HAS RECEIPT'
    END as status_text
FROM mpesa_transactions mt
LEFT JOIN receipts r ON r.transaction_id = mt.transaction_id
WHERE mt.status = 'completed'
ORDER BY mt.created_at DESC
LIMIT 1;

-- 2. Check if generate_receipt_number function exists and works
SELECT 
    '2. FUNCTION CHECK' as check_section,
    generate_receipt_number() as sample_receipt_number;

-- 3. Check order details for the most recent payment
SELECT 
    '3. ORDER DETAILS' as check_section,
    o.id as order_id,
    o.short_id,
    o.status as order_status,
    o.user_auth_id,
    o.subtotal,
    o.tax,
    o.total,
    o.placed_at,
    u.name as customer_name,
    u.phone as customer_phone,
    u.email as customer_email,
    (SELECT COUNT(*) FROM order_items WHERE order_id = o.id) as items_count
FROM orders o
LEFT JOIN users u ON u.auth_id = o.user_auth_id
WHERE o.id IN (
    SELECT order_id FROM mpesa_transactions 
    WHERE status = 'completed' 
    ORDER BY created_at DESC 
    LIMIT 1
);

-- 4. Check order items for the most recent payment
SELECT 
    '4. ORDER ITEMS' as check_section,
    oi.id,
    oi.name,
    oi.quantity,
    oi.unit_price,
    oi.total_price,
    oi.item_type
FROM order_items oi
WHERE oi.order_id IN (
    SELECT order_id FROM mpesa_transactions 
    WHERE status = 'completed' 
    ORDER BY created_at DESC 
    LIMIT 1
);

-- 5. Check if Edge Function logs show receipt creation attempts
-- (You'll need to check Supabase Edge Function logs manually)

-- 6. Try to manually create a receipt for the most recent payment
-- (DRY RUN - just SELECT to see what would be inserted)
WITH latest_payment AS (
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
    WHERE mt.status = 'completed'
      AND NOT EXISTS (SELECT 1 FROM receipts r WHERE r.transaction_id = mt.transaction_id)
    ORDER BY mt.created_at DESC
    LIMIT 1
)
SELECT
    '6. DRY RUN - What would be inserted' as check_section,
    generate_receipt_number() as receipt_number,
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
    'M-Pesa' as payment_method,
    'Ouma''s Delicacy' as business_name
FROM latest_payment;

-- 7. Check receipts table permissions
SELECT 
    '7. TABLE PERMISSIONS' as check_section,
    tablename,
    has_table_privilege('service_role', schemaname || '.' || tablename, 'INSERT') as can_insert,
    has_table_privilege('service_role', schemaname || '.' || tablename, 'SELECT') as can_select
FROM pg_tables
WHERE schemaname = 'public' 
  AND tablename IN ('receipts', 'receipt_items');

-- 8. Check if there are any recent errors in pg_stat_statements
-- (Requires pg_stat_statements extension)
-- SELECT query, calls, total_time, mean_time
-- FROM pg_stat_statements
-- WHERE query LIKE '%receipts%'
-- ORDER BY last_exec_time DESC
-- LIMIT 5;

-- 9. Count payments without receipts created in last hour
SELECT 
    '9. RECENT MISSING RECEIPTS' as check_section,
    COUNT(*) as count,
    MIN(mt.created_at) as oldest,
    MAX(mt.created_at) as newest
FROM mpesa_transactions mt
WHERE mt.status = 'completed'
  AND mt.created_at > NOW() - INTERVAL '1 hour'
  AND NOT EXISTS (
    SELECT 1 FROM receipts r WHERE r.transaction_id = mt.transaction_id
  );

-- 10. Check if mpesa-query-status function is being called
-- Show last 3 completed transactions and their timing
SELECT 
    '10. PAYMENT TIMING' as check_section,
    mt.transaction_id,
    mt.created_at as payment_created,
    mt.updated_at as payment_updated,
    EXTRACT(EPOCH FROM (mt.updated_at - mt.created_at)) as seconds_to_complete,
    r.created_at as receipt_created,
    CASE 
        WHEN r.id IS NULL THEN NULL
        ELSE EXTRACT(EPOCH FROM (r.created_at - mt.updated_at))
    END as seconds_payment_to_receipt
FROM mpesa_transactions mt
LEFT JOIN receipts r ON r.transaction_id = mt.transaction_id
WHERE mt.status = 'completed'
ORDER BY mt.created_at DESC
LIMIT 3;
