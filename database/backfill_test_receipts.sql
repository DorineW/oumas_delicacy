-- ================================================================
-- BACKFILL MISSING RECEIPTS FOR TEST PAYMENTS
-- ================================================================
-- Create receipts for the 2 test payments that just completed
-- ================================================================

-- Create receipts for both test transactions
WITH payments_needing_receipts AS (
    SELECT 
        mt.transaction_id,
        mt.order_id,
        mt.created_at,
        o.subtotal,
        o.tax,
        o.total,
        COALESCE(u.name, 'Customer') as customer_name,
        COALESCE(u.phone, '') as customer_phone,
        COALESCE(u.email, '') as customer_email,
        ROW_NUMBER() OVER (ORDER BY mt.created_at) as row_num
    FROM mpesa_transactions mt
    JOIN orders o ON o.id = mt.order_id
    LEFT JOIN users u ON u.auth_id = COALESCE(mt.user_auth_id, o.user_auth_id)
    WHERE mt.transaction_id IN (
        '4d20015a-dbc8-4a35-be61-0abb39c82c4a',
        'd6837a25-f5bc-45f1-9d75-430ec9d08148'
    )
    AND mt.status = 'completed'
    AND NOT EXISTS (
        SELECT 1 FROM receipts r WHERE r.transaction_id = mt.transaction_id
    )
)
INSERT INTO receipts (
    receipt_number,
    transaction_id,
    receipt_type,
    issue_date,
    customer_name,
    customer_phone,
    customer_email,
    subtotal,
    tax_amount,
    discount_amount,
    total_amount,
    currency,
    payment_method,
    business_name,
    business_email
)
SELECT
    generate_receipt_number(),
    transaction_id,
    'payment',
    created_at,
    customer_name,
    customer_phone,
    customer_email,
    CAST(ROUND(COALESCE(subtotal, 0)) AS INTEGER),
    CAST(ROUND(COALESCE(tax, 0)) AS INTEGER),
    0,
    CAST(ROUND(COALESCE(total, 0)) AS INTEGER),
    'KES',
    'M-Pesa',
    'Ouma''s Delicacy',
    'receipts@oumasdelicacy.com'
FROM payments_needing_receipts
RETURNING receipt_number, transaction_id;

-- Create receipt items
INSERT INTO receipt_items (
    receipt_id,
    item_description,
    quantity,
    unit_price,
    total_price,
    item_code
)
SELECT
    r.id,
    COALESCE(oi.name, 'Item'),
    COALESCE(oi.quantity, 1),
    CAST(ROUND(COALESCE(oi.unit_price, 0)) AS INTEGER),
    CAST(ROUND(COALESCE(oi.total_price, 0)) AS INTEGER),
    COALESCE(oi.item_type, 'ITEM')
FROM receipts r
JOIN mpesa_transactions mt ON mt.transaction_id = r.transaction_id
JOIN order_items oi ON oi.order_id = mt.order_id
WHERE mt.transaction_id IN (
    '4d20015a-dbc8-4a35-be61-0abb39c82c4a',
    'd6837a25-f5bc-45f1-9d75-430ec9d08148'
)
AND r.created_at > NOW() - INTERVAL '5 minutes';

-- Verify
SELECT 
    mt.transaction_id,
    r.receipt_number,
    COUNT(ri.id) as items_count,
    CASE 
        WHEN r.id IS NULL THEN '❌ FAILED'
        WHEN COUNT(ri.id) = 0 THEN '⚠️ NO ITEMS'
        ELSE '✅ SUCCESS'
    END as status
FROM mpesa_transactions mt
LEFT JOIN receipts r ON r.transaction_id = mt.transaction_id
LEFT JOIN receipt_items ri ON ri.receipt_id = r.id
WHERE mt.transaction_id IN (
    '4d20015a-dbc8-4a35-be61-0abb39c82c4a',
    'd6837a25-f5bc-45f1-9d75-430ec9d08148'
)
GROUP BY mt.transaction_id, r.id, r.receipt_number;
