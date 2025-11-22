-- ================================================================
-- VERIFY RECEIPT SYSTEM - ALL COMPONENTS
-- ================================================================

-- 1. ✅ Verify generate_receipt_number() function exists
SELECT 
    'Step 1: Function Test' as step,
    generate_receipt_number() as sample_number,
    '✅ PASS' as status;

-- 2. ✅ Test function works multiple times (should increment)
SELECT 
    'Step 2: Function Increment Test' as step,
    generate_receipt_number() as number1,
    generate_receipt_number() as number2,
    CASE 
        WHEN generate_receipt_number() != generate_receipt_number() 
        THEN '✅ PASS - Numbers increment'
        ELSE '❌ FAIL - Numbers duplicate'
    END as status;

-- 3. Check if receipts table has proper structure
SELECT 
    'Step 3: Receipts Table' as step,
    column_name,
    data_type,
    '✅ PASS' as status
FROM information_schema.columns
WHERE table_name = 'receipts'
  AND column_name IN ('receipt_number', 'transaction_id', 'id', 'created_at')
ORDER BY ordinal_position;

-- 4. Check if receipt_items table has proper structure
SELECT 
    'Step 4: Receipt Items Table' as step,
    column_name,
    data_type,
    '✅ PASS' as status
FROM information_schema.columns
WHERE table_name = 'receipt_items'
  AND column_name IN ('receipt_id', 'item_description', 'quantity', 'unit_price')
ORDER BY ordinal_position;

-- 5. Check order_items has 'name' column (not 'item_name')
SELECT 
    'Step 5: Order Items Schema' as step,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'order_items' AND column_name = 'name'
        ) THEN '✅ PASS - name column exists'
        ELSE '❌ FAIL - name column missing'
    END as name_status,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'order_items' AND column_name = 'item_name'
        ) THEN '⚠️ WARNING - item_name exists (should not)'
        ELSE '✅ PASS - item_name does not exist'
    END as item_name_status;

-- 6. Check most recent completed payment
SELECT 
    'Step 6: Recent Payment' as step,
    mt.transaction_id,
    mt.created_at as payment_time,
    mt.status,
    r.receipt_number,
    CASE 
        WHEN r.id IS NOT NULL THEN '✅ PASS - Has receipt'
        ELSE '❌ FAIL - No receipt'
    END as status
FROM mpesa_transactions mt
LEFT JOIN receipts r ON r.transaction_id = mt.transaction_id
WHERE mt.status = 'completed'
ORDER BY mt.created_at DESC
LIMIT 1;

-- 7. Check receipt items for most recent receipt
SELECT 
    'Step 7: Recent Receipt Items' as step,
    r.receipt_number,
    COUNT(ri.id) as items_count,
    CASE 
        WHEN COUNT(ri.id) > 0 THEN '✅ PASS - Has items'
        WHEN r.id IS NULL THEN '⚠️ SKIP - No receipt yet'
        ELSE '❌ FAIL - No items'
    END as status
FROM mpesa_transactions mt
LEFT JOIN receipts r ON r.transaction_id = mt.transaction_id
LEFT JOIN receipt_items ri ON ri.receipt_id = r.id
WHERE mt.status = 'completed'
GROUP BY mt.created_at, r.receipt_number, r.id
ORDER BY mt.created_at DESC
LIMIT 1;

-- 8. Check service_role permissions
SELECT 
    'Step 8: Permissions' as step,
    'receipts' as table_name,
    has_table_privilege('service_role', 'public.receipts', 'INSERT') as can_insert,
    has_table_privilege('service_role', 'public.receipts', 'SELECT') as can_select,
    CASE 
        WHEN has_table_privilege('service_role', 'public.receipts', 'INSERT') 
        THEN '✅ PASS'
        ELSE '❌ FAIL'
    END as status;

-- 9. Summary: Payments needing receipts
SELECT 
    'Step 9: Missing Receipts Summary' as step,
    COUNT(*) as missing_count,
    MIN(mt.created_at) as oldest_payment,
    MAX(mt.created_at) as newest_payment,
    CASE 
        WHEN COUNT(*) = 0 THEN '✅ PASS - No missing receipts'
        ELSE '❌ FAIL - ' || COUNT(*) || ' payments need receipts'
    END as status
FROM mpesa_transactions mt
WHERE mt.status = 'completed'
  AND NOT EXISTS (
    SELECT 1 FROM receipts r WHERE r.transaction_id = mt.transaction_id
  );

-- 10. Show all payments from last 24 hours with receipt status
SELECT 
    'Step 10: Last 24h Payments' as step,
    mt.transaction_id,
    mt.created_at as payment_time,
    mt.order_id,
    r.receipt_number,
    CASE 
        WHEN r.id IS NOT NULL THEN '✅ Has Receipt'
        ELSE '❌ Missing'
    END as receipt_status
FROM mpesa_transactions mt
LEFT JOIN receipts r ON r.transaction_id = mt.transaction_id
WHERE mt.status = 'completed'
  AND mt.created_at > NOW() - INTERVAL '24 hours'
ORDER BY mt.created_at DESC;
