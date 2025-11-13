-- Test if the is_admin function works for your admin user
-- Replace with your actual admin auth_id
SELECT public.is_admin('008d2243-d8c7-42f1-b211-66c6da03c003'::uuid) as is_admin_result;

-- Also check what your admin's auth_id actually is
SELECT auth_id, email, role 
FROM users 
WHERE email = 'admin@test.com';

-- Check all admin users
SELECT auth_id, email, role 
FROM users 
WHERE role = 'admin';
