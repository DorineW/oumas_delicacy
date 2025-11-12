-- ============================================================================
-- Script: Drop All Orders from Database
-- Created: 2025-11-12
-- Description: Safely deletes all orders and order items (for testing/cleanup)
-- WARNING: This will permanently delete all order data!
-- ============================================================================

-- 1. First, delete all order items (child table)
DELETE FROM public.order_items;

-- 2. Then, delete all orders (parent table)
DELETE FROM public.orders;

-- 3. Reset sequences if you want IDs to start from 1 again (optional)
-- Note: Orders use UUID so this might not be needed
-- But order_items might use serial/auto-increment

-- 4. Verify deletion
SELECT 
  'Orders deleted: ' || COUNT(*)::TEXT as result
FROM public.orders
UNION ALL
SELECT 
  'Order items deleted: ' || COUNT(*)::TEXT
FROM public.order_items;

-- 5. Show confirmation message
DO $$
BEGIN
  RAISE NOTICE '✅ All orders and order items have been deleted!';
END $$;
