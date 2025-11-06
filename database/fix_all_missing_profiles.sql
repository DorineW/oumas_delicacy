-- Create profiles for ALL auth users missing a public.users row
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
WHERE pu.auth_id IS NULL  -- Only users WITHOUT a profile
ON CONFLICT (auth_id) DO NOTHING;

-- Verify: Check that all auth users now have profiles
SELECT 
  COUNT(*) as total_auth_users,
  (SELECT COUNT(*) FROM public.users) as total_profiles,
  CASE 
    WHEN COUNT(*) = (SELECT COUNT(*) FROM public.users) THEN '✅ All users have profiles'
    ELSE '❌ Some users missing profiles'
  END as status
FROM auth.users;
