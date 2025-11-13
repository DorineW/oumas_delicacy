-- Check UPDATE policies for orders table
SELECT 
  policyname,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'orders' 
  AND cmd = 'UPDATE'
ORDER BY policyname;
