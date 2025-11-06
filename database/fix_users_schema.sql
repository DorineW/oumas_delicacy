-- 1) Add missing updated_at column
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 2) Create profile for dorinewairimu001
INSERT INTO public.users (auth_id, email, name, phone, role, created_at, updated_at)
SELECT 
  id,
  email,
  COALESCE(raw_user_meta_data->>'name', email),
  raw_user_meta_data->>'phone',
  COALESCE(raw_user_meta_data->>'role', 'customer'),
  NOW(),
  NOW()
FROM auth.users
WHERE email = 'dorinewairimu001@example.com'
ON CONFLICT (auth_id) DO NOTHING;

-- 3) Verify profile was created
SELECT * FROM public.users WHERE email = 'dorinewairimu001@example.com';

-- 4) Create profiles for ALL auth users missing a profile
INSERT INTO public.users (auth_id, email, name, phone, role, created_at, updated_at)
SELECT 
  au.id,
  au.email,
  COALESCE(au.raw_user_meta_data->>'name', au.email),
  au.raw_user_meta_data->>'phone',
  COALESCE(au.raw_user_meta_data->>'role', 'customer'),
  NOW(),
  NOW()
FROM auth.users au
LEFT JOIN public.users pu ON au.id = pu.auth_id
WHERE pu.auth_id IS NULL
ON CONFLICT (auth_id) DO NOTHING;

-- 5) Verify all users now have profiles
SELECT 
  COUNT(*) as total_auth_users,
  (SELECT COUNT(*) FROM public.users) as total_profiles
FROM auth.users;
