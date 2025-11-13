-- COMPREHENSIVE FIX: Replace ALL policies with unquoted 'role' references
-- This fixes the "role 'customer' does not exist" error

-- Reset any stuck session state
RESET ROLE;

-- ===== INVENTORY_ITEMS POLICIES =====
DROP POLICY IF EXISTS "Only admins can modify inventory" ON public.inventory_items;

CREATE POLICY "Only admins can modify inventory"
  ON public.inventory_items
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.users 
      WHERE users.auth_id = auth.uid() 
      AND users."role" = 'admin'
    )
  );

-- ===== ORDER_ITEMS POLICIES =====
DROP POLICY IF EXISTS "Admins can view all order items" ON public.order_items;

CREATE POLICY "Admins can view all order items"
  ON public.order_items
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.users 
      WHERE users.auth_id = auth.uid() 
      AND users."role" = 'admin'
    )
  );

-- ===== ORDERS POLICIES =====
DROP POLICY IF EXISTS "orders_select_admin" ON public.orders;
DROP POLICY IF EXISTS "orders_update_rider" ON public.orders;

CREATE POLICY "orders_select_admin"
  ON public.orders
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.users 
      WHERE users.auth_id = auth.uid() 
      AND users."role" = 'admin'
    )
  );

CREATE POLICY "orders_update_rider"
  ON public.orders
  FOR UPDATE
  USING (
    rider_id = auth.uid() 
    AND EXISTS (
      SELECT 1 FROM public.users 
      WHERE users.auth_id = auth.uid() 
      AND users."role" = 'rider'
    )
  );

-- ===== PRODUCTS POLICIES =====
DROP POLICY IF EXISTS "Only admins can modify products" ON public.products;

CREATE POLICY "Only admins can modify products"
  ON public.products
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.users 
      WHERE users.auth_id = auth.uid() 
      AND users."role" = 'admin'
    )
  );

-- ===== RIDERS POLICIES =====
DROP POLICY IF EXISTS "Admins can manage riders" ON public.riders;

CREATE POLICY "Admins can manage riders"
  ON public.riders
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.users 
      WHERE users.auth_id = auth.uid() 
      AND users."role" = 'admin'
    )
  );

-- ===== UPDATE is_admin FUNCTION =====
CREATE OR REPLACE FUNCTION public.is_admin(user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE users.auth_id = user_id 
    AND users."role" = 'admin'
  );
$$;

-- ===== UPDATE admin_update_user_role FUNCTION =====
DROP FUNCTION IF EXISTS public.admin_update_user_role(uuid, text) CASCADE;

CREATE OR REPLACE FUNCTION public.admin_update_user_role(
  target_user_id uuid,
  new_role text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result json;
  user_exists boolean;
BEGIN
  -- Check if caller is admin
  IF NOT public.is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Only admins can update user roles';
  END IF;

  -- Check if user exists in auth.users
  SELECT EXISTS(SELECT 1 FROM auth.users WHERE auth.users.id = target_user_id) INTO user_exists;
  
  IF NOT user_exists THEN
    RAISE EXCEPTION 'User not found in auth.users';
  END IF;

  -- Update public.users table with fully qualified column names
  UPDATE public.users
  SET "role" = new_role, "updated_at" = NOW()
  WHERE public.users."auth_id" = target_user_id;

  -- Update auth.users raw_user_meta_data
  UPDATE auth.users
  SET "raw_user_meta_data" = 
    COALESCE(auth.users."raw_user_meta_data", '{}'::jsonb) || jsonb_build_object('role', new_role),
    "updated_at" = NOW()
  WHERE auth.users."id" = target_user_id;

  -- Return success
  SELECT json_build_object(
    'success', true,
    'user_id', target_user_id,
    'new_role', new_role,
    'message', 'Role updated successfully. User needs to log out and log back in.'
  ) INTO result;

  RETURN result;
END;
$$;

-- Verification message
DO $$
BEGIN
  RAISE NOTICE '✅ ALL policies and functions updated with quoted "role" column references';
  RAISE NOTICE '⚠️ NEXT STEPS:';
  RAISE NOTICE '   1. Terminate all connections: Run the connection termination query';
  RAISE NOTICE '   2. Restart your Supabase project from the dashboard';
  RAISE NOTICE '   3. Restart your Flutter app completely';
END $$;
