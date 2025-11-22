-- ============================================
-- MANUAL RECEIPT GENERATION
-- ============================================
-- Use this if a receipt wasn't auto-generated for a completed payment
-- Replace the checkout_request_id with your actual transaction ID

-- Step 1: Verify the transaction is completed
DO $$
DECLARE
    v_transaction_id VARCHAR(50);
    v_order_id UUID;
    v_user_auth_id UUID;
    v_order_record RECORD;
    v_receipt_number VARCHAR(100);
    v_receipt_id UUID;
BEGIN
    -- Get the most recent completed transaction without a receipt
    SELECT mt.transaction_id, mt.order_id, mt.user_auth_id
    INTO v_transaction_id, v_order_id, v_user_auth_id
    FROM mpesa_transactions mt
    WHERE mt.status = 'completed'
    AND NOT EXISTS (
        SELECT 1 FROM receipts r WHERE r.transaction_id = mt.transaction_id
    )
    ORDER BY mt.updated_at DESC
    LIMIT 1;

    -- Check if we found a transaction
    IF v_transaction_id IS NULL THEN
        RAISE NOTICE '✅ No completed transactions without receipts found!';
        RETURN;
    END IF;

    RAISE NOTICE '🔍 Found transaction without receipt: %', v_transaction_id;
    RAISE NOTICE '   Order ID: %', v_order_id;

    -- Get order details
    SELECT 
        o.*,
        u.name,
        u.phone,
        u.email
    INTO v_order_record
    FROM orders o
    JOIN users u ON o.user_auth_id = u.auth_id
    WHERE o.id = v_order_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order not found: %', v_order_id;
    END IF;

    -- Generate receipt number
    SELECT generate_receipt_number() INTO v_receipt_number;

    RAISE NOTICE '📄 Creating receipt: %', v_receipt_number;

    -- Insert receipt with business_name (required NOT NULL field)
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
        payment_method,
        currency,
        business_name
    ) VALUES (
        v_receipt_number,
        v_transaction_id,
        'payment',
        NOW(),
        v_order_record.name,
        v_order_record.phone,
        v_order_record.email,
        ROUND(v_order_record.subtotal)::numeric,
        ROUND(COALESCE(v_order_record.tax, 0))::numeric,
        0::numeric,
        ROUND(v_order_record.total)::numeric,
        'M-Pesa',
        'KES',
        'Ouma''s Delicacy'
    )
    RETURNING id INTO v_receipt_id;

    RAISE NOTICE '✅ Receipt created with ID: %', v_receipt_id;

    -- Insert receipt items
    INSERT INTO receipt_items (
        receipt_id,
        item_description,
        quantity,
        unit_price,
        total_price,
        item_code
    )
    SELECT
        v_receipt_id,
        oi.name,
        oi.quantity,
        ROUND(oi.unit_price)::integer,
        ROUND(oi.total_price)::integer,
        oi.item_type
    FROM order_items oi
    WHERE oi.order_id = v_order_id;

    RAISE NOTICE '✅ Receipt items created for order %', v_order_id;
    RAISE NOTICE '';
    RAISE NOTICE '==================================================';
    RAISE NOTICE 'Receipt Generation Complete!';
    RAISE NOTICE '==================================================';
    RAISE NOTICE 'Receipt Number: %', v_receipt_number;
    RAISE NOTICE 'Transaction ID: %', v_transaction_id;
    RAISE NOTICE 'Customer: %', v_order_record.name;
    RAISE NOTICE 'Total Amount: KSh %', ROUND(v_order_record.total);
    RAISE NOTICE '==================================================';

END $$;

-- Verify the receipt was created
SELECT 
    r.receipt_number,
    r.transaction_id,
    r.customer_name,
    r.total_amount,
    r.issue_date,
    COUNT(ri.id) as item_count
FROM receipts r
LEFT JOIN receipt_items ri ON r.id = ri.receipt_id
WHERE r.transaction_id IN (
    SELECT transaction_id 
    FROM mpesa_transactions 
    WHERE status = 'completed'
    ORDER BY updated_at DESC 
    LIMIT 1
)
GROUP BY r.id
ORDER BY r.issue_date DESC;
