-- ================================================================
-- SIMPLE CHECK: Which payments have receipts?
-- ================================================================

-- Check all completed payments and their receipt status
SELECT 
    mt.transaction_id,
    mt.order_id,
    mt.created_at as payment_time,
    r.receipt_number,
    CASE 
        WHEN r.id IS NULL THEN '❌ NO RECEIPT'
        ELSE '✅ HAS RECEIPT'
    END as status
FROM mpesa_transactions mt
LEFT JOIN receipts r ON r.transaction_id = mt.transaction_id
WHERE mt.status = 'completed'
  AND mt.created_at > NOW() - INTERVAL '7 days'
ORDER BY mt.created_at DESC;
