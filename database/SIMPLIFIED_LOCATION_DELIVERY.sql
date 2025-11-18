-- ============================================
-- SIMPLIFIED LOCATION-BASED DELIVERY (Uber Eats Style)
-- ============================================
-- Minimal changes to support location-based ordering like Uber Eats
-- Can be implemented quickly without major refactoring

-- ============================================
-- STEP 1: Ensure locations have delivery settings
-- ============================================
-- These columns should already exist, just verifying

DO $$ 
BEGIN
  -- Verify delivery_radius_km exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'locations' AND column_name = 'delivery_radius_km'
  ) THEN
    ALTER TABLE public.locations ADD COLUMN delivery_radius_km NUMERIC DEFAULT 10;
  END IF;

  -- Verify delivery_base_fee exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'locations' AND column_name = 'delivery_base_fee'
  ) THEN
    ALTER TABLE public.locations ADD COLUMN delivery_base_fee INTEGER DEFAULT 50;
  END IF;

  -- Verify delivery_rate_per_km exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'locations' AND column_name = 'delivery_rate_per_km'
  ) THEN
    ALTER TABLE public.locations ADD COLUMN delivery_rate_per_km INTEGER DEFAULT 20;
  END IF;

  -- Verify minimum_order_amount exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'locations' AND column_name = 'minimum_order_amount'
  ) THEN
    ALTER TABLE public.locations ADD COLUMN minimum_order_amount INTEGER DEFAULT 0;
  END IF;
END $$;

-- ============================================
-- STEP 2: Create function to check if location can deliver to address
-- ============================================
CREATE OR REPLACE FUNCTION can_deliver_to_address(
  location_id_param uuid,
  customer_lat NUMERIC,
  customer_lon NUMERIC
)
RETURNS BOOLEAN AS $$
DECLARE
  location_lat NUMERIC;
  location_lon NUMERIC;
  radius_km NUMERIC;
  distance NUMERIC;
BEGIN
  -- Get location coordinates and delivery radius
  SELECT lat, lon, COALESCE(delivery_radius_km, 10)
  INTO location_lat, location_lon, radius_km
  FROM public.locations
  WHERE id = location_id_param AND is_active = true;
  
  -- If location not found or no coordinates, can't deliver
  IF location_lat IS NULL OR location_lon IS NULL THEN
    RETURN false;
  END IF;
  
  -- Calculate distance using haversine formula
  distance := 6371 * acos(
    cos(radians(customer_lat)) * 
    cos(radians(location_lat)) * 
    cos(radians(location_lon) - radians(customer_lon)) + 
    sin(radians(customer_lat)) * 
    sin(radians(location_lat))
  );
  
  -- Return true if within radius
  RETURN distance <= radius_km;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION can_deliver_to_address IS 
  'Checks if a location can deliver to the given address coordinates. Returns true if within delivery_radius_km.';

-- ============================================
-- STEP 3: Create function to calculate delivery fee
-- ============================================
CREATE OR REPLACE FUNCTION calculate_delivery_fee(
  location_id_param uuid,
  customer_lat NUMERIC,
  customer_lon NUMERIC
)
RETURNS NUMERIC AS $$
DECLARE
  base_fee INTEGER;
  rate_per_km INTEGER;
  distance_km NUMERIC;
  total_fee NUMERIC;
  location_lat NUMERIC;
  location_lon NUMERIC;
BEGIN
  -- Get location details
  SELECT 
    l.delivery_base_fee,
    l.delivery_rate_per_km,
    l.lat,
    l.lon
  INTO 
    base_fee,
    rate_per_km,
    location_lat,
    location_lon
  FROM public.locations l
  WHERE l.id = location_id_param AND l.is_active = true;
  
  -- If no coordinates, return base fee only
  IF location_lat IS NULL OR location_lon IS NULL THEN
    RETURN COALESCE(base_fee, 50);
  END IF;
  
  -- Calculate distance
  distance_km := ROUND(
    CAST(
      6371 * acos(
        cos(radians(customer_lat)) * 
        cos(radians(location_lat)) * 
        cos(radians(location_lon) - radians(customer_lon)) + 
        sin(radians(customer_lat)) * 
        sin(radians(location_lat))
      ) AS NUMERIC
    ), 
    2
  );
  
  -- Calculate total fee
  total_fee := COALESCE(base_fee, 50) + (distance_km * COALESCE(rate_per_km, 20));
  
  RETURN ROUND(total_fee, 0);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION calculate_delivery_fee IS 
  'Calculates delivery fee for a location to customer address. Returns base_fee + (distance * rate_per_km).';

-- ============================================
-- STEP 4: Create view for available locations at customer address
-- ============================================
-- This view will be used to show which restaurants/stores can deliver
-- Pass customer lat/lon as parameters

CREATE OR REPLACE FUNCTION get_available_locations_for_address(
  customer_lat NUMERIC,
  customer_lon NUMERIC
)
RETURNS TABLE(
  location_id uuid,
  location_name text,
  location_type text,
  address jsonb,
  delivery_fee NUMERIC,
  distance_km NUMERIC,
  is_active boolean,
  menu_item_count bigint,
  store_item_count bigint
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    l.id,
    l.name,
    l.location_type,
    l.address,
    calculate_delivery_fee(l.id, customer_lat, customer_lon) AS delivery_fee,
    ROUND(
      CAST(
        6371 * acos(
          cos(radians(customer_lat)) * 
          cos(radians(l.lat)) * 
          cos(radians(l.lon) - radians(customer_lon)) + 
          sin(radians(customer_lat)) * 
          sin(radians(l.lat))
        ) AS NUMERIC
      ), 
      2
    ) AS distance_km,
    l.is_active,
    (SELECT COUNT(*) FROM public.menu_items mi WHERE mi.location_id = l.id AND mi.available = true) AS menu_item_count,
    (SELECT COUNT(*) FROM public."StoreItems" si WHERE si.location_id = l.id AND si.available = true) AS store_item_count
  FROM public.locations l
  WHERE l.is_active = true
    AND l.lat IS NOT NULL 
    AND l.lon IS NOT NULL
    -- Only locations that can deliver to this address
    AND can_deliver_to_address(l.id, customer_lat, customer_lon) = true
  ORDER BY distance_km ASC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_available_locations_for_address IS 
  'Returns all locations that can deliver to the given address, with delivery fees and item counts. Like Uber Eats restaurant list.';

-- ============================================
-- STEP 5: Add validation for checkout
-- ============================================
CREATE OR REPLACE FUNCTION validate_order_location(
  location_id_param uuid,
  customer_lat NUMERIC,
  customer_lon NUMERIC
)
RETURNS jsonb AS $$
DECLARE
  can_deliver BOOLEAN;
  delivery_fee NUMERIC;
  min_order INTEGER;
  result jsonb;
BEGIN
  -- Check if location can deliver
  can_deliver := can_deliver_to_address(location_id_param, customer_lat, customer_lon);
  
  IF NOT can_deliver THEN
    RETURN jsonb_build_object(
      'valid', false,
      'error', 'This location cannot deliver to your address. Please choose a different location or change your delivery address.',
      'error_code', 'OUT_OF_DELIVERY_RANGE'
    );
  END IF;
  
  -- Get delivery fee and minimum order
  SELECT 
    calculate_delivery_fee(location_id_param, customer_lat, customer_lon),
    COALESCE(minimum_order_amount, 0)
  INTO delivery_fee, min_order;
  
  RETURN jsonb_build_object(
    'valid', true,
    'delivery_fee', delivery_fee,
    'minimum_order_amount', min_order
  );
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION validate_order_location IS 
  'Validates if an order can be placed from a location to customer address. Used at checkout to prevent invalid orders.';

-- ============================================
-- SUCCESS MESSAGE
-- ============================================
SELECT 'Simplified location-based delivery setup complete! 

Usage in Flutter:
1. Get customer address lat/lon
2. Call get_available_locations_for_address(lat, lon) to show locations
3. User selects a location (restaurant/store)
4. Show menu/store items for that location
5. At checkout, call validate_order_location() before placing order
6. If valid=false, show error and prevent checkout

This works like Uber Eats - user sees only locations that deliver to them!
' AS status;
