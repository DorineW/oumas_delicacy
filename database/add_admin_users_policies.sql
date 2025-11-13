-- Add admin policies for users table
-- This allows admins to view and update all users

-- Create or replace the is_admin function if it doesn't exist
CREATE OR REPLACE FUNCTION public.is_admin(user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE auth_id = user_id AND role = 'admin'
  );
$$;

-- Drop existing admin policies if they exist
DROP POLICY IF EXISTS "Admins Can Select All Users" ON public.users;
DROP POLICY IF EXISTS "Admins Can Update All Users" ON public.users;

-- Create policy allowing admins to select any user
CREATE POLICY "Admins Can Select All Users"
  ON public.users
  FOR SELECT
  USING (public.is_admin(auth.uid()));

-- Create policy allowing admins to update any user
CREATE POLICY "Admins Can Update All Users"
  ON public.users
  FOR UPDATE
  USING (public.is_admin(auth.uid()))
  WITH CHECK (public.is_admin(auth.uid()));

-- Create function to update user role (including auth metadata)
-- This runs with SECURITY DEFINER so it can update auth.users
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
  SELECT EXISTS(SELECT 1 FROM auth.users WHERE id = target_user_id) INTO user_exists;
  
  IF NOT user_exists THEN
    RAISE EXCEPTION 'User not found in auth.users';
  END IF;

  -- Update public.users table (quote "role" to avoid SET ROLE command confusion)
  UPDATE public.users
  SET "role" = new_role, updated_at = NOW()
  WHERE auth_id = target_user_id;

  -- Update auth.users raw_user_meta_data
  UPDATE auth.users
  SET raw_user_meta_data = 
    COALESCE(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object('role', new_role),
    updated_at = NOW()
  WHERE id = target_user_id;

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

-- Create helper function to view user auth details (for debugging)
CREATE OR REPLACE FUNCTION public.admin_get_user_details(
  target_user_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result json;
BEGIN
  -- Check if caller is admin
  IF NOT public.is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Only admins can view user details';
  END IF;

  SELECT json_build_object(
    'auth_user', (
      SELECT json_build_object(
        'id', id,
        'email', email,
        'email_confirmed_at', email_confirmed_at,
        'role', raw_user_meta_data->>'role',
        'raw_user_meta_data', raw_user_meta_data,
        'created_at', created_at,
        'updated_at', updated_at
      )
      FROM auth.users WHERE id = target_user_id
    ),
    'public_user', (
      SELECT json_build_object(
        'auth_id', auth_id,
        'email', email,
        'name', name,
        'role', role,
        'created_at', created_at,
        'updated_at', updated_at
      )
      FROM public.users WHERE auth_id = target_user_id
    )
  ) INTO result;

  RETURN result;
END;
$$;

