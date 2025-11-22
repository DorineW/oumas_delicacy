-- ============================================
-- FIX LATEST ORDER STATUS AND GENERATE RECEIPT
-- ============================================
-- This will:
-- 1. Update order status from pending_payment to confirmed
-- 2. Generate receipt for the completed transaction

-- Step 1: Update the order status to confirmed
UPDATE orders
SET 
    status = 'confirmed',
    updated_at = NOW()
WHERE id = '3ba3f918-300f-4762-8fcc-e2ee593da1fc'
AND status = 'pending_payment';

-- Step 2: Generate receipt for the completed transaction
DO $$
DECLARE
    v_transaction_id VARCHAR(50);
    v_order_id UUID;
    v_user_auth_id UUID;
    v_order_record RECORD;
    v_receipt_number VARCHAR(100);
    v_receipt_id UUID;
BEGIN
    -- Get the transaction for checkout_request_id
    SELECT mt.transaction_id, mt.order_id, mt.user_auth_id
    INTO v_transaction_id, v_order_id, v_user_auth_id
    FROM mpesa_transactions mt
    WHERE mt.checkout_request_id = 'ws_CO_18112025194817799700182990'
    AND mt.status = 'completed'
    AND NOT EXISTS (
        SELECT 1 FROM receipts r WHERE r.transaction_id = mt.transaction_id
    );

    -- Check if we found a transaction
    IF v_transaction_id IS NULL THEN
        RAISE NOTICE '✅ Receipt already exists or transaction not found!';
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

    -- Insert receipt
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

-- Verify the results
SELECT 
    'VERIFICATION' as check_type,
    o.id as order_id,
    o.short_id,
    o.status as order_status,
    o.total as order_total,
    mt.transaction_id,
    mt.status as payment_status,
    r.receipt_number,
    r.total_amount as receipt_total,
    COUNT(ri.id) as receipt_items_count
FROM orders o
LEFT JOIN mpesa_transactions mt ON mt.order_id = o.id
LEFT JOIN receipts r ON r.transaction_id = mt.transaction_id
LEFT JOIN receipt_items ri ON ri.receipt_id = r.id
WHERE o.id = '3ba3f918-300f-4762-8fcc-e2ee593da1fc'
GROUP BY o.id, o.short_id, o.status, o.total, mt.transaction_id, mt.status, r.receipt_number, r.total_amount;
