-- Initialize Inventory for Existing Products
-- Run this AFTER you have added at least one location via the admin panel

-- This script will:
-- 1. Find your first active location
-- 2. Create inventory records for all your products at that location
-- 3. Set default quantities and minimum stock alerts

DO $$ 
DECLARE
  v_first_location_id uuid;
  v_products_count integer;
BEGIN
  -- Get first active location
  SELECT id INTO v_first_location_id
  FROM public.locations
  WHERE is_active = true
  ORDER BY created_at
  LIMIT 1;

  IF v_first_location_id IS NULL THEN
    RAISE EXCEPTION 'No active location found! Please add a location first via Admin Dashboard → Location Management';
  END IF;

  RAISE NOTICE 'Using location: %', v_first_location_id;

  -- Create inventory records for all products that don't have inventory yet
  INSERT INTO public."ProductInventory" (product_id, location_id, quantity, minimum_stock_alert)
  SELECT 
    p.id,
    v_first_location_id,
    50, -- Default quantity (adjust as needed)
    10  -- Default minimum alert threshold
  FROM public.products p
  WHERE NOT EXISTS (
    SELECT 1 FROM public."ProductInventory" pi
    WHERE pi.product_id = p.id AND pi.location_id = v_first_location_id
  );

  -- Get count of initialized products
  GET DIAGNOSTICS v_products_count = ROW_COUNT;
  
  RAISE NOTICE '✅ Initialized inventory for % products at location %', 
    v_products_count, v_first_location_id;
    
  -- Show summary
  RAISE NOTICE 'Summary:';
  RAISE NOTICE '  - Total products in catalog: %', (SELECT COUNT(*) FROM public.products);
  RAISE NOTICE '  - Products with inventory: %', (
    SELECT COUNT(DISTINCT product_id) 
    FROM public."ProductInventory" 
    WHERE location_id = v_first_location_id
  );
  RAISE NOTICE '  - Total inventory units: %', (
    SELECT SUM(quantity) 
    FROM public."ProductInventory" 
    WHERE location_id = v_first_location_id
  );
    
END $$;

-- Verify the setup
SELECT 
  l.name as location,
  COUNT(DISTINCT pi.product_id) as products_stocked,
  SUM(pi.quantity) as total_units,
  SUM(CASE WHEN pi.quantity <= pi.minimum_stock_alert THEN 1 ELSE 0 END) as low_stock_items,
  SUM(CASE WHEN pi.quantity = 0 THEN 1 ELSE 0 END) as out_of_stock_items
FROM public.locations l
LEFT JOIN public."ProductInventory" pi ON pi.location_id = l.id
WHERE l.is_active = true
GROUP BY l.id, l.name
ORDER BY l.created_at;
