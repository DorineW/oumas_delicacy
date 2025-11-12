-- ============================================================================
-- Script: Link Existing Orders to Payment Methods
-- Created: 2025-11-12
-- Description: Attempts to retroactively link orders to payment methods
--              based on user_auth_id and timestamp proximity
-- ============================================================================

-- Strategy: Match orders with payment_methods where:
-- 1. Same user_auth_id
-- 2. Payment method created within 5 minutes BEFORE order placed_at
-- 3. Payment method doesn't already have an order linked to it

-- First, let's see what we're working with
SELECT 
  'Orders without payment_method_id: ' || COUNT(*)::TEXT as status
FROM public.orders
WHERE payment_method_id IS NULL;

-- Preview potential matches (doesn't update anything)
SELECT 
  o.id as order_id,
  o.user_auth_id,
  o.placed_at as order_time,
  o.total as order_total,
  pm.id as payment_method_id,
  pm.created_at as payment_time,
  pm.metadata->>'totalAmount' as payment_amount,
  EXTRACT(EPOCH FROM (o.placed_at - pm.created_at))/60 as minutes_difference
FROM public.orders o
LEFT JOIN public.payment_methods pm ON (
  o.user_auth_id = pm.user_auth_id
  AND pm.created_at <= o.placed_at
  AND pm.created_at >= o.placed_at - INTERVAL '5 minutes'
)
WHERE o.payment_method_id IS NULL
ORDER BY o.placed_at DESC, minutes_difference ASC;

-- ============================================================================
-- OPTION 1: Automatic update (best match per order)
-- Uncomment to execute automatic linking
-- ============================================================================
/*
WITH matched_payments AS (
  SELECT DISTINCT ON (o.id)
    o.id as order_id,
    pm.id as payment_method_id,
    EXTRACT(EPOCH FROM (o.placed_at - pm.created_at)) as time_diff_seconds
  FROM public.orders o
  JOIN public.payment_methods pm ON (
    o.user_auth_id = pm.user_auth_id
    AND pm.created_at <= o.placed_at
    AND pm.created_at >= o.placed_at - INTERVAL '10 minutes'
  )
  WHERE o.payment_method_id IS NULL
  ORDER BY o.id, ABS(EXTRACT(EPOCH FROM (o.placed_at - pm.created_at))) ASC
)
UPDATE public.orders
SET payment_method_id = matched_payments.payment_method_id
FROM matched_payments
WHERE orders.id = matched_payments.order_id;

-- Verify update
SELECT 
  'Orders now linked to payment methods: ' || COUNT(*)::TEXT as result
FROM public.orders
WHERE payment_method_id IS NOT NULL;
*/

-- ============================================================================
-- OPTION 2: Manual update for specific order
-- Replace the UUIDs with actual values from your database
-- ============================================================================
/*
UPDATE public.orders
SET payment_method_id = 'YOUR_PAYMENT_METHOD_ID'
WHERE id = 'YOUR_ORDER_ID';
*/

-- ============================================================================
-- OPTION 3: Link based on metadata (if order details stored in payment_methods)
-- This assumes your backend stored order info in metadata
-- ============================================================================
/*
UPDATE public.orders o
SET payment_method_id = pm.id
FROM public.payment_methods pm
WHERE 
  o.payment_method_id IS NULL
  AND pm.user_auth_id = o.user_auth_id
  AND pm.metadata IS NOT NULL
  AND (
    -- Try matching by total amount
    (pm.metadata->>'totalAmount')::numeric = o.total
    OR
    -- Or by customer ID + timestamp proximity
    (
      pm.metadata->>'customerId' = o.user_auth_id::text
      AND pm.created_at <= o.placed_at
      AND pm.created_at >= o.placed_at - INTERVAL '10 minutes'
    )
  );
*/

-- ============================================================================
-- Check results
-- ============================================================================
SELECT 
  COUNT(*) as total_orders,
  COUNT(payment_method_id) as orders_with_payment_link,
  COUNT(*) - COUNT(payment_method_id) as orders_without_payment_link
FROM public.orders;

-- Show orders that still don't have payment method linked
SELECT 
  o.id,
  o.user_auth_id,
  o.placed_at,
  o.total,
  o.status,
  u.name as customer_name
FROM public.orders o
LEFT JOIN public.users u ON o.user_auth_id = u.auth_id
WHERE o.payment_method_id IS NULL
ORDER BY o.placed_at DESC
LIMIT 20;

-- ============================================================================
-- Final message
-- ============================================================================
DO $$
DECLARE
  unlinked_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO unlinked_count
  FROM public.orders
  WHERE payment_method_id IS NULL;
  
  IF unlinked_count = 0 THEN
    RAISE NOTICE '✅ All orders have been linked to payment methods!';
  ELSE
    RAISE NOTICE '⚠️ % orders still need payment method links. Review and use manual update if needed.', unlinked_count;
  END IF;
END $$;
