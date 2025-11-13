-- Test if admin can update orders
-- First, verify you're testing with the correct admin
SELECT auth_id, email, role 
FROM users 
WHERE role = 'admin';

-- Check the is_admin function for your admin
SELECT public.is_admin('f6b30df2-25b8-468d-a360-cf746298d039'::uuid) as admin_check;

-- Try to manually assign the rider to test the policy
UPDATE orders 
SET 
  rider_id = 'ae4bfde4-df50-423e-9068-8a981429522b',
  rider_name = 'Test Rider',
  status = 'outForDelivery'
WHERE id = 'ec0e5280-4447-4fdb-ac84-5cf63aa4ff94';

-- Verify the update worked
SELECT 
  id,
  rider_id,
  rider_name,
  status
FROM orders
WHERE id = 'ec0e5280-4447-4fdb-ac84-5cf63aa4ff94';
