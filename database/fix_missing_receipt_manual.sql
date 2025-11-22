-- ================================================================
-- MANUALLY CREATE RECEIPT FOR LATEST PAYMENT
-- ================================================================
-- Transaction: TXN-1763751066745-ksmr4le (2025-11-21 18:51:06)
-- ================================================================

-- Step 1: Create the receipt
WITH payment_data AS (
    SELECT 
        mt.transaction_id,
        mt.order_id,
        mt.created_at,
        o.subtotal,
        o.tax,
        o.total,
        COALESCE(u.name, 'Customer') as customer_name,
        COALESCE(u.phone, '') as customer_phone,
        COALESCE(u.email, '') as customer_email
    FROM mpesa_transactions mt
    JOIN orders o ON o.id = mt.order_id
    LEFT JOIN users u ON u.auth_id = COALESCE(mt.user_auth_id, o.user_auth_id)
    WHERE mt.transaction_id = 'TXN-1763751066745-ksmr4le'
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
FROM payment_data
RETURNING id, receipt_number;

-- Step 2: Create receipt items
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
WHERE r.transaction_id = 'TXN-1763751066745-ksmr4le';

-- Step 3: Verify
SELECT 
    r.receipt_number,
    r.transaction_id,
    r.total_amount,
    COUNT(ri.id) as items_count
FROM receipts r
LEFT JOIN receipt_items ri ON ri.receipt_id = r.id
WHERE r.transaction_id = 'TXN-1763751066745-ksmr4le'
GROUP BY r.id, r.receipt_number, r.transaction_id, r.total_amount;
