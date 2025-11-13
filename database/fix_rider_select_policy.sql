-- ============================================================================
-- Fix Rider SELECT Policy for Orders
-- Description: Simplify the rider policy to just check rider_id
-- ============================================================================

-- Drop the existing rider select policy
DROP POLICY IF EXISTS "orders_select_rider" ON public.orders;

-- Create a simpler policy - just check if the order is assigned to this rider
CREATE POLICY "orders_select_rider" ON public.orders
  FOR SELECT
  TO authenticated
  USING (rider_id = auth.uid());

-- Verify the policy
SELECT 
  policyname,
  cmd,
  qual
FROM pg_policies
WHERE tablename = 'orders' 
  AND policyname = 'orders_select_rider';

-- Test query to see what a rider would see
-- Replace 'ae4bfde4-df50-423e-9068-8a981429522b' with actual rider auth_id
SELECT 
  id,
  user_auth_id,
  rider_id,
  status,
  total,
  placed_at
FROM orders
WHERE rider_id = 'ae4bfde4-df50-423e-9068-8a981429522b'
ORDER BY placed_at DESC;

-- Summary
DO $$
BEGIN
  RAISE NOTICE '✅ Rider SELECT policy simplified!';
  RAISE NOTICE '📋 Riders can now see orders where rider_id = auth.uid()';
END $$;
