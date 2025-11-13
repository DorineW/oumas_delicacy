-- ============================================================================
-- Check Rider Assignment
-- Description: Verify the order has rider_id set correctly
-- ============================================================================

-- Check the specific order that was assigned
SELECT 
  id,
  user_auth_id,
  rider_id,
  rider_name,
  status,
  total,
  placed_at,
  delivered_at
FROM orders
WHERE id = 'ec0e5280-4447-4fdb-ac84-5cf63aa4ff94';

-- Check all orders with rider assigned
SELECT 
  id,
  user_auth_id,
  rider_id,
  rider_name,
  status,
  total,
  placed_at
FROM orders
WHERE rider_id IS NOT NULL
ORDER BY placed_at DESC;

-- Verify rider exists in users table
SELECT 
  auth_id,
  name,
  role,
  email
FROM users
WHERE auth_id = 'ae4bfde4-df50-423e-9068-8a981429522b';

-- Check what the rider would see (simulating RLS)
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "ae4bfde4-df50-423e-9068-8a981429522b"}';

SELECT 
  id,
  rider_id,
  status,
  total
FROM orders
WHERE rider_id = 'ae4bfde4-df50-423e-9068-8a981429522b';

RESET ROLE;
