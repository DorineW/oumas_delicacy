-- ================================================================
-- Migration: Add Location-Based Delivery Settings
-- Date: 2025-11-15
-- Purpose: Enable dynamic delivery pricing and multi-location support
--          - Add delivery configuration to locations table
--          - Link items to specific locations for stock management
--          - Backward compatible (all columns nullable)
-- ================================================================

BEGIN;

-- ================================================================
-- Step 1: Add delivery settings to locations table
-- ================================================================

-- Add delivery configuration columns
DO $$ 
BEGIN
  -- Delivery radius in kilometers
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'locations' AND column_name = 'delivery_radius_km'
  ) THEN
    ALTER TABLE public.locations 
      ADD COLUMN delivery_radius_km NUMERIC NULL DEFAULT 10;
    
    COMMENT ON COLUMN public.locations.delivery_radius_km IS 
      'Maximum delivery distance from this location in kilometers. NULL means unlimited.';
  END IF;

  -- Base delivery fee (flat rate)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'locations' AND column_name = 'delivery_base_fee'
  ) THEN
    ALTER TABLE public.locations 
      ADD COLUMN delivery_base_fee INTEGER NULL DEFAULT 50;
    
    COMMENT ON COLUMN public.locations.delivery_base_fee IS 
      'Flat delivery fee in lowest currency unit (e.g., KES 50). NULL means free delivery.';
  END IF;

  -- Rate per kilometer
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'locations' AND column_name = 'delivery_rate_per_km'
  ) THEN
    ALTER TABLE public.locations 
      ADD COLUMN delivery_rate_per_km INTEGER NULL DEFAULT 20;
    
    COMMENT ON COLUMN public.locations.delivery_rate_per_km IS 
      'Additional fee per kilometer beyond base fee (e.g., KES 20/km). NULL means no distance-based charge.';
  END IF;

  -- Minimum order for delivery
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'locations' AND column_name = 'minimum_order_amount'
  ) THEN
    ALTER TABLE public.locations 
      ADD COLUMN minimum_order_amount INTEGER NULL DEFAULT 0;
    
    COMMENT ON COLUMN public.locations.minimum_order_amount IS 
      'Minimum order value required for delivery. 0 or NULL means no minimum.';
  END IF;

  -- Free delivery threshold
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'locations' AND column_name = 'free_delivery_threshold'
  ) THEN
    ALTER TABLE public.locations 
      ADD COLUMN free_delivery_threshold INTEGER NULL;
    
    COMMENT ON COLUMN public.locations.free_delivery_threshold IS 
      'Order amount above which delivery is free. NULL means no free delivery promotion.';
  END IF;
END $$;

-- ================================================================
-- Step 2: Link StoreItems to locations (for stock management)
-- ================================================================

DO $$ 
BEGIN
  -- Add location_id to StoreItems
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'StoreItems' AND column_name = 'location_id'
  ) THEN
    ALTER TABLE public."StoreItems" 
      ADD COLUMN location_id UUID NULL;
    
    ALTER TABLE public."StoreItems"
      ADD CONSTRAINT StoreItems_location_id_fkey 
      FOREIGN KEY (location_id) 
      REFERENCES public.locations (id) 
      ON DELETE SET NULL;
    
    CREATE INDEX idx_storeitems_location_id 
      ON public."StoreItems" USING btree (location_id);
    
    COMMENT ON COLUMN public."StoreItems".location_id IS 
      'Location where this item is available. NULL means available at all locations (default behavior).';
  END IF;

  -- Add stock quantity tracking
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'StoreItems' AND column_name = 'stock_quantity'
  ) THEN
    ALTER TABLE public."StoreItems" 
      ADD COLUMN stock_quantity INTEGER NULL;
    
    COMMENT ON COLUMN public."StoreItems".stock_quantity IS 
      'Current stock level. NULL means unlimited/not tracked. 0 means out of stock.';
  END IF;

  -- Add low stock threshold for alerts
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'StoreItems' AND column_name = 'low_stock_threshold'
  ) THEN
    ALTER TABLE public."StoreItems" 
      ADD COLUMN low_stock_threshold INTEGER NULL DEFAULT 10;
    
    COMMENT ON COLUMN public."StoreItems".low_stock_threshold IS 
      'Quantity below which to trigger low stock alert. NULL means no alerts.';
  END IF;
END $$;

-- ================================================================
-- Step 3: Link menu_items to locations (for restaurant chains)
-- ================================================================

DO $$ 
BEGIN
  -- Add location_id to menu_items
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'menu_items' AND column_name = 'location_id'
  ) THEN
    ALTER TABLE public.menu_items 
      ADD COLUMN location_id UUID NULL;
    
    ALTER TABLE public.menu_items
      ADD CONSTRAINT menu_items_location_id_fkey 
      FOREIGN KEY (location_id) 
      REFERENCES public.locations (id) 
      ON DELETE SET NULL;
    
    CREATE INDEX idx_menu_items_location_id 
      ON public.menu_items USING btree (location_id);
    
    COMMENT ON COLUMN public.menu_items.location_id IS 
      'Restaurant location serving this menu item. NULL means available at all locations.';
  END IF;
END $$;

-- ================================================================
-- Step 4: Add location to orders (track which location fulfilled order)
-- ================================================================

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'orders' AND column_name = 'fulfillment_location_id'
  ) THEN
    ALTER TABLE public.orders 
      ADD COLUMN fulfillment_location_id UUID NULL;
    
    ALTER TABLE public.orders
      ADD CONSTRAINT orders_fulfillment_location_id_fkey 
      FOREIGN KEY (fulfillment_location_id) 
      REFERENCES public.locations (id) 
      ON DELETE SET NULL;
    
    CREATE INDEX idx_orders_fulfillment_location_id 
      ON public.orders USING btree (fulfillment_location_id);
    
    COMMENT ON COLUMN public.orders.fulfillment_location_id IS 
      'Location that fulfilled this order. Used for tracking and reporting.';
  END IF;
END $$;

COMMIT;

-- ================================================================
-- Verification Queries
-- ================================================================

-- Check locations table new columns
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'locations'
  AND column_name IN (
    'delivery_radius_km',
    'delivery_base_fee',
    'delivery_rate_per_km',
    'minimum_order_amount',
    'free_delivery_threshold'
  )
ORDER BY ordinal_position;

-- Check StoreItems new columns
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'StoreItems'
  AND column_name IN ('location_id', 'stock_quantity', 'low_stock_threshold')
ORDER BY ordinal_position;

-- Check menu_items location_id
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'menu_items'
  AND column_name = 'location_id';

-- Check orders fulfillment_location_id
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'orders'
  AND column_name = 'fulfillment_location_id';

-- Check indexes
SELECT 
  tablename,
  indexname,
  indexdef
FROM pg_indexes
WHERE indexname IN (
  'idx_storeitems_location_id',
  'idx_menu_items_location_id',
  'idx_orders_fulfillment_location_id'
);

-- ================================================================
-- Example Usage
-- ================================================================

-- Example 1: Configure different delivery settings for each location/region
/*
-- Urban location - Higher density, shorter radius, lower base fee
UPDATE public.locations
SET 
  delivery_radius_km = 10,              -- Deliver within 10km (urban area)
  delivery_base_fee = 50,               -- KES 50 base fee (lower for urban)
  delivery_rate_per_km = 20,            -- KES 20 per km
  minimum_order_amount = 300,           -- Lower minimum (KES 300)
  free_delivery_threshold = 1500        -- Free delivery over KES 1500
WHERE name = 'Downtown Restaurant';

-- Suburban location - Medium radius, medium fees
UPDATE public.locations
SET 
  delivery_radius_km = 15,              -- Deliver within 15km
  delivery_base_fee = 100,              -- KES 100 base fee
  delivery_rate_per_km = 30,            -- KES 30 per km
  minimum_order_amount = 500,           -- KES 500 minimum
  free_delivery_threshold = 2000        -- Free delivery over KES 2000
WHERE name = 'Westlands Branch';

-- Rural/Remote location - Larger radius, higher fees
UPDATE public.locations
SET 
  delivery_radius_km = 25,              -- Deliver within 25km (rural area needs wider reach)
  delivery_base_fee = 200,              -- KES 200 base fee (higher due to distance)
  delivery_rate_per_km = 50,            -- KES 50 per km (rough terrain, fuel costs)
  minimum_order_amount = 1000,          -- Higher minimum (KES 1000)
  free_delivery_threshold = 3000        -- Free delivery over KES 3000
WHERE name = 'Ngong Branch';
*/

-- Example 2: Assign a store item to a specific location with stock tracking
/*
UPDATE public."StoreItems"
SET 
  location_id = '00000000-0000-0000-0000-000000000000',
  stock_quantity = 100,
  low_stock_threshold = 20
WHERE id = '00000000-0000-0000-0000-000000000001';
*/

-- Example 3: Calculate delivery fee for a user's address from EACH location
-- Each location has its own pricing - rates vary by region
/*
WITH user_location AS (
  SELECT latitude, longitude
  FROM public."UserAddresses"
  WHERE user_auth_id = auth.uid()
    AND is_default = true
  LIMIT 1
)
SELECT 
  l.id AS location_id,
  l.name AS location_name,
  l.location_type,
  -- Calculate distance using Haversine formula
  (
    6371 * acos(
      cos(radians(ul.latitude)) * 
      cos(radians(l.lat)) * 
      cos(radians(l.lon) - radians(ul.longitude)) + 
      sin(radians(ul.latitude)) * 
      sin(radians(l.lat))
    )
  ) AS distance_km,
  l.delivery_radius_km,
  l.delivery_base_fee,
  l.delivery_rate_per_km,
  -- Delivery status
  CASE 
    WHEN l.delivery_radius_km IS NULL THEN 'Unlimited delivery'
    WHEN (
      6371 * acos(
        cos(radians(ul.latitude)) * 
        cos(radians(l.lat)) * 
        cos(radians(l.lon) - radians(ul.longitude)) + 
        sin(radians(ul.latitude)) * 
        sin(radians(l.lat))
      )
    ) <= l.delivery_radius_km THEN 'Within delivery zone'
    ELSE 'Outside delivery zone'
  END AS delivery_status,
  -- Calculate fee (each location has different rates)
  -- Formula: base_fee + (distance_from_0km * rate_per_km)
  CASE 
    WHEN l.delivery_radius_km IS NOT NULL 
      AND (
        6371 * acos(
          cos(radians(ul.latitude)) * 
          cos(radians(l.lat)) * 
          cos(radians(l.lon) - radians(ul.longitude)) + 
          sin(radians(ul.latitude)) * 
          sin(radians(l.lat))
        )
      ) > l.delivery_radius_km THEN NULL  -- Outside zone
    ELSE 
      -- Base fee + (actual distance starting from 0km * per km rate)
      COALESCE(l.delivery_base_fee, 0) + 
      ROUND(
        (
          6371 * acos(
            cos(radians(ul.latitude)) * 
            cos(radians(l.lat)) * 
            cos(radians(l.lon) - radians(ul.longitude)) + 
            sin(radians(ul.latitude)) * 
            sin(radians(l.lat))
          )
        ) * COALESCE(l.delivery_rate_per_km, 0)
      )
  END AS delivery_fee,
  l.free_delivery_threshold
FROM public.locations l, user_location ul
WHERE l.is_active = true
  AND l.location_type IN ('Restaurant', 'General Store')
ORDER BY 
  -- Show locations that can deliver first, then by distance
  CASE 
    WHEN l.delivery_radius_km IS NULL THEN 0
    WHEN (
      6371 * acos(
        cos(radians(ul.latitude)) * 
        cos(radians(l.lat)) * 
        cos(radians(l.lon) - radians(ul.longitude)) + 
        sin(radians(ul.latitude)) * 
        sin(radians(l.lat))
      )
    ) <= l.delivery_radius_km THEN 1
    ELSE 2
  END,
  distance_km;
*/

-- Example 4: Get items available at a specific location
/*
SELECT 
  si.id,
  si.name,
  si.price,
  si.stock_quantity,
  l.name AS location_name
FROM public."StoreItems" si
LEFT JOIN public.locations l ON si.location_id = l.id
WHERE si.available = true
  AND (
    si.location_id IS NULL  -- Available everywhere
    OR si.location_id = '00000000-0000-0000-0000-000000000000'  -- Or at specific location
  )
  AND (si.stock_quantity IS NULL OR si.stock_quantity > 0);  -- In stock or not tracked
*/

-- Example 5: Find locations serving a user's area
/*
WITH user_location AS (
  SELECT latitude, longitude
  FROM public."UserAddresses"
  WHERE user_auth_id = auth.uid()
    AND is_default = true
  LIMIT 1
)
SELECT 
  l.id,
  l.name,
  l.location_type,
  l.delivery_radius_km,
  l.delivery_base_fee,
  (
    6371 * acos(
      cos(radians(ul.latitude)) * 
      cos(radians(l.lat)) * 
      cos(radians(l.lon) - radians(ul.longitude)) + 
      sin(radians(ul.latitude)) * 
      sin(radians(l.lat))
    )
  ) AS distance_km
FROM public.locations l, user_location ul
WHERE l.is_active = true
  AND (
    l.delivery_radius_km IS NULL  -- Unlimited delivery
    OR (
      6371 * acos(
        cos(radians(ul.latitude)) * 
        cos(radians(l.lat)) * 
        cos(radians(l.lon) - radians(ul.longitude)) + 
        sin(radians(ul.latitude)) * 
        sin(radians(l.lat))
      )
    ) <= l.delivery_radius_km
  )
ORDER BY distance_km;
*/

-- Example 6: Stock alert - Items running low at each location
/*
SELECT 
  l.name AS location_name,
  si.name AS item_name,
  si.stock_quantity,
  si.low_stock_threshold,
  si.stock_quantity - si.low_stock_threshold AS units_above_threshold
FROM public."StoreItems" si
JOIN public.locations l ON si.location_id = l.id
WHERE si.stock_quantity IS NOT NULL
  AND si.low_stock_threshold IS NOT NULL
  AND si.stock_quantity <= si.low_stock_threshold
ORDER BY l.name, si.stock_quantity;
*/
