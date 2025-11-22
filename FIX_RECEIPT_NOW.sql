-- Simple direct INSERT for the missing receipt
-- Run this in Supabase SQL Editor

DO $$
DECLARE
    v_receipt_number VARCHAR;
    v_receipt_id UUID;
BEGIN
    -- Generate receipt number
    v_receipt_number := generate_receipt_number();
    v_receipt_id := gen_random_uuid();
    
    RAISE NOTICE 'Creating receipt % for transaction TXN-1763753984913-1yzv6xm', v_receipt_number;
    
    -- Insert receipt (calculate subtotal from order items)
    INSERT INTO receipts (
        id,
        receipt_number,
        transaction_id,
        receipt_type,
        issue_date,
        customer_name,
        customer_phone,
        subtotal,
        tax_amount,
        discount_amount,
        total_amount,
        payment_method,
        currency,
        business_name,
        business_address,
        business_phone
    )
    SELECT 
        v_receipt_id,
        v_receipt_number,
        mt.transaction_id,
        'payment',
        mt.created_at,
        COALESCE(u.name, 'Customer'),
        mt.phone_number,
        mt.amount,
        0,
        0,
        mt.amount,
        'M-Pesa',
        'KES',
        'Oumas Delicacy',
        'Nairobi, Kenya',
        '+254700000000'
    FROM mpesa_transactions mt
    LEFT JOIN users u ON mt.user_auth_id = u.auth_id
    WHERE mt.transaction_id = 'TXN-1763753984913-1yzv6xm';
    
    -- Insert receipt items
    INSERT INTO receipt_items (
        id,
        receipt_id,
        item_description,
        quantity,
        unit_price,
        total_price
    )
    SELECT 
        gen_random_uuid(),
        v_receipt_id,
        oi.name,
        oi.quantity,
        oi.unit_price,
        oi.quantity * oi.unit_price
    FROM mpesa_transactions mt
    JOIN order_items oi ON oi.order_id = mt.order_id
    WHERE mt.transaction_id = 'TXN-1763753984913-1yzv6xm';
    
    RAISE NOTICE '✅ Receipt created: %', v_receipt_number;
END $$;

-- Verify it was created
SELECT 
    r.receipt_number,
    r.transaction_id,
    r.total_amount,
    r.customer_name,
    COUNT(ri.id) as item_count
FROM receipts r
LEFT JOIN receipt_items ri ON r.id = ri.receipt_id
WHERE r.transaction_id = 'TXN-1763753984913-1yzv6xm'
GROUP BY r.receipt_number, r.transaction_id, r.total_amount, r.customer_name;
