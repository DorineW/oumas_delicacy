-- Check specific transaction and why it has no receipt
SELECT 
    'Transaction Info' as section,
    mt.transaction_id,
    mt.mpesa_receipt_number,
    mt.phone_number,
    mt.amount,
    mt.status,
    mt.order_id,
    mt.created_at as transaction_time
FROM mpesa_transactions mt
WHERE mt.transaction_id = 'TXN-1763753984913-1yzv6xm'

UNION ALL

SELECT 
    'Receipt Info' as section,
    r.receipt_number::text as transaction_id,
    r.transaction_id as mpesa_receipt_number,
    NULL as phone_number,
    r.total_amount,
    NULL as status,
    NULL as order_id,
    r.issue_date as transaction_time
FROM receipts r
WHERE r.transaction_id = 'TXN-1763753984913-1yzv6xm'

UNION ALL

SELECT 
    'Order Info' as section,
    o.id::text,
    o.status::text,
    NULL,
    o.total_amount,
    NULL,
    NULL,
    o.order_date
FROM orders o
WHERE o.id = '29cf3659-34ca-436c-b746-33eecfbd8bb9';
