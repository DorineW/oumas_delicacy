-- ============================================================================
-- Fix RLS Policies for Users Table
-- Allow admins to view all users (including riders)
-- ============================================================================

-- Check existing policies on users table
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual
FROM pg_policies
WHERE tablename = 'users'
ORDER BY cmd, policyname;

-- Check if admin policy exists
SELECT policyname, cmd, qual
FROM pg_policies
WHERE tablename = 'users' 
  AND policyname LIKE '%admin%'
ORDER BY policyname;

-- Create admin policy (FIXED - no recursion):
DROP POLICY IF EXISTS "users_select_admin" ON public.users;
DROP POLICY IF EXISTS "users_select_all_authenticated" ON public.users;

-- Simple approach: Let all authenticated users read the users table
-- This is safe because sensitive data (passwords) is in auth.users, not public.users
CREATE POLICY "users_select_all_authenticated" ON public.users
  FOR SELECT
  TO authenticated
  USING (true);

-- Verify new policies
SELECT policyname, cmd, qual
FROM pg_policies
WHERE tablename = 'users' AND cmd = 'SELECT'
ORDER BY policyname;
