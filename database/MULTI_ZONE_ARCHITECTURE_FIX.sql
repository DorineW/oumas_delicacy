-- ============================================
-- MULTI-ZONE ARCHITECTURE FIX
-- ============================================
-- This migration implements proper location/zone isolation for:
-- 1. Customers can only see items from their serving location
-- 2. Admins can only manage their assigned location(s)
-- 3. Riders are assigned to specific locations
-- 4. Menu items (restaurant) don't use inventory
-- 5. Store items use inventory per location
-- 6. Delivery is calculated per location

-- ============================================
-- STEP 1: Add location assignment to users
-- ============================================
DO $$ 
BEGIN
  -- Add serving_location_id to users (which location serves this customer)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'users' AND column_name = 'serving_location_id'
  ) THEN
    ALTER TABLE public.users 
      ADD COLUMN serving_location_id uuid;
    
    ALTER TABLE public.users
      ADD CONSTRAINT users_serving_location_id_fkey 
      FOREIGN KEY (serving_location_id) 
      REFERENCES public.locations (id) 
      ON DELETE SET NULL;
    
    CREATE INDEX idx_users_serving_location 
      ON public.users USING btree (serving_location_id);
    
    RAISE NOTICE 'Added serving_location_id to users';
  END IF;

  -- Add managed_location_ids for admins (can manage multiple locations)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'users' AND column_name = 'managed_location_ids'
  ) THEN
    ALTER TABLE public.users 
      ADD COLUMN managed_location_ids uuid[] DEFAULT ARRAY[]::uuid[];
    
    CREATE INDEX idx_users_managed_locations 
      ON public.users USING GIN (managed_location_ids);
    
    RAISE NOTICE 'Added managed_location_ids to users';
  END IF;
END $$;

COMMENT ON COLUMN public.users.serving_location_id IS 
  'The location that serves this customer. Customers can only see menu/store items from this location. Set based on their delivery address during registration.';

COMMENT ON COLUMN public.users.managed_location_ids IS 
  'Array of location IDs that this admin can manage. Used for location-specific admin access control.';

-- ============================================
-- STEP 2: Add location assignment to riders
-- ============================================
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'riders' AND column_name = 'assigned_location_id'
  ) THEN
    ALTER TABLE public.riders 
      ADD COLUMN assigned_location_id uuid;
    
    ALTER TABLE public.riders
      ADD CONSTRAINT riders_assigned_location_id_fkey 
      FOREIGN KEY (assigned_location_id) 
      REFERENCES public.locations (id) 
      ON DELETE SET NULL;
    
    CREATE INDEX idx_riders_assigned_location 
      ON public.riders USING btree (assigned_location_id, is_available);
    
    RAISE NOTICE 'Added assigned_location_id to riders';
  END IF;
END $$;

COMMENT ON COLUMN public.riders.assigned_location_id IS 
  'The location/zone this rider operates in. Riders can only be assigned orders from their assigned location.';

-- ============================================
-- STEP 3: Ensure location_id is NOT NULL for menu_items and StoreItems
-- ============================================
-- Menu items must belong to a location
DO $$
BEGIN
  -- Check if there are menu_items without location_id
  IF EXISTS (SELECT 1 FROM public.menu_items WHERE location_id IS NULL) THEN
    RAISE NOTICE 'WARNING: Found menu_items without location_id. Please assign locations before making this NOT NULL.';
  ELSE
    -- Make location_id NOT NULL
    ALTER TABLE public.menu_items 
      ALTER COLUMN location_id SET NOT NULL;
    
    RAISE NOTICE 'Made menu_items.location_id NOT NULL';
  END IF;
END $$;

-- Store items must belong to a location
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public."StoreItems" WHERE location_id IS NULL) THEN
    RAISE NOTICE 'WARNING: Found StoreItems without location_id. Please assign locations before making this NOT NULL.';
  ELSE
    ALTER TABLE public."StoreItems" 
      ALTER COLUMN location_id SET NOT NULL;
    
    RAISE NOTICE 'Made StoreItems.location_id NOT NULL';
  END IF;
END $$;

-- ============================================
-- STEP 4: Remove inventory columns from menu_items
-- ============================================
-- Menu items (restaurant food) don't track inventory
-- Only StoreItems use ProductInventory

COMMENT ON TABLE public.menu_items IS 
  'Restaurant menu items. These are made-to-order and do NOT track inventory. Use available=false to mark as unavailable.';

COMMENT ON TABLE public."StoreItems" IS 
  'Store/retail items that have physical inventory. Stock is tracked in ProductInventory table per location.';

-- ============================================
-- STEP 5: Create view for customer-available items
-- ============================================
-- This view shows only items available at the customer's serving location

CREATE OR REPLACE VIEW customer_available_menu_items AS
SELECT 
  mi.id,
  mi.product_id,
  mi.name,
  mi.description,
  mi.price,
  mi.available,
  mi.category,
  mi.meal_weight,
  mi.image_url,
  mi.location_id,
  l.name AS location_name,
  'Food' AS item_type
FROM public.menu_items mi
JOIN public.locations l ON mi.location_id = l.id
WHERE mi.available = true 
  AND l.is_active = true;

CREATE OR REPLACE VIEW customer_available_store_items AS
SELECT 
  si.id,
  si.product_id,
  si.name,
  si.description,
  si.price,
  si.available,
  si.category,
  si.unit_of_measure,
  si.unit_description,
  si.image_url,
  si.location_id,
  l.name AS location_name,
  pi.quantity AS current_stock,
  'Store Item' AS item_type
FROM public."StoreItems" si
JOIN public.locations l ON si.location_id = l.id
LEFT JOIN public."ProductInventory" pi ON si.product_id = pi.product_id AND si.location_id = pi.location_id
WHERE si.available = true 
  AND l.is_active = true
  AND (pi.quantity IS NULL OR pi.quantity > 0); -- Only show items in stock

COMMENT ON VIEW customer_available_menu_items IS 
  'Menu items available for ordering. Filter by users.serving_location_id to show items for specific customer.';

COMMENT ON VIEW customer_available_store_items IS 
  'Store items available for ordering with current stock levels. Filter by users.serving_location_id.';

-- ============================================
-- STEP 6: Create function to determine serving location
-- ============================================
CREATE OR REPLACE FUNCTION find_serving_location(
  customer_lat NUMERIC,
  customer_lon NUMERIC
)
RETURNS uuid AS $$
DECLARE
  closest_location uuid;
BEGIN
  -- Find the closest active location within its delivery radius
  SELECT l.id INTO closest_location
  FROM public.locations l
  WHERE l.is_active = true
    AND l.lat IS NOT NULL 
    AND l.lon IS NOT NULL
    -- Check if customer is within delivery radius using haversine formula
    AND (
      6371 * acos(
        cos(radians(customer_lat)) * 
        cos(radians(l.lat)) * 
        cos(radians(l.lon) - radians(customer_lon)) + 
        sin(radians(customer_lat)) * 
        sin(radians(l.lat))
      )
    ) <= COALESCE(l.delivery_radius_km, 10)
  ORDER BY 
    -- Sort by distance (closest first)
    (
      6371 * acos(
        cos(radians(customer_lat)) * 
        cos(radians(l.lat)) * 
        cos(radians(l.lon) - radians(customer_lon)) + 
        sin(radians(customer_lat)) * 
        sin(radians(l.lat))
      )
    ) ASC
  LIMIT 1;
  
  RETURN closest_location;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION find_serving_location IS 
  'Finds the closest active location within delivery radius for given coordinates. Returns NULL if no location serves that area.';

-- ============================================
-- STEP 7: Create function to calculate delivery fee
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
  WHERE l.id = location_id_param;
  
  -- Calculate distance if coordinates available
  IF location_lat IS NOT NULL AND location_lon IS NOT NULL THEN
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
    
    total_fee := COALESCE(base_fee, 50) + (distance_km * COALESCE(rate_per_km, 20));
  ELSE
    -- Default fee if no coordinates
    total_fee := COALESCE(base_fee, 50);
  END IF;
  
  RETURN total_fee;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION calculate_delivery_fee IS 
  'Calculates delivery fee based on location settings and distance. Returns base_fee + (distance_km * rate_per_km).';

-- ============================================
-- STEP 8: Create RLS policies for location-based access
-- ============================================

-- Customers can only see menu items from their serving location
DROP POLICY IF EXISTS "Customers see their location menu" ON public.menu_items;
CREATE POLICY "Customers see their location menu" 
  ON public.menu_items
  FOR SELECT
  USING (
    location_id IN (
      SELECT serving_location_id 
      FROM public.users 
      WHERE auth_id = auth.uid()
    )
    OR
    -- Admins can see all if they manage this location
    EXISTS (
      SELECT 1 FROM public.users
      WHERE auth_id = auth.uid()
        AND role = 'admin'
        AND menu_items.location_id = ANY(managed_location_ids)
    )
  );

-- Customers can only see store items from their serving location
DROP POLICY IF EXISTS "Customers see their location store" ON public."StoreItems";
CREATE POLICY "Customers see their location store" 
  ON public."StoreItems"
  FOR SELECT
  USING (
    location_id IN (
      SELECT serving_location_id 
      FROM public.users 
      WHERE auth_id = auth.uid()
    )
    OR
    -- Admins can see if they manage this location
    EXISTS (
      SELECT 1 FROM public.users
      WHERE auth_id = auth.uid()
        AND role = 'admin'
        AND "StoreItems".location_id = ANY(managed_location_ids)
    )
  );

-- Admins can only modify items at their managed locations
DROP POLICY IF EXISTS "Admins manage their location menu" ON public.menu_items;
CREATE POLICY "Admins manage their location menu" 
  ON public.menu_items
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE auth_id = auth.uid()
        AND role = 'admin'
        AND menu_items.location_id = ANY(managed_location_ids)
    )
  );

DROP POLICY IF EXISTS "Admins manage their location store" ON public."StoreItems";
CREATE POLICY "Admins manage their location store" 
  ON public."StoreItems"
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE auth_id = auth.uid()
        AND role = 'admin'
        AND "StoreItems".location_id = ANY(managed_location_ids)
    )
  );

-- Admins can only see inventory for their managed locations
DROP POLICY IF EXISTS "Admins see their location inventory" ON public."ProductInventory";
CREATE POLICY "Admins see their location inventory" 
  ON public."ProductInventory"
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE auth_id = auth.uid()
        AND role = 'admin'
        AND "ProductInventory".location_id = ANY(managed_location_ids)
    )
  );

-- Riders can only see orders assigned to their location
DROP POLICY IF EXISTS "Riders see their location orders" ON public.orders;
CREATE POLICY "Riders see their location orders" 
  ON public.orders
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 
      FROM public.riders r
      WHERE r.auth_id = auth.uid()
        AND orders.fulfillment_location_id = r.assigned_location_id
    )
  );

-- ============================================
-- STEP 9: Create trigger to set serving_location on user registration
-- ============================================
CREATE OR REPLACE FUNCTION set_user_serving_location()
RETURNS TRIGGER AS $$
DECLARE
  first_address_id uuid;
  address_lat NUMERIC;
  address_lon NUMERIC;
  serving_loc uuid;
BEGIN
  -- When a new user is created, try to set their serving location
  -- based on their first saved address
  IF NEW.serving_location_id IS NULL THEN
    -- Get first address if any
    SELECT id, latitude, longitude INTO first_address_id, address_lat, address_lon
    FROM public."UserAddresses"
    WHERE user_auth_id = NEW.auth_id
    ORDER BY is_default DESC, created_at ASC
    LIMIT 1;
    
    IF first_address_id IS NOT NULL THEN
      -- Find serving location
      serving_loc := find_serving_location(address_lat, address_lon);
      
      IF serving_loc IS NOT NULL THEN
        NEW.serving_location_id := serving_loc;
        RAISE NOTICE 'Set serving_location_id % for user %', serving_loc, NEW.auth_id;
      END IF;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_set_user_serving_location ON public.users;
CREATE TRIGGER trg_set_user_serving_location
  BEFORE INSERT OR UPDATE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION set_user_serving_location();

-- ============================================
-- STEP 10: Create trigger to update serving location when address added
-- ============================================
CREATE OR REPLACE FUNCTION update_serving_location_on_address()
RETURNS TRIGGER AS $$
DECLARE
  serving_loc uuid;
  current_serving uuid;
BEGIN
  -- When user adds first address or changes default address, update their serving location
  SELECT serving_location_id INTO current_serving
  FROM public.users
  WHERE auth_id = NEW.user_auth_id;
  
  -- If user has no serving location yet, or this is their default address
  IF current_serving IS NULL OR NEW.is_default = true THEN
    serving_loc := find_serving_location(NEW.latitude, NEW.longitude);
    
    IF serving_loc IS NOT NULL THEN
      UPDATE public.users
      SET serving_location_id = serving_loc
      WHERE auth_id = NEW.user_auth_id;
      
      RAISE NOTICE 'Updated serving_location_id to % for user %', serving_loc, NEW.user_auth_id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_serving_location_on_address ON public."UserAddresses";
CREATE TRIGGER trg_update_serving_location_on_address
  AFTER INSERT OR UPDATE ON public."UserAddresses"
  FOR EACH ROW
  EXECUTE FUNCTION update_serving_location_on_address();

-- ============================================
-- STEP 11: Create view for admin location management
-- ============================================
CREATE OR REPLACE VIEW admin_location_access AS
SELECT 
  u.auth_id AS admin_id,
  u.name AS admin_name,
  u.email AS admin_email,
  l.id AS location_id,
  l.name AS location_name,
  l.location_type,
  l.is_active,
  l.address,
  l.delivery_radius_km,
  COUNT(DISTINCT CASE WHEN u2.role = 'customer' THEN u2.auth_id END) AS customer_count,
  COUNT(DISTINCT r.id) AS rider_count,
  COUNT(DISTINCT mi.id) AS menu_item_count,
  COUNT(DISTINCT si.id) AS store_item_count
FROM public.users u
CROSS JOIN public.locations l
LEFT JOIN public.users u2 ON u2.serving_location_id = l.id AND u2.role = 'customer'
LEFT JOIN public.riders r ON r.assigned_location_id = l.id
LEFT JOIN public.menu_items mi ON mi.location_id = l.id
LEFT JOIN public."StoreItems" si ON si.location_id = l.id
WHERE u.role = 'admin'
  AND l.id = ANY(u.managed_location_ids)
GROUP BY u.auth_id, u.name, u.email, l.id, l.name, l.location_type, l.is_active, l.address, l.delivery_radius_km;

COMMENT ON VIEW admin_location_access IS 
  'Shows which admins have access to which locations and statistics for each location.';

-- ============================================
-- VERIFICATION & HELPER QUERIES
-- ============================================

-- Query to check if customer address is in any service area
CREATE OR REPLACE FUNCTION check_address_service_availability(
  address_lat NUMERIC,
  address_lon NUMERIC
)
RETURNS TABLE(
  location_id uuid,
  location_name text,
  location_type text,
  distance_km NUMERIC,
  delivery_fee NUMERIC,
  in_range boolean
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    l.id,
    l.name,
    l.location_type,
    ROUND(
      CAST(
        6371 * acos(
          cos(radians(address_lat)) * 
          cos(radians(l.lat)) * 
          cos(radians(l.lon) - radians(address_lon)) + 
          sin(radians(address_lat)) * 
          sin(radians(l.lat))
        ) AS NUMERIC
      ), 
      2
    ) AS distance_km,
    calculate_delivery_fee(l.id, address_lat, address_lon) AS delivery_fee,
    (
      6371 * acos(
        cos(radians(address_lat)) * 
        cos(radians(l.lat)) * 
        cos(radians(l.lon) - radians(address_lon)) + 
        sin(radians(address_lat)) * 
        sin(radians(l.lat))
      )
    ) <= COALESCE(l.delivery_radius_km, 10) AS in_range
  FROM public.locations l
  WHERE l.is_active = true
    AND l.lat IS NOT NULL 
    AND l.lon IS NOT NULL
  ORDER BY distance_km ASC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION check_address_service_availability IS 
  'Check which locations can serve a given address and calculate delivery fees. Used to show "not in service area" or suggest nearest location.';

-- ============================================
-- MIGRATION COMPLETED
-- ============================================
SELECT 'Multi-zone architecture migration completed! 

Next steps:
1. Assign serving_location_id to existing customers based on their addresses
2. Assign managed_location_ids to admin users
3. Assign assigned_location_id to riders
4. Set location_id for all menu_items and StoreItems

Key changes:
- Customers now tied to a serving location
- Admins can manage multiple locations
- Riders assigned to specific locations
- Menu items (restaurant) do NOT use inventory
- Store items DO use ProductInventory per location
- Delivery calculated per location with zone isolation
' AS status;
