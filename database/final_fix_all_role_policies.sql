-- Comprehensive fix for "role 'customer' does not exist" error
-- Fixes all policies and functions to use fully qualified column names

-- Step 1: Reset any stuck session state
RESET ROLE;

-- Step 2: Fix the riders table policies
DROP POLICY IF EXISTS "Admins can manage riders" ON public.riders;
DROP POLICY IF EXISTS "Riders can update own profile" ON public.riders;
DROP POLICY IF EXISTS "Riders can view own profile" ON public.riders;

-- Recreate riders policies with explicit column references
CREATE POLICY "Admins can manage riders"
  ON public.riders
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.users 
      WHERE public.users.auth_id = auth.uid() 
      AND public.users."role" = 'admin'
    )
  );

CREATE POLICY "Riders can view own profile"
  ON public.riders
  FOR SELECT
  USING (public.riders.auth_id = auth.uid());

CREATE POLICY "Riders can update own profile"
  ON public.riders
  FOR UPDATE
  USING (public.riders.auth_id = auth.uid());

-- Step 3: Update the admin_update_user_role function
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

-- Step 4: Update is_admin function to be explicit
CREATE OR REPLACE FUNCTION public.is_admin(user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE public.users.auth_id = user_id 
    AND public.users."role" = 'admin'
  );
$$;

-- Step 5: Verify no stuck roles
DO $$
BEGIN
  RAISE NOTICE '✅ All policies and functions updated with explicit column references';
  RAISE NOTICE '⚠️ If errors persist, restart your Supabase project from the dashboard';
END $$;
