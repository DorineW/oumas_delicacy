-- Check recent completed orders and their receipts
SELECT 
    o.id as order_id,
    o.status,
    o.order_date as order_time,
    mt.transaction_id,
    mt.status as payment_status,
    r.receipt_number,
    r.id as receipt_id,
    CASE 
        WHEN r.id IS NOT NULL THEN 'Has Receipt'
        WHEN mt.status = 'completed' THEN 'Payment Complete - NO RECEIPT'
        WHEN mt.status IS NOT NULL THEN 'Payment: ' || mt.status
        ELSE 'No Payment'
    END as receipt_status
FROM orders o
LEFT JOIN mpesa_transactions mt ON o.id = mt.order_id
LEFT JOIN receipts r ON mt.transaction_id = r.transaction_id
WHERE o.user_auth_id = '8d8a4e83-9e74-4416-a189-1ebf6de728ab'
  AND o.order_date > NOW() - INTERVAL '7 days'
ORDER BY o.order_date DESC
LIMIT 10;
