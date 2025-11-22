-- ================================================================
-- GENERATE MISSING RECEIPTS FOR COMPLETED PAYMENTS
-- ================================================================
-- This script creates receipts for all completed M-Pesa payments
-- that don't have receipts yet (with robust NULL handling)
-- ================================================================

-- First, create the receipt number generator function if it doesn't exist
-- (Run create_receipt_number_function.sql first)

-- Generate receipts for completed payments without receipts
DO $$
DECLARE
  payment_record RECORD;
  new_receipt_id UUID;
  new_receipt_number TEXT;
  items_count INTEGER;
  receipt_count INTEGER := 0;
BEGIN
  -- Loop through completed payments without receipts
  FOR payment_record IN
    SELECT 
      mt.transaction_id,
      mt.order_id,
      mt.user_auth_id,
      mt.amount,
      mt.created_at,
      o.subtotal,
      o.tax,
      o.total,
      o.user_auth_id as order_user_id,
      COALESCE(u.name, 'Customer') as customer_name,
      COALESCE(u.phone, '') as customer_phone,
      COALESCE(u.email, '') as customer_email
    FROM mpesa_transactions mt
    JOIN orders o ON o.id = mt.order_id
    LEFT JOIN users u ON u.auth_id = COALESCE(mt.user_auth_id, o.user_auth_id)
    WHERE mt.status = 'completed'
      AND NOT EXISTS (
        SELECT 1 FROM receipts r WHERE r.transaction_id = mt.transaction_id
      )
    ORDER BY mt.created_at DESC
  LOOP
    BEGIN
      -- Generate receipt number
      SELECT generate_receipt_number() INTO new_receipt_number;
      
      -- Insert receipt with safe NULL handling
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
        new_receipt_number,
        payment_record.transaction_id,
        'payment',
        payment_record.created_at,
        payment_record.customer_name,
        payment_record.customer_phone,
        payment_record.customer_email,
        CAST(ROUND(COALESCE(payment_record.subtotal, 0)) AS INTEGER),
        CAST(ROUND(COALESCE(payment_record.tax, 0)) AS INTEGER),
        0,
        CAST(ROUND(COALESCE(payment_record.total, 0)) AS INTEGER),
        'KES',
        'M-Pesa',
        'Ouma''s Delicacy',
        NULL,  -- business_address (nullable)
        NULL,  -- business_phone (nullable)
        'receipts@oumasdelicacy.com'
      )
      RETURNING id INTO new_receipt_id;
      
      -- Insert receipt items (only if order has items)
      INSERT INTO receipt_items (
        receipt_id,
        item_description,
        quantity,
        unit_price,
        total_price,
        item_code
      )
      SELECT
        new_receipt_id,
        COALESCE(oi.item_name, 'Item'),
        COALESCE(oi.quantity, 1),
        CAST(ROUND(COALESCE(oi.unit_price, 0)) AS INTEGER),
        CAST(ROUND(COALESCE(oi.total_price, 0)) AS INTEGER),
        COALESCE(oi.item_type, 'ITEM')
      FROM order_items oi
      WHERE oi.order_id = payment_record.order_id;
      
      GET DIAGNOSTICS items_count = ROW_COUNT;
      
      receipt_count := receipt_count + 1;
      
      RAISE NOTICE '✅ [%] Created receipt % for transaction % with % items',
        receipt_count,
        new_receipt_number,
        payment_record.transaction_id,
        items_count;
        
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE '❌ Failed to create receipt for transaction %: % (SQLSTATE: %)',
        payment_record.transaction_id,
        SQLERRM,
        SQLSTATE;
    END;
  END LOOP;
  
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ COMPLETE: Generated % receipts', receipt_count;
  RAISE NOTICE '========================================';
END $$;

-- Verify results
SELECT 
    mt.transaction_id,
    mt.order_id,
    mt.status as payment_status,
    mt.created_at as payment_time,
    r.receipt_number,
    r.created_at as receipt_time,
    COUNT(ri.id) as items_count
FROM mpesa_transactions mt
LEFT JOIN receipts r ON r.transaction_id = mt.transaction_id
LEFT JOIN receipt_items ri ON ri.receipt_id = r.id
WHERE mt.status = 'completed'
  AND mt.created_at > NOW() - INTERVAL '7 days'
GROUP BY mt.transaction_id, mt.order_id, mt.status, mt.created_at, r.receipt_number, r.created_at
ORDER BY mt.created_at DESC;
