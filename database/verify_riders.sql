-- ============================================================================
-- Verify and Add Riders
-- ============================================================================

-- 1. Check current riders
SELECT 
  auth_id,
  email,
  name,
  phone,
  role,
  created_at
FROM public.users
WHERE role = 'rider'
ORDER BY name;

-- 2. Convert existing users to riders:
-- (Replace with actual auth_id values from your users table)
-- First, find users you want to make riders:
SELECT auth_id, email, name, role
FROM public.users
WHERE role = 'customer'
LIMIT 5;

-- Then update a user to rider role:
-- UPDATE public.users 
-- SET role = 'rider'
-- WHERE email = 'some-existing-user@example.com';

-- OR: Create test accounts properly through Supabase Auth first,
-- then they'll appear in users table and you can update their role

-- 3. Verify total count
SELECT COUNT(*) as total_riders
FROM public.users
WHERE role = 'rider';
