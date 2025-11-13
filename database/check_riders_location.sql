-- ============================================================================
-- Check Where Rider Data Exists
-- Description: Find riders in users, profiles, or riders tables
-- ============================================================================

-- 1. Check users table for riders
SELECT 'USERS TABLE' as source, auth_id, name, email, role
FROM public.users
WHERE role = 'rider';

-- 2. Check what columns profiles actually has
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'profiles'
ORDER BY ordinal_position;

-- 3. Check riders table
SELECT 'RIDERS TABLE' as source, auth_id, name, phone, vehicle, is_available
FROM public.riders;

-- 4. Find ALL records with role='rider' in users
SELECT 
  'ALL RIDERS' as info,
  COUNT(*) as count,
  array_agg(name) as rider_names
FROM public.users
WHERE role = 'rider';

-- 5. Show all profiles data (just see what's there)
SELECT *
FROM public.profiles
LIMIT 5;

-- Summary
DO $$
DECLARE
  users_count INTEGER;
  riders_count INTEGER;
BEGIN
  -- Count riders in users table
  SELECT COUNT(*) INTO users_count
  FROM public.users
  WHERE role = 'rider';
  
  -- Count riders in riders table
  SELECT COUNT(*) INTO riders_count
  FROM public.riders;
  
  RAISE NOTICE '📊 RIDER DATA LOCATION:';
  RAISE NOTICE '   - Users table (role=rider): % records', users_count;
  RAISE NOTICE '   - Riders table: % records', riders_count;
  
  IF users_count > 0 THEN
    RAISE NOTICE '✅ Use: SELECT auth_id, name FROM users WHERE role = ''rider''';
  ELSIF riders_count > 0 THEN
    RAISE NOTICE '✅ Use: SELECT auth_id, name FROM riders';
  ELSE
    RAISE NOTICE '❌ No riders found! Need to add test rider data';
  END IF;
END $$;
