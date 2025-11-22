-- Check the most recent completed M-Pesa transaction
SELECT 
    mt.checkout_request_id,
    mt.status,
    mt.transaction_id,
    mt.amount,
    mt.order_id,
    mt.result_code,
    mt.result_desc,
    mt.created_at,
    mt.updated_at
FROM mpesa_transactions mt
WHERE mt.status = 'completed'
ORDER BY mt.updated_at DESC
LIMIT 1;

-- Check if a receipt exists for the most recent completed transaction
SELECT 
    r.receipt_number,
    r.transaction_id,
    r.customer_name,
    r.customer_phone,
    r.subtotal,
    r.tax_amount,
    r.total_amount,
    r.issue_date,
    COUNT(ri.id) as item_count
FROM receipts r
LEFT JOIN receipt_items ri ON r.id = ri.receipt_id
WHERE r.transaction_id = (
    SELECT transaction_id 
    FROM mpesa_transactions 
    WHERE status = 'completed'
    ORDER BY updated_at DESC 
    LIMIT 1
)
GROUP BY r.id;

-- If no receipt exists, check the order details to prepare for manual receipt creation
SELECT 
    o.id as order_id,
    o.short_id,
    o.total,
    o.subtotal,
    o.tax,
    o.status,
    u.full_name,
    u.phone,
    u.email,
    mt.transaction_id,
    COUNT(oi.id) as item_count
FROM orders o
JOIN users u ON o.customer_id = u.auth_id
JOIN mpesa_transactions mt ON mt.order_id = o.id
LEFT JOIN order_items oi ON oi.order_id = o.id
WHERE mt.status = 'completed'
AND o.id = (
    SELECT order_id 
    FROM mpesa_transactions 
    WHERE status = 'completed'
    ORDER BY updated_at DESC 
    LIMIT 1
)
GROUP BY o.id, u.id, mt.transaction_id;
