-- Verify the rider assignment saved
SELECT 
  id,
  rider_id,
  rider_name,
  status
FROM orders
WHERE id = 'ec0e5280-4447-4fdb-ac84-5cf63aa4ff94';
