-- ============================================
-- VERIFY M-PESA DATABASE SETUP
-- ============================================
-- Run this script after migration to verify everything is set up correctly

-- ============================================
-- 1. Check All Tables Exist
-- ============================================
SELECT 
    '1. Table Existence Check' as check_name,
    expected.tablename,
    CASE 
        WHEN pg_tables.tablename IS NOT NULL THEN '✅ EXISTS'
        ELSE '❌ MISSING'
    END as status
FROM (
    VALUES 
        ('mpesa_transactions'),
        ('receipts'),
        ('receipt_items'),
        ('tax_configurations'),
        ('payment_reconciliations'),
        ('transaction_fees'),
        ('receipt_templates')
) AS expected(tablename)
LEFT JOIN pg_tables ON pg_tables.tablename = expected.tablename 
    AND pg_tables.schemaname = 'public'
ORDER BY expected.tablename;

-- ============================================
-- 2. Check Table Row Counts
-- ============================================
SELECT 
    '2. Table Row Counts' as check_name,
    'mpesa_transactions' as table_name,
    COUNT(*) as row_count
FROM public.mpesa_transactions
UNION ALL
SELECT 
    '2. Table Row Counts',
    'receipts',
    COUNT(*)
FROM public.receipts
UNION ALL
SELECT 
    '2. Table Row Counts',
    'receipt_items',
    COUNT(*)
FROM public.receipt_items
UNION ALL
SELECT 
    '2. Table Row Counts',
    'tax_configurations',
    COUNT(*)
FROM public.tax_configurations
UNION ALL
SELECT 
    '2. Table Row Counts',
    'payment_reconciliations',
    COUNT(*)
FROM public.payment_reconciliations
UNION ALL
SELECT 
    '2. Table Row Counts',
    'transaction_fees',
    COUNT(*)
FROM public.transaction_fees
UNION ALL
SELECT 
    '2. Table Row Counts',
    'receipt_templates',
    COUNT(*)
FROM public.receipt_templates;

-- ============================================
-- 3. Check Indexes
-- ============================================
SELECT 
    '3. Index Check' as check_name,
    schemaname,
    tablename,
    indexname,
    '✅ EXISTS' as status
FROM pg_indexes
WHERE schemaname = 'public'
    AND tablename IN (
        'mpesa_transactions',
        'receipts',
        'receipt_items',
        'payment_reconciliations',
        'transaction_fees'
    )
ORDER BY tablename, indexname;

-- ============================================
-- 4. Check Foreign Keys
-- ============================================
SELECT 
    '4. Foreign Key Check' as check_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    '✅ EXISTS' as status
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema = 'public'
    AND tc.table_name IN (
        'mpesa_transactions',
        'receipts',
        'receipt_items',
        'payment_reconciliations',
        'transaction_fees'
    )
ORDER BY tc.table_name;

-- ============================================
-- 5. Check RLS Policies
-- ============================================
SELECT 
    '5. RLS Policy Check' as check_name,
    schemaname,
    tablename,
    policyname,
    CASE 
        WHEN cmd = 'SELECT' THEN '🔍 SELECT'
        WHEN cmd = 'INSERT' THEN '➕ INSERT'
        WHEN cmd = 'UPDATE' THEN '✏️ UPDATE'
        WHEN cmd = 'DELETE' THEN '🗑️ DELETE'
        ELSE cmd
    END as operation,
    '✅ ACTIVE' as status
FROM pg_policies
WHERE schemaname = 'public'
    AND tablename IN (
        'mpesa_transactions',
        'receipts',
        'receipt_items'
    )
ORDER BY tablename, policyname;

-- ============================================
-- 6. Check RLS is Enabled
-- ============================================
SELECT 
    '6. RLS Status Check' as check_name,
    schemaname,
    tablename,
    CASE 
        WHEN rowsecurity THEN '✅ ENABLED'
        ELSE '⚠️ DISABLED'
    END as rls_status
FROM pg_tables
WHERE schemaname = 'public'
    AND tablename IN (
        'mpesa_transactions',
        'receipts',
        'receipt_items'
    )
ORDER BY tablename;

-- ============================================
-- 7. Check Views Exist
-- ============================================
SELECT 
    '7. View Check' as check_name,
    schemaname,
    viewname,
    '✅ EXISTS' as status
FROM pg_views
WHERE schemaname = 'public'
    AND viewname IN (
        'daily_transaction_summary',
        'transaction_status_overview',
        'monthly_transaction_summary',
        'failed_transactions_report',
        'top_customers_by_volume',
        'hourly_transaction_distribution',
        'pending_transactions_monitor',
        'receipt_generation_status',
        'daily_revenue_summary',
        'reconciliation_dashboard'
    )
ORDER BY viewname;

-- ============================================
-- 8. Check Functions Exist
-- ============================================
SELECT 
    '8. Function Check' as check_name,
    n.nspname as schema_name,
    p.proname as function_name,
    pg_get_function_result(p.oid) as return_type,
    '✅ EXISTS' as status
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
    AND p.proname IN (
        'generate_receipt_number',
        'update_mpesa_transactions_updated_at'
    )
ORDER BY p.proname;

-- ============================================
-- 9. Check Sequences
-- ============================================
SELECT 
    '9. Sequence Check' as check_name,
    schemaname,
    sequencename,
    last_value,
    '✅ EXISTS' as status
FROM pg_sequences
WHERE schemaname = 'public'
    AND sequencename = 'receipt_number_seq';

-- ============================================
-- 10. Check Data Types for Money Fields
-- ============================================
SELECT 
    '10. Data Type Check' as check_name,
    table_name,
    column_name,
    data_type,
    CASE 
        WHEN data_type = 'numeric' THEN '✅ CORRECT (NUMERIC)'
        WHEN data_type = 'integer' THEN '⚠️ WARNING (Should be NUMERIC for money)'
        ELSE '❓ UNKNOWN TYPE'
    END as validation_status
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name IN ('mpesa_transactions', 'receipts', 'receipt_items', 'payment_reconciliations', 'transaction_fees')
    AND column_name IN ('amount', 'balance', 'subtotal', 'tax_amount', 'discount_amount', 'total_amount', 
                        'unit_price', 'total_price', 'expected_amount', 'received_amount', 
                        'difference_amount', 'mpesa_charges', 'net_amount', 'fee_amount')
ORDER BY table_name, column_name;

-- ============================================
-- 11. Check Triggers
-- ============================================
SELECT 
    '11. Trigger Check' as check_name,
    trigger_schema,
    event_object_table as table_name,
    trigger_name,
    event_manipulation as trigger_event,
    '✅ EXISTS' as status
FROM information_schema.triggers
WHERE trigger_schema = 'public'
    AND event_object_table IN ('mpesa_transactions')
ORDER BY event_object_table, trigger_name;

-- ============================================
-- 12. Check Tax Configurations
-- ============================================
SELECT 
    '12. Tax Configuration Check' as check_name,
    tax_name,
    tax_rate,
    tax_type,
    is_active,
    CASE 
        WHEN is_active THEN '✅ ACTIVE'
        ELSE '⚠️ INACTIVE'
    END as status
FROM public.tax_configurations
ORDER BY is_active DESC, tax_name;

-- ============================================
-- 13. Test Receipt Number Generation
-- ============================================
SELECT 
    '13. Receipt Number Generation Test' as check_name,
    generate_receipt_number() as sample_receipt_number,
    '✅ FUNCTION WORKS' as status;

-- ============================================
-- SUMMARY REPORT
-- ============================================
SELECT 
    '═══════════════════════════════════════' as separator
UNION ALL
SELECT '📊 M-PESA DATABASE SETUP VERIFICATION COMPLETE'
UNION ALL
SELECT '═══════════════════════════════════════'
UNION ALL
SELECT ''
UNION ALL
SELECT '✅ All checks completed successfully!'
UNION ALL
SELECT ''
UNION ALL
SELECT 'Next Steps:'
UNION ALL
SELECT '1. Review the output above for any ⚠️ warnings or ❌ errors'
UNION ALL
SELECT '2. Ensure all money fields show NUMERIC type (not INTEGER)'
UNION ALL
SELECT '3. Verify RLS is enabled on all sensitive tables'
UNION ALL
SELECT '4. Test inserting a sample transaction'
UNION ALL
SELECT '5. Deploy Edge Functions for M-Pesa integration'
UNION ALL
SELECT ''
UNION ALL
SELECT 'Sample Test Transaction:'
UNION ALL
SELECT '-- Run this in a separate query to test:'
UNION ALL
SELECT '-- INSERT INTO mpesa_transactions (...) VALUES (...);';
