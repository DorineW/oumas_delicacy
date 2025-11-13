-- ============================================================================
-- Simple Long-term Fix for Admin UPDATE Policy
-- Description: Use a SECURITY DEFINER function to check admin role
-- ============================================================================

-- Step 1: Create a function that bypasses RLS to check if user is admin
CREATE OR REPLACE FUNCTION public.is_admin(user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE auth_id = user_id
    AND role = 'admin'
  );
$$;

-- Step 2: Drop and recreate the admin update policy using the function
DROP POLICY IF EXISTS "orders_update_admin" ON public.orders;

CREATE POLICY "orders_update_admin" ON public.orders
  FOR UPDATE
  TO authenticated
  USING (public.is_admin(auth.uid()))
  WITH CHECK (true);

-- Step 3: Verify
SELECT 
  policyname,
  cmd,
  qual
FROM pg_policies
WHERE tablename = 'orders' 
  AND policyname = 'orders_update_admin';

-- Summary
DO $$
BEGIN
  RAISE NOTICE '✅ Admin UPDATE policy fixed with SECURITY DEFINER function!';
  RAISE NOTICE '📋 No more infinite recursion';
  RAISE NOTICE '🔒 Long-term solution in place';
END $$;
