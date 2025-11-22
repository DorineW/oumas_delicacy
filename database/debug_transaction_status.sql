-- ================================================================
-- DEBUG: CHECK WHAT'S ACTUALLY IN THE DATABASE
-- ================================================================

-- 1. Check if these transactions even exist
SELECT 
    '1. Do transactions exist?' as check_name,
    mt.transaction_id,
    mt.status,
    mt.result_code,
    mt.created_at,
    mt.order_id
FROM mpesa_transactions mt
WHERE mt.transaction_id IN (
    '4d20015a-dbc8-4a35-be61-0abb39c82c4a',
    'd6837a25-f5bc-45f1-9d75-430ec9d08148'
)
ORDER BY mt.created_at DESC;

-- 2. Check ALL completed transactions in last hour
SELECT 
    '2. All recent completed' as check_name,
    mt.transaction_id,
    mt.status,
    mt.created_at,
    EXISTS (SELECT 1 FROM receipts WHERE transaction_id = mt.transaction_id) as has_receipt
FROM mpesa_transactions mt
WHERE mt.created_at > NOW() - INTERVAL '1 hour'
ORDER BY mt.created_at DESC;

-- 3. If they're not completed, what status are they?
SELECT 
    '3. Transaction status breakdown' as check_name,
    status,
    COUNT(*) as count
FROM mpesa_transactions
WHERE created_at > NOW() - INTERVAL '1 hour'
GROUP BY status;

-- 4. Check by checkout_request_id instead
SELECT 
    '4. By checkout request ID' as check_name,
    mt.*
FROM mpesa_transactions mt
WHERE mt.checkout_request_id IN (
    'ws_CO_21112025220548468700182990',
    'ws_CO_21112025220609912700182990'
);
