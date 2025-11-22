-- ================================================================
-- DIAGNOSE RECEIPT GENERATION ISSUE
-- ================================================================
-- Find out exactly why receipts aren't being created
-- ================================================================

-- 1. Check if generate_receipt_number function exists and its return type
SELECT 
    p.proname as function_name,
    pg_get_function_result(p.oid) as return_type,
    pg_get_functiondef(p.oid) as definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' 
  AND p.proname = 'generate_receipt_number';

-- 2. Check completed payments WITHOUT receipts (the problem cases)
SELECT 
    mt.id,
    mt.transaction_id,
    mt.order_id,
    mt.user_auth_id,
    mt.status,
    mt.created_at,
    o.short_id as order_number,
    o.status as order_status,
    u.name as customer_name,
    u.phone as customer_phone,
    u.email as customer_email,
    o.subtotal,
    o.tax,
    o.total,
    -- Check if order has items
    (SELECT COUNT(*) FROM order_items oi WHERE oi.order_id = o.id) as items_count,
    -- Check if receipt exists
    r.id as receipt_id,
    CASE 
        WHEN r.id IS NULL THEN '❌ NO RECEIPT'
        ELSE '✅ HAS RECEIPT'
    END as receipt_status
FROM mpesa_transactions mt
LEFT JOIN orders o ON o.id = mt.order_id
LEFT JOIN users u ON u.auth_id = mt.user_auth_id
LEFT JOIN receipts r ON r.transaction_id = mt.transaction_id
WHERE mt.status = 'completed'
  AND mt.created_at > NOW() - INTERVAL '7 days'
ORDER BY mt.created_at DESC;

-- 3. Check for data quality issues that might prevent receipt creation
SELECT 
    'Missing Order' as issue,
    COUNT(*) as count
FROM mpesa_transactions mt
WHERE mt.status = 'completed'
  AND mt.order_id IS NULL
  AND mt.created_at > NOW() - INTERVAL '7 days'

UNION ALL

SELECT 
    'Missing User' as issue,
    COUNT(*) as count
FROM mpesa_transactions mt
WHERE mt.status = 'completed'
  AND mt.user_auth_id IS NULL
  AND mt.created_at > NOW() - INTERVAL '7 days'

UNION ALL

SELECT 
    'Order Missing User Link' as issue,
    COUNT(*) as count
FROM mpesa_transactions mt
JOIN orders o ON o.id = mt.order_id
WHERE mt.status = 'completed'
  AND o.user_auth_id IS NULL
  AND mt.created_at > NOW() - INTERVAL '7 days'

UNION ALL

SELECT 
    'Order Has No Items' as issue,
    COUNT(*) as count
FROM mpesa_transactions mt
JOIN orders o ON o.id = mt.order_id
WHERE mt.status = 'completed'
  AND NOT EXISTS (SELECT 1 FROM order_items oi WHERE oi.order_id = o.id)
  AND mt.created_at > NOW() - INTERVAL '7 days'

UNION ALL

SELECT 
    'User Has No Name' as issue,
    COUNT(*) as count
FROM mpesa_transactions mt
JOIN users u ON u.auth_id = mt.user_auth_id
WHERE mt.status = 'completed'
  AND (u.name IS NULL OR u.name = '')
  AND mt.created_at > NOW() - INTERVAL '7 days'

UNION ALL

SELECT 
    'User Has No Phone' as issue,
    COUNT(*) as count
FROM mpesa_transactions mt
JOIN users u ON u.auth_id = mt.user_auth_id
WHERE mt.status = 'completed'
  AND (u.phone IS NULL OR u.phone = '')
  AND mt.created_at > NOW() - INTERVAL '7 days';

-- 4. Test a single receipt creation (DRY RUN - just SELECT, no INSERT)
SELECT 
    'RCP-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-TEST' as receipt_number,
    mt.transaction_id,
    'payment' as receipt_type,
    mt.created_at as issue_date,
    COALESCE(u.name, 'Customer') as customer_name,
    COALESCE(u.phone, '') as customer_phone,
    COALESCE(u.email, '') as customer_email,
    CAST(ROUND(o.subtotal) AS INTEGER) as subtotal,
    CAST(ROUND(COALESCE(o.tax, 0)) AS INTEGER) as tax_amount,
    0 as discount_amount,
    CAST(ROUND(o.total) AS INTEGER) as total_amount,
    'KES' as currency,
    'M-Pesa' as payment_method,
    'Ouma''s Delicacy' as business_name,
    NULL::TEXT as business_address,
    NULL::TEXT as business_phone,
    'receipts@oumasdelicacy.com' as business_email
FROM mpesa_transactions mt
JOIN orders o ON o.id = mt.order_id
JOIN users u ON u.auth_id = mt.user_auth_id
WHERE mt.status = 'completed'
  AND NOT EXISTS (SELECT 1 FROM receipts r WHERE r.transaction_id = mt.transaction_id)
ORDER BY mt.created_at DESC
LIMIT 1;

-- 5. Check the receipts table structure for any issues
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'receipts'
ORDER BY ordinal_position;

-- 6. Check receipt_items table structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'receipt_items'
ORDER BY ordinal_position;
