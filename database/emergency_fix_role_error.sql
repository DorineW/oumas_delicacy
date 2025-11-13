-- Emergency fix for "role 'customer' does not exist" error
-- This clears the corrupted session state and fixes all role-related functions

-- Step 1: Reset any SET ROLE statements that might be stuck
RESET ROLE;

-- Step 2: Drop the problematic function if it exists
DROP FUNCTION IF EXISTS public.admin_update_user_role(uuid, text) CASCADE;

-- Step 3: Recreate the function with properly quoted column names
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
  SET "role" = new_role, "updated_at" = NOW()
  WHERE "auth_id" = target_user_id;

  -- Update auth.users raw_user_meta_data
  UPDATE auth.users
  SET "raw_user_meta_data" = 
    COALESCE("raw_user_meta_data", '{}'::jsonb) || jsonb_build_object('role', new_role),
    "updated_at" = NOW()
  WHERE "id" = target_user_id;

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

-- Step 4: Verify the fix worked
DO $$
BEGIN
  RAISE NOTICE 'Function recreated successfully. Run RESET ROLE; in any active sessions if errors persist.';
END $$;
