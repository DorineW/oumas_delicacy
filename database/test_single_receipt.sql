-- ================================================================
-- TEST SINGLE RECEIPT CREATION
-- ================================================================
-- Try to create just ONE receipt to see the exact error
-- ================================================================

-- Get the most recent completed payment without a receipt
DO $$
DECLARE
  v_transaction_id VARCHAR(50);
  v_order_id UUID;
  v_user_auth_id UUID;
  v_created_at TIMESTAMPTZ;
  v_subtotal NUMERIC;
  v_tax NUMERIC;
  v_total NUMERIC;
  v_customer_name VARCHAR(255);
  v_customer_phone VARCHAR(20);
  v_customer_email VARCHAR(255);
  v_receipt_number TEXT;
  v_new_receipt_id UUID;
  v_items_count INTEGER;
BEGIN
  -- Get the payment details
  SELECT 
    mt.transaction_id,
    mt.order_id,
    mt.user_auth_id,
    mt.created_at,
    o.subtotal,
    o.tax,
    o.total,
    COALESCE(u.name, 'Customer') as customer_name,
    COALESCE(u.phone, '') as customer_phone,
    COALESCE(u.email, '') as customer_email
  INTO
    v_transaction_id,
    v_order_id,
    v_user_auth_id,
    v_created_at,
    v_subtotal,
    v_tax,
    v_total,
    v_customer_name,
    v_customer_phone,
    v_customer_email
  FROM mpesa_transactions mt
  JOIN orders o ON o.id = mt.order_id
  LEFT JOIN users u ON u.auth_id = COALESCE(mt.user_auth_id, o.user_auth_id)
  WHERE mt.status = 'completed'
    AND NOT EXISTS (SELECT 1 FROM receipts r WHERE r.transaction_id = mt.transaction_id)
  ORDER BY mt.created_at DESC
  LIMIT 1;

  -- Check if we found a payment
  IF v_transaction_id IS NULL THEN
    RAISE NOTICE '❌ No completed payments without receipts found';
    RETURN;
  END IF;

  RAISE NOTICE '📋 Found payment to process:';
  RAISE NOTICE '   Transaction ID: %', v_transaction_id;
  RAISE NOTICE '   Order ID: %', v_order_id;
  RAISE NOTICE '   User Auth ID: %', v_user_auth_id;
  RAISE NOTICE '   Customer Name: %', v_customer_name;
  RAISE NOTICE '   Customer Phone: %', v_customer_phone;
  RAISE NOTICE '   Subtotal: %', v_subtotal;
  RAISE NOTICE '   Total: %', v_total;
  RAISE NOTICE '';

  -- Generate receipt number
  SELECT generate_receipt_number() INTO v_receipt_number;
  RAISE NOTICE '✅ Generated receipt number: %', v_receipt_number;

  -- Try to insert the receipt
  RAISE NOTICE '📝 Attempting to insert receipt...';
  
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
    business_address,
    business_phone,
    business_email
  ) VALUES (
    v_receipt_number,
    v_transaction_id,
    'payment',
    v_created_at,
    v_customer_name,
    v_customer_phone,
    v_customer_email,
    CAST(ROUND(COALESCE(v_subtotal, 0)) AS INTEGER),
    CAST(ROUND(COALESCE(v_tax, 0)) AS INTEGER),
    0,
    CAST(ROUND(COALESCE(v_total, 0)) AS INTEGER),
    'KES',
    'M-Pesa',
    'Ouma''s Delicacy',
    NULL,
    NULL,
    'receipts@oumasdelicacy.com'
  )
  RETURNING id INTO v_new_receipt_id;

  RAISE NOTICE '✅ Receipt inserted! ID: %', v_new_receipt_id;

  -- Try to insert receipt items
  RAISE NOTICE '📝 Attempting to insert receipt items...';
  
  INSERT INTO receipt_items (
    receipt_id,
    item_description,
    quantity,
    unit_price,
    total_price,
    item_code
  )
  SELECT
    v_new_receipt_id,
    COALESCE(oi.item_name, 'Item'),
    COALESCE(oi.quantity, 1),
    CAST(ROUND(COALESCE(oi.unit_price, 0)) AS INTEGER),
    CAST(ROUND(COALESCE(oi.total_price, 0)) AS INTEGER),
    COALESCE(oi.item_type, 'ITEM')
  FROM order_items oi
  WHERE oi.order_id = v_order_id;

  GET DIAGNOSTICS v_items_count = ROW_COUNT;
  
  RAISE NOTICE '✅ Inserted % receipt items', v_items_count;
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ SUCCESS: Created receipt % with % items', v_receipt_number, v_items_count;
  RAISE NOTICE '========================================';

EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '❌ ERROR DETAILS:';
  RAISE NOTICE '   Message: %', SQLERRM;
  RAISE NOTICE '   State: %', SQLSTATE;
  RAISE NOTICE '========================================';
END $$;
