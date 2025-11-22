-- ================================================================
-- CHECK RECEIPT GENERATION SYSTEM
-- ================================================================
-- Diagnose why receipts aren't being created
-- ================================================================

-- 1. Check if generate_receipt_number function exists
SELECT 
    p.proname as function_name,
    pg_get_functiondef(p.oid) as function_definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' 
  AND p.proname = 'generate_receipt_number';

-- 2. Check recent M-Pesa transactions that should have receipts
SELECT 
    mt.id,
    mt.transaction_id,
    mt.order_id,
    mt.status as payment_status,
    mt.created_at as payment_time,
    r.id as receipt_id,
    r.receipt_number,
    r.created_at as receipt_time,
    CASE 
        WHEN r.id IS NULL THEN '❌ NO RECEIPT'
        ELSE '✅ HAS RECEIPT'
    END as receipt_status
FROM mpesa_transactions mt
LEFT JOIN receipts r ON r.transaction_id = mt.transaction_id
WHERE mt.status = 'completed'
  AND mt.created_at > NOW() - INTERVAL '24 hours'
ORDER BY mt.created_at DESC
LIMIT 20;

-- 3. Check if receipts table has correct foreign key constraint
SELECT
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_name = 'receipts'
    AND kcu.column_name = 'transaction_id';

-- 4. Check receipts table structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'receipts'
ORDER BY ordinal_position;

-- 5. Test if we can manually insert a receipt for the latest completed transaction
-- (This is just a SELECT to show what would be inserted - don't actually insert)
SELECT 
    'RCP-TEST-' || mt.id as receipt_number,
    mt.transaction_id,
    'payment' as receipt_type,
    NOW() as issue_date,
    u.name as customer_name,
    u.phone as customer_phone,
    u.email as customer_email,
    CAST(o.subtotal AS INTEGER) as subtotal,
    CAST(COALESCE(o.tax, 0) AS INTEGER) as tax_amount,
    0 as discount_amount,
    CAST(o.total AS INTEGER) as total_amount,
    'KES' as currency,
    'M-Pesa' as payment_method,
    'Ouma''s Delicacy' as business_name
FROM mpesa_transactions mt
JOIN orders o ON o.id = mt.order_id
JOIN users u ON u.auth_id = mt.user_auth_id
WHERE mt.status = 'completed'
  AND NOT EXISTS (
    SELECT 1 FROM receipts r WHERE r.transaction_id = mt.transaction_id
  )
ORDER BY mt.created_at DESC
LIMIT 1;
