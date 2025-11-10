-- ============================================
-- USER ROLE MANAGEMENT
-- Replace 'user@actual-email.com' with the real user's email
-- ============================================

-- Make a user an ADMIN
UPDATE public.users
SET role = 'admin', updated_at = NOW()
WHERE email = 'user@actual-email.com'; -- REPLACE with real email

-- Make a user a RIDER
UPDATE public.users
SET role = 'rider', updated_at = NOW()
WHERE email = 'user@actual-email.com'; -- REPLACE with real email

-- Make a user a CUSTOMER (default)
UPDATE public.users
SET role = 'customer', updated_at = NOW()
WHERE email = 'user@actual-email.com'; -- REPLACE with real email

-- Verify the change
SELECT auth_id, email, name, role, created_at
FROM public.users
ORDER BY created_at DESC
LIMIT 10;

-- ============================================
-- View all users and their roles
-- ============================================
SELECT email, name, role, created_at
FROM public.users
ORDER BY created_at DESC;
