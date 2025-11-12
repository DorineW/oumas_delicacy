-- ============================================================================
-- Cleanup Duplicate RLS Policies on Orders Table
-- Description: Remove duplicate policies and keep only clean, optimized ones
-- ============================================================================

-- Step 1: Drop ALL existing policies on orders table
DROP POLICY IF EXISTS "Users can select own orders" ON public.orders;
DROP POLICY IF EXISTS "Admins can view all orders" ON public.orders;
DROP POLICY IF EXISTS "Riders can view assigned orders" ON public.orders;
DROP POLICY IF EXISTS "Users can update own orders" ON public.orders;
DROP POLICY IF EXISTS "Admins can update all orders" ON public.orders;
DROP POLICY IF EXISTS "Riders can update assigned orders" ON public.orders;
DROP POLICY IF EXISTS "orders_select_own" ON public.orders;
DROP POLICY IF EXISTS "orders_insert_own" ON public.orders;
DROP POLICY IF EXISTS "Service role can insert orders" ON public.orders;
DROP POLICY IF EXISTS "Users can insert own orders (duplicate/alt)" ON public.orders;

-- Step 2: Create clean, optimized policies

-- SELECT POLICIES
-- 1. Users can view their own orders
CREATE POLICY "orders_select_own" ON public.orders
  FOR SELECT
  TO authenticated
  USING (user_auth_id = auth.uid());

-- 2. Admins can view all orders
CREATE POLICY "orders_select_admin" ON public.orders
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users 
      WHERE users.auth_id = auth.uid() 
      AND users.role = 'admin'
    )
  );

-- 3. Riders can view orders assigned to them
CREATE POLICY "orders_select_rider" ON public.orders
  FOR SELECT
  TO authenticated
  USING (
    rider_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.users 
      WHERE users.auth_id = auth.uid() 
      AND users.role = 'rider'
    )
  );

-- INSERT POLICIES
-- 4. Service role can insert orders (for M-Pesa backend)
CREATE POLICY "orders_insert_service" ON public.orders
  FOR INSERT
  TO service_role
  WITH CHECK (true);

-- 5. Users can insert their own orders
CREATE POLICY "orders_insert_own" ON public.orders
  FOR INSERT
  TO authenticated
  WITH CHECK (user_auth_id = auth.uid());

-- UPDATE POLICIES
-- 6. Users can update their own pending orders (for cancellation)
CREATE POLICY "orders_update_own" ON public.orders
  FOR UPDATE
  TO authenticated
  USING (user_auth_id = auth.uid())
  WITH CHECK (user_auth_id = auth.uid());

-- 7. Admins can update all orders
CREATE POLICY "orders_update_admin" ON public.orders
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users 
      WHERE users.auth_id = auth.uid() 
      AND users.role = 'admin'
    )
  );

-- 8. Riders can update orders assigned to them (for status updates)
CREATE POLICY "orders_update_rider" ON public.orders
  FOR UPDATE
  TO authenticated
  USING (
    rider_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.users 
      WHERE users.auth_id = auth.uid() 
      AND users.role = 'rider'
    )
  );

-- Step 3: Verify the policies
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
WHERE tablename = 'orders'
ORDER BY cmd, policyname;

-- Step 4: Summary
DO $$
DECLARE
  policy_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO policy_count
  FROM pg_policies
  WHERE tablename = 'orders';
  
  RAISE NOTICE '✅ Cleanup complete!';
  RAISE NOTICE '📋 Total policies on orders table: %', policy_count;
  RAISE NOTICE '✨ Policies:';
  RAISE NOTICE '   - 3 SELECT policies (own/admin/rider)';
  RAISE NOTICE '   - 2 INSERT policies (service/own)';
  RAISE NOTICE '   - 3 UPDATE policies (own/admin/rider)';
END $$;
