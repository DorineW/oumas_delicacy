-- Find the auth user and create the missing profile
INSERT INTO public.users (auth_id, email, name, phone, role, created_at, updated_at)
SELECT 
  id,
  email,
  COALESCE(raw_user_meta_data->>'name', email), -- use metadata name or fallback to email
  raw_user_meta_data->>'phone',
  COALESCE(raw_user_meta_data->>'role', 'customer'),
  NOW(),
  NOW()
FROM auth.users
WHERE email = 'dorinewairimu001@example.com' -- CHANGE: Replace with actual email
ON CONFLICT (auth_id) DO NOTHING;

-- Verify the profile was created
SELECT * FROM public.users WHERE email = 'dorinewairimu001@example.com';
