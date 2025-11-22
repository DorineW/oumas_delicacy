-- ================================================================
-- BULK CREATE RECEIPTS - Direct INSERT Method
-- ================================================================
-- Creates all missing receipts in one go (faster and more reliable)
-- ================================================================

-- Part 1: Insert all missing receipts
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
  WHERE mt.status = 'completed'
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
  business_address,
  business_phone,
  business_email
)
SELECT
  'RCP-' || TO_CHAR(created_at, 'YYYYMMDD') || '-' || LPAD(row_num::TEXT, 6, '0'),
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
  NULL,
  NULL,
  'receipts@oumasdelicacy.com'
FROM payments_needing_receipts;

-- Check how many were created
SELECT COUNT(*) as receipts_created 
FROM receipts 
WHERE created_at > NOW() - INTERVAL '1 minute';

-- Part 2: Insert receipt items for all new receipts
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
WHERE r.created_at > NOW() - INTERVAL '1 minute';

-- Check how many items were created
SELECT COUNT(*) as receipt_items_created 
FROM receipt_items 
WHERE created_at > NOW() - INTERVAL '1 minute';

-- Final verification
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
WHERE mt.status = 'completed'
  AND mt.created_at > NOW() - INTERVAL '7 days'
GROUP BY mt.transaction_id, mt.created_at, r.id, r.receipt_number
ORDER BY mt.created_at DESC;
