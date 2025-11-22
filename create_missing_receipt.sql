-- Create receipt for the missing transaction
DO $$
DECLARE
    v_receipt_number VARCHAR;
    v_receipt_id UUID;
    v_transaction_record RECORD;
    v_order_record RECORD;
BEGIN
    -- Get transaction details
    SELECT * INTO v_transaction_record
    FROM mpesa_transactions
    WHERE transaction_id = 'TXN-1763753984913-1yzv6xm';
    
    IF NOT FOUND THEN
        RAISE NOTICE 'Transaction not found!';
        RETURN;
    END IF;
    
    -- Get order details
    SELECT * INTO v_order_record
    FROM orders
    WHERE id = v_transaction_record.order_id;
    
    -- Generate receipt number
    v_receipt_number := generate_receipt_number();
    v_receipt_id := gen_random_uuid();
    
    RAISE NOTICE 'Creating receipt % for transaction %', v_receipt_number, v_transaction_record.transaction_id;
    
    -- Insert receipt
    INSERT INTO receipts (
        id,
        receipt_number,
        transaction_id,
        issue_date,
        customer_name,
        customer_email,
        customer_phone,
        subtotal,
        tax_amount,
        discount_amount,
        total_amount,
        payment_method,
        currency
    ) VALUES (
        v_receipt_id,
        v_receipt_number,
        v_transaction_record.transaction_id,
        COALESCE(v_transaction_record.created_at, NOW()),
        v_transaction_record.customer_name,
        NULL, -- email from users table if needed
        v_transaction_record.phone_number,
        v_order_record.total_amount,
        0,
        0,
        v_transaction_record.amount,
        'M-Pesa',
        'KES'
    );
    
    -- Insert receipt items from order
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
        oi.price,
        oi.quantity * oi.price
    FROM order_items oi
    WHERE oi.order_id = v_order_record.id;
    
    RAISE NOTICE '✅ Receipt created successfully: %', v_receipt_number;
END $$;

-- Verify the receipt was created
SELECT 
    r.receipt_number,
    r.transaction_id,
    r.total_amount,
    COUNT(ri.id) as item_count
FROM receipts r
LEFT JOIN receipt_items ri ON r.id = ri.receipt_id
WHERE r.transaction_id = 'TXN-1763753984913-1yzv6xm'
GROUP BY r.receipt_number, r.transaction_id, r.total_amount;
