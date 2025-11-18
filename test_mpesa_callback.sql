-- Test M-Pesa Callback Simulator
-- This simulates a successful M-Pesa payment callback for testing
-- Replace 'YOUR_CHECKOUT_REQUEST_ID' with the actual checkout request ID from your test

-- Step 1: Find the latest pending transaction
SELECT 
    id,
    checkout_request_id,
    phone_number,
    amount,
    status,
    created_at
FROM mpesa_transactions 
WHERE status = 'pending'
ORDER BY created_at DESC
LIMIT 5;

-- Step 2: Update a specific transaction to 'completed' (replace the ID)
-- UPDATE mpesa_transactions
-- SET 
--     status = 'completed',
--     mpesa_receipt_number = 'TEST' || FLOOR(RANDOM() * 1000000000)::TEXT,
--     result_code = '0',
--     result_desc = 'The service request is processed successfully.',
--     updated_at = NOW()
-- WHERE checkout_request_id = 'YOUR_CHECKOUT_REQUEST_ID';

-- Step 3: Verify the update
-- SELECT * FROM mpesa_transactions 
-- WHERE checkout_request_id = 'YOUR_CHECKOUT_REQUEST_ID';

-- Usage Instructions:
-- 1. Copy the checkout_request_id from the Flutter app logs (e.g., ws_CO_17112025231413501708374149)
-- 2. Replace 'YOUR_CHECKOUT_REQUEST_ID' in the UPDATE statement above
-- 3. Uncomment the UPDATE and verification SELECT statements
-- 4. Run this in Supabase SQL Editor
-- 5. The Flutter app should immediately detect the status change via real-time Stream
