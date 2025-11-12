-- ============================================================================
-- Quick Check: Verify payment_method_id column in orders table
-- ============================================================================

-- 1. Check if the column exists in orders table
SELECT 
  column_name, 
  data_type, 
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'orders'
  AND column_name = 'payment_method_id';

-- 2. View sample orders with the new column
SELECT 
  id,
  user_auth_id,
  status,
  total,
  placed_at,
  payment_method_id,  -- ← This is the new column
  CASE 
    WHEN payment_method_id IS NULL THEN '❌ No payment link'
    ELSE '✅ Linked to payment'
  END as link_status
FROM public.orders
ORDER BY placed_at DESC
LIMIT 10;

-- 3. Summary of orders with/without payment method links
SELECT 
  COUNT(*) as total_orders,
  COUNT(payment_method_id) as orders_linked_to_payment,
  COUNT(*) - COUNT(payment_method_id) as orders_without_link,
  ROUND(COUNT(payment_method_id)::numeric / NULLIF(COUNT(*), 0) * 100, 2) as percentage_linked
FROM public.orders;
