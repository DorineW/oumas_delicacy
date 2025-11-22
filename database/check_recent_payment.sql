-- Check the specific transaction that was just processed
SELECT 
    id,
    checkout_request_id,
    status,
    result_code,
    result_desc,
    transaction_id as mpesa_receipt,
    amount,
    phone_number,
    order_id,
    created_at,
    updated_at
FROM mpesa_transactions 
WHERE checkout_request_id = 'ws_CO_18112025184001763700182990';

-- Check if there's a linked order and its status
SELECT 
    o.id,
    o.short_id,
    o.status as order_status,
    o.total,
    mt.status as payment_status,
    mt.result_code,
    mt.result_desc,
    mt.transaction_id as mpesa_receipt
FROM orders o
LEFT JOIN mpesa_transactions mt ON mt.order_id = o.id
WHERE mt.checkout_request_id = 'ws_CO_18112025184001763700182990';

-- If the payment actually succeeded but shows as failed, run this fix:
-- (Only uncomment if you confirmed the M-Pesa SMS says payment was successful)
/*
UPDATE mpesa_transactions
SET 
    status = 'completed',
    result_code = '0',
    result_desc = 'The service request is processed successfully.',
    updated_at = NOW()
WHERE checkout_request_id = 'ws_CO_18112025184001763700182990'
  AND result_code != '0';

-- Also update the order
UPDATE orders
SET 
    status = 'paid',
    updated_at = NOW()
WHERE id = (
    SELECT order_id 
    FROM mpesa_transactions 
    WHERE checkout_request_id = 'ws_CO_18112025184001763700182990'
)
AND status = 'pending_payment';

-- Verify the updates
SELECT * FROM mpesa_transactions WHERE checkout_request_id = 'ws_CO_18112025184001763700182990';
SELECT o.*, mt.status as payment_status FROM orders o 
JOIN mpesa_transactions mt ON mt.order_id = o.id 
WHERE mt.checkout_request_id = 'ws_CO_18112025184001763700182990';
*/
