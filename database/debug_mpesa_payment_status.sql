-- Debug M-Pesa Transaction Status
-- Run this to check what happened with the recent payment

-- 1. Check the most recent M-Pesa transaction
SELECT 
    id,
    checkout_request_id,
    merchant_request_id,
    phone_number,
    amount,
    status,
    result_code,
    result_desc,
    transaction_id as mpesa_receipt_number,
    order_id,
    created_at,
    updated_at,
    transaction_timestamp
FROM mpesa_transactions 
ORDER BY created_at DESC
LIMIT 5;

-- 2. Check if there's an order linked to the transaction
SELECT 
    mt.checkout_request_id,
    mt.status as transaction_status,
    mt.result_code,
    mt.result_desc,
    mt.transaction_id as mpesa_receipt,
    o.id as order_id,
    o.short_id as order_number,
    o.status as order_status,
    o.total as order_total,
    mt.amount as paid_amount
FROM mpesa_transactions mt
LEFT JOIN orders o ON o.id = mt.order_id
WHERE mt.checkout_request_id = 'ws_CO_18112025184001763700182990'  -- Replace with your checkout request ID
ORDER BY mt.created_at DESC;

-- 3. Check for any recent successful payments without orders
SELECT 
    mt.id,
    mt.checkout_request_id,
    mt.status,
    mt.result_code,
    mt.transaction_id as mpesa_receipt,
    mt.amount,
    mt.order_id,
    mt.created_at
FROM mpesa_transactions mt
WHERE mt.status = 'completed' 
  AND mt.result_code = '0'
  AND mt.created_at > NOW() - INTERVAL '1 hour'
ORDER BY mt.created_at DESC;

-- 4. Check M-Pesa callback logs (if you have edge function logs enabled)
-- Go to Supabase Dashboard > Edge Functions > mpesa-callback > Logs
-- Look for the callback data from Safaricom

-- 5. If payment was successful but showing as failed, manually fix it:
-- Uncomment and run this (replace the checkout_request_id):
/*
UPDATE mpesa_transactions
SET 
    status = 'completed',
    result_code = '0',
    result_desc = 'The service request is processed successfully.',
    updated_at = NOW()
WHERE checkout_request_id = 'ws_CO_18112025184001763700182990';

-- Also update the order status if needed
UPDATE orders
SET status = 'paid'
WHERE id = (
    SELECT order_id 
    FROM mpesa_transactions 
    WHERE checkout_request_id = 'ws_CO_18112025184001763700182990'
);
*/
