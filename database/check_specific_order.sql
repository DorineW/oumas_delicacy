-- ============================================================================
-- Check Specific Order in Database
-- Order ID: 7f1f2faa-b4d9-4d2f-a099-c5af4f4929e5
-- M-Pesa Receipt: TEST_S7B0NLO53
-- ============================================================================

-- 1. Check if the order exists
SELECT 
  id,
  user_auth_id,
  status,
  total,
  subtotal,
  delivery_fee,
  tax,
  placed_at,
  updated_at,
  delivery_address,
  delivery_phone
FROM public.orders
WHERE id = '7f1f2faa-b4d9-4d2f-a099-c5af4f4929e5';

-- 2. Check order items for this order
SELECT 
  oi.id,
  oi.order_id,
  oi.product_id,
  oi.name,
  oi.quantity,
  oi.unit_price,
  oi.total_price
FROM public.order_items oi
WHERE oi.order_id = '7f1f2faa-b4d9-4d2f-a099-c5af4f4929e5';

-- 3. Check payment method record (if linked)
SELECT 
  pm.id,
  pm.user_auth_id,
  pm.provider,
  pm.provider_method_id,
  pm.metadata,
  pm.created_at
FROM public.payment_methods pm
WHERE pm.user_auth_id = '8d8a4e83-9e74-4416-a189-1ebf6de728ab'
  AND pm.metadata->>'orderId' = '7f1f2faa-b4d9-4d2f-a099-c5af4f4929e5';

-- 4. Get full order details with customer name
SELECT 
  o.id,
  o.user_auth_id,
  u.name as customer_name,
  u.email as customer_email,
  o.status,
  o.total,
  o.placed_at,
  o.delivery_address,
  COUNT(oi.id) as item_count
FROM public.orders o
LEFT JOIN public.users u ON o.user_auth_id = u.auth_id
LEFT JOIN public.order_items oi ON o.id = oi.order_id
WHERE o.id = '7f1f2faa-b4d9-4d2f-a099-c5af4f4929e5'
GROUP BY o.id, o.user_auth_id, u.name, u.email, o.status, o.total, o.placed_at, o.delivery_address;

-- 5. Check recent orders for this user
SELECT 
  id,
  status,
  total,
  placed_at,
  CASE 
    WHEN id = '7f1f2faa-b4d9-4d2f-a099-c5af4f4929e5' THEN '👈 THIS ORDER'
    ELSE ''
  END as marker
FROM public.orders
WHERE user_auth_id = '8d8a4e83-9e74-4416-a189-1ebf6de728ab'
ORDER BY placed_at DESC
LIMIT 10;

-- 6. Summary
DO $$
DECLARE
  order_exists BOOLEAN;
  item_count INTEGER;
BEGIN
  -- Check if order exists
  SELECT EXISTS(
    SELECT 1 FROM public.orders WHERE id = '7f1f2faa-b4d9-4d2f-a099-c5af4f4929e5'
  ) INTO order_exists;
  
  IF order_exists THEN
    -- Count order items
    SELECT COUNT(*) INTO item_count
    FROM public.order_items
    WHERE order_id = '7f1f2faa-b4d9-4d2f-a099-c5af4f4929e5';
    
    RAISE NOTICE '✅ Order 7f1f2faa-b4d9-4d2f-a099-c5af4f4929e5 EXISTS in database';
    RAISE NOTICE '📦 Order has % item(s)', item_count;
    RAISE NOTICE '💳 M-Pesa Receipt: TEST_S7B0NLO53';
  ELSE
    RAISE NOTICE '❌ Order 7f1f2faa-b4d9-4d2f-a099-c5af4f4929e5 NOT FOUND in database';
  END IF;
END $$;
