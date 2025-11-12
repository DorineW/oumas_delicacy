-- ============================================================================
-- Diagnostic Script: Check Orders and Payment Methods Relationship
-- Created: 2025-11-12
-- Description: Helps diagnose why orders aren't loading after payment
-- ============================================================================

-- 1. Check if orders exist in the database
SELECT 
  COUNT(*) as total_orders,
  COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_orders,
  COUNT(CASE WHEN status = 'confirmed' THEN 1 END) as confirmed_orders,
  COUNT(CASE WHEN placed_at > NOW() - INTERVAL '1 hour' THEN 1 END) as orders_last_hour,
  COUNT(CASE WHEN placed_at > NOW() - INTERVAL '1 day' THEN 1 END) as orders_last_24h
FROM public.orders;

-- 2. Check recent orders with user info
SELECT 
  o.id,
  o.user_auth_id,
  o.status,
  o.total,
  o.placed_at,
  u.name as customer_name,
  u.email,
  u.role
FROM public.orders o
LEFT JOIN public.users u ON o.user_auth_id = u.auth_id
ORDER BY o.placed_at DESC
LIMIT 10;

-- 3. Check payment methods with recent activity
SELECT 
  pm.id,
  pm.user_auth_id,
  pm.provider,
  pm.created_at,
  pm.metadata,
  u.name as user_name,
  u.email
FROM public.payment_methods pm
LEFT JOIN public.users u ON pm.user_auth_id = u.auth_id
ORDER BY pm.created_at DESC
LIMIT 10;

-- 4. Check for orders created in last 24 hours without user match
SELECT 
  o.id,
  o.user_auth_id,
  o.status,
  o.total,
  o.placed_at,
  CASE 
    WHEN EXISTS (SELECT 1 FROM public.users WHERE auth_id = o.user_auth_id) 
    THEN 'User exists' 
    ELSE '❌ User NOT found' 
  END as user_status
FROM public.orders o
WHERE o.placed_at > NOW() - INTERVAL '1 day'
ORDER BY o.placed_at DESC;

-- 5. Check RLS policies on orders table
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'orders';

-- 6. Check if RLS is enabled
SELECT 
  schemaname,
  tablename,
  rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public' AND tablename IN ('orders', 'order_items', 'payment_methods');

-- 7. Check for orphaned orders (orders with invalid user_auth_id)
SELECT 
  COUNT(*) as orphaned_orders,
  ARRAY_AGG(o.id) as order_ids
FROM public.orders o
WHERE NOT EXISTS (
  SELECT 1 FROM public.users u WHERE u.auth_id = o.user_auth_id
);

-- 8. Check for orders without order_items
SELECT 
  o.id,
  o.user_auth_id,
  o.total,
  o.placed_at,
  COUNT(oi.id) as item_count
FROM public.orders o
LEFT JOIN public.order_items oi ON o.id = oi.order_id
WHERE o.placed_at > NOW() - INTERVAL '1 day'
GROUP BY o.id, o.user_auth_id, o.total, o.placed_at
HAVING COUNT(oi.id) = 0
ORDER BY o.placed_at DESC;

-- 9. Test query that app uses (simulating a user query)
-- Replace 'YOUR_USER_AUTH_ID' with actual auth_id to test
/*
SELECT 
  o.*,
  u.name as customer_name
FROM public.orders o
LEFT JOIN public.users u ON o.user_auth_id = u.auth_id
WHERE o.user_auth_id = 'YOUR_USER_AUTH_ID'
ORDER BY o.placed_at DESC;
*/

-- 10. Check metadata in payment_methods for incomplete orders
SELECT 
  pm.id,
  pm.user_auth_id,
  pm.provider,
  pm.created_at,
  pm.metadata->>'orderId' as potential_order_id,
  pm.metadata->>'totalAmount' as order_total,
  pm.metadata->>'customerId' as customer_id,
  CASE 
    WHEN pm.metadata IS NOT NULL AND (pm.metadata->>'orderId') IS NOT NULL
    THEN 'Has order reference'
    WHEN pm.metadata IS NOT NULL
    THEN '⚠️ Has metadata but no order ID'
    ELSE 'No metadata'
  END as status
FROM public.payment_methods pm
WHERE pm.created_at > NOW() - INTERVAL '1 day'
ORDER BY pm.created_at DESC;

-- 11. Summary report
SELECT 
  '📊 SUMMARY REPORT' as section,
  '' as details
UNION ALL
SELECT 
  'Total Orders:', 
  COUNT(*)::TEXT
FROM public.orders
UNION ALL
SELECT 
  'Total Payment Methods:',
  COUNT(*)::TEXT
FROM public.payment_methods
UNION ALL
SELECT 
  'Orders in last 24h:',
  COUNT(*)::TEXT
FROM public.orders
WHERE placed_at > NOW() - INTERVAL '1 day'
UNION ALL
SELECT 
  'Payment Methods in last 24h:',
  COUNT(*)::TEXT
FROM public.payment_methods
WHERE created_at > NOW() - INTERVAL '1 day'
UNION ALL
SELECT 
  'Orphaned Orders:',
  COUNT(*)::TEXT
FROM public.orders o
WHERE NOT EXISTS (
  SELECT 1 FROM public.users u WHERE u.auth_id = o.user_auth_id
);
