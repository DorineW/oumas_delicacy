-- ============================================
-- FIX ADDRESS, ORDER, AND DELIVERY FLOW
-- ============================================
-- This migration ensures proper relationships between:
-- 1. UserAddresses (customer saved addresses)
-- 2. orders (order records with delivery information)
-- 3. Deliveries (delivery tracking and rider assignment)
-- 4. riders (delivery personnel)

-- ============================================
-- STEP 1: Verify orders table has all required columns
-- ============================================
DO $$ 
BEGIN
  -- Ensure delivery_address_id exists and is properly indexed
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'orders' AND column_name = 'delivery_address_id'
  ) THEN
    ALTER TABLE public.orders 
      ADD COLUMN delivery_address_id uuid NULL;
    
    RAISE NOTICE 'Added delivery_address_id column to orders';
  END IF;

  -- Add foreign key constraint if not exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'orders_delivery_address_id_fkey'
  ) THEN
    ALTER TABLE public.orders
      ADD CONSTRAINT orders_delivery_address_id_fkey 
      FOREIGN KEY (delivery_address_id) 
      REFERENCES public."UserAddresses" (id) 
      ON DELETE SET NULL;
    
    RAISE NOTICE 'Added FK constraint orders_delivery_address_id_fkey';
  END IF;

  -- Add index for performance
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE indexname = 'idx_orders_delivery_address_id'
  ) THEN
    CREATE INDEX idx_orders_delivery_address_id 
      ON public.orders USING btree (delivery_address_id);
    
    RAISE NOTICE 'Created index idx_orders_delivery_address_id';
  END IF;

  -- Ensure delivery_lat and delivery_lon exist (for rider navigation)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'orders' AND column_name = 'delivery_lat'
  ) THEN
    ALTER TABLE public.orders 
      ADD COLUMN delivery_lat NUMERIC(10, 7) NULL;
    
    RAISE NOTICE 'Added delivery_lat column';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'orders' AND column_name = 'delivery_lon'
  ) THEN
    ALTER TABLE public.orders 
      ADD COLUMN delivery_lon NUMERIC(10, 7) NULL;
    
    RAISE NOTICE 'Added delivery_lon column';
  END IF;

  -- Add index for geospatial queries (nearest orders to rider)
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE indexname = 'idx_orders_delivery_coordinates'
  ) THEN
    CREATE INDEX idx_orders_delivery_coordinates 
      ON public.orders USING btree (delivery_lat, delivery_lon)
      WHERE delivery_lat IS NOT NULL AND delivery_lon IS NOT NULL;
    
    RAISE NOTICE 'Created index idx_orders_delivery_coordinates';
  END IF;

END $$;

-- ============================================
-- STEP 2: Add helpful comments to document the flow
-- ============================================
COMMENT ON COLUMN public.orders.delivery_address_id IS 
  'FK to UserAddresses.id. When customer selects saved address at checkout, this links the order to that address record for full address details.';

COMMENT ON COLUMN public.orders.delivery_address IS 
  'JSONB field containing address snapshot at order time. Includes: address text, lat, lon. Preserves address even if UserAddress is deleted later.';

COMMENT ON COLUMN public.orders.delivery_lat IS 
  'Latitude of delivery destination. Used by riders for navigation. Populated from UserAddresses.latitude or manual selection.';

COMMENT ON COLUMN public.orders.delivery_lon IS 
  'Longitude of delivery destination. Used by riders for navigation. Populated from UserAddresses.longitude or manual selection.';

COMMENT ON COLUMN public.orders.delivery_phone IS 
  'Customer contact phone for delivery. May differ from user account phone. Used by riders to contact customer.';

-- ============================================
-- STEP 3: Create helper function to sync address data to orders
-- ============================================
CREATE OR REPLACE FUNCTION sync_address_to_order()
RETURNS TRIGGER AS $$
BEGIN
  -- When delivery_address_id is set, automatically populate delivery_lat/lon and delivery_address jsonb
  IF NEW.delivery_address_id IS NOT NULL AND (
    OLD.delivery_address_id IS NULL OR 
    OLD.delivery_address_id != NEW.delivery_address_id OR
    NEW.delivery_lat IS NULL OR
    NEW.delivery_lon IS NULL
  ) THEN
    -- Fetch address details from UserAddresses
    SELECT 
      latitude,
      longitude,
      jsonb_build_object(
        'address_id', ua.id,
        'label', ua.label,
        'latitude', ua.latitude,
        'longitude', ua.longitude,
        'descriptive_directions', ua.descriptive_directions,
        'street_address', ua.street_address,
        'address_text', COALESCE(ua.street_address || ', ', '') || ua.descriptive_directions
      )
    INTO 
      NEW.delivery_lat,
      NEW.delivery_lon,
      NEW.delivery_address
    FROM public."UserAddresses" ua
    WHERE ua.id = NEW.delivery_address_id;

    RAISE NOTICE 'Synced address data from UserAddresses % to order %', NEW.delivery_address_id, NEW.id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop and recreate trigger to ensure it's up to date
DROP TRIGGER IF EXISTS trg_sync_address_to_order ON public.orders;
CREATE TRIGGER trg_sync_address_to_order
  BEFORE INSERT OR UPDATE OF delivery_address_id ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION sync_address_to_order();

COMMENT ON FUNCTION sync_address_to_order() IS 
  'Automatically populates delivery_lat, delivery_lon, and delivery_address jsonb when delivery_address_id is set. Ensures order has complete address snapshot even if UserAddress is later modified or deleted.';

-- ============================================
-- STEP 4: Ensure Deliveries table relationships are correct
-- ============================================
DO $$
BEGIN
  -- Verify Deliveries.order_id FK exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'Deliveries_order_id_fkey'
  ) THEN
    ALTER TABLE public."Deliveries"
      ADD CONSTRAINT "Deliveries_order_id_fkey" 
      FOREIGN KEY (order_id) 
      REFERENCES public.orders (id) 
      ON DELETE CASCADE;
    
    RAISE NOTICE 'Added FK Deliveries_order_id_fkey';
  END IF;

  -- Verify Deliveries.assigned_rider_id FK exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'Deliveries_assigned_rider_id_fkey'
  ) THEN
    ALTER TABLE public."Deliveries"
      ADD CONSTRAINT "Deliveries_assigned_rider_id_fkey" 
      FOREIGN KEY (assigned_rider_id) 
      REFERENCES public.riders (id) 
      ON DELETE SET NULL;
    
    RAISE NOTICE 'Added FK Deliveries_assigned_rider_id_fkey';
  END IF;

  -- Verify Deliveries.warehouse_location_id FK exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'Deliveries_warehouse_location_id_fkey'
  ) THEN
    ALTER TABLE public."Deliveries"
      ADD CONSTRAINT "Deliveries_warehouse_location_id_fkey" 
      FOREIGN KEY (warehouse_location_id) 
      REFERENCES public.locations (id) 
      ON DELETE SET NULL;
    
    RAISE NOTICE 'Added FK Deliveries_warehouse_location_id_fkey';
  END IF;
END $$;

-- ============================================
-- STEP 5: Create view for complete order/delivery info (for admin & rider)
-- ============================================
CREATE OR REPLACE VIEW order_delivery_details AS
SELECT 
  o.id AS order_id,
  o.short_id AS order_number,
  o.user_auth_id AS customer_id,
  u.name AS customer_name,
  u.phone AS customer_phone,
  o.delivery_phone,
  o.status AS order_status,
  o.total,
  o.subtotal,
  o.delivery_fee,
  o.tax,
  o.placed_at,
  o.delivered_at,
  o.cancelled_at,
  
  -- Delivery address details
  o.delivery_address_id,
  o.delivery_lat,
  o.delivery_lon,
  o.delivery_address AS delivery_address_jsonb,
  COALESCE(
    o.delivery_address->>'address_text',
    ua.descriptive_directions
  ) AS delivery_address_text,
  
  -- UserAddress details (if linked)
  ua.label AS address_label,
  ua.street_address,
  ua.descriptive_directions,
  
  -- Delivery tracking
  d.id AS delivery_id,
  d.fulfillment_step,
  d.status AS delivery_status,
  d.estimated_completion_time,
  
  -- Rider details
  d.assigned_rider_id,
  r.name AS rider_name,
  r.phone AS rider_phone,
  r.vehicle AS rider_vehicle,
  r.location_lat AS rider_lat,
  r.location_lon AS rider_lon,
  r.is_available AS rider_available,
  
  -- Warehouse/location details
  d.warehouse_location_id,
  l.name AS warehouse_name,
  l.lat AS warehouse_lat,
  l.lon AS warehouse_lon,
  l.address AS warehouse_address,
  
  -- Calculate distance from warehouse to delivery (in km)
  CASE 
    WHEN o.delivery_lat IS NOT NULL AND o.delivery_lon IS NOT NULL 
         AND l.lat IS NOT NULL AND l.lon IS NOT NULL
    THEN
      ROUND(
        CAST(
          6371 * acos(
            cos(radians(l.lat)) * 
            cos(radians(o.delivery_lat)) * 
            cos(radians(o.delivery_lon) - radians(l.lon)) + 
            sin(radians(l.lat)) * 
            sin(radians(o.delivery_lat))
          ) AS NUMERIC
        ), 
        2
      )
    ELSE NULL
  END AS distance_km

FROM public.orders o
LEFT JOIN public.users u ON o.user_auth_id = u.auth_id
LEFT JOIN public."UserAddresses" ua ON o.delivery_address_id = ua.id
LEFT JOIN public."Deliveries" d ON o.id = d.order_id
LEFT JOIN public.riders r ON d.assigned_rider_id = r.id
LEFT JOIN public.locations l ON d.warehouse_location_id = l.id;

COMMENT ON VIEW order_delivery_details IS 
  'Complete order and delivery information for admin dashboard and rider app. Includes customer address, delivery status, rider details, and distance calculations.';

-- Grant access to authenticated users (adjust as needed)
GRANT SELECT ON order_delivery_details TO authenticated;

-- ============================================
-- STEP 6: Add RLS policies for riders to access order addresses
-- ============================================
-- Riders need to see delivery addresses for orders assigned to them

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Riders can view assigned order addresses" ON public.orders;

CREATE POLICY "Riders can view assigned order addresses" 
  ON public.orders
  FOR SELECT
  USING (
    -- Check if current user is a rider assigned to a delivery for this order
    EXISTS (
      SELECT 1 
      FROM public.riders r
      JOIN public."Deliveries" d ON d.assigned_rider_id = r.id
      WHERE r.auth_id = auth.uid()
        AND d.order_id = orders.id
    )
  );

-- ============================================
-- STEP 7: Create indexes for common queries
-- ============================================
-- Index for finding orders by rider
CREATE INDEX IF NOT EXISTS idx_deliveries_order_rider 
  ON public."Deliveries" USING btree (order_id, assigned_rider_id);

-- Index for finding active deliveries by status
CREATE INDEX IF NOT EXISTS idx_deliveries_status 
  ON public."Deliveries" USING btree (status) 
  WHERE status IN ('Pending', 'Picking', 'In Transit');

-- Index for finding nearby riders (for auto-assignment)
CREATE INDEX IF NOT EXISTS idx_riders_location_available 
  ON public.riders USING btree (is_available, location_lat, location_lon)
  WHERE is_available = true;

-- ============================================
-- STEP 8: Backfill existing orders (if any don't have lat/lon)
-- ============================================
-- Update existing orders that have delivery_address_id but no coordinates
UPDATE public.orders o
SET 
  delivery_lat = ua.latitude,
  delivery_lon = ua.longitude,
  delivery_address = jsonb_build_object(
    'address_id', ua.id,
    'label', ua.label,
    'latitude', ua.latitude,
    'longitude', ua.longitude,
    'descriptive_directions', ua.descriptive_directions,
    'street_address', ua.street_address,
    'address_text', COALESCE(ua.street_address || ', ', '') || ua.descriptive_directions
  )
FROM public."UserAddresses" ua
WHERE o.delivery_address_id = ua.id
  AND (o.delivery_lat IS NULL OR o.delivery_lon IS NULL);

-- ============================================
-- VERIFICATION QUERIES
-- ============================================
-- Run these to verify the setup:

-- 1. Check all order columns
-- SELECT column_name, data_type, is_nullable 
-- FROM information_schema.columns 
-- WHERE table_name = 'orders' 
-- ORDER BY ordinal_position;

-- 2. Test the view
-- SELECT * FROM order_delivery_details LIMIT 5;

-- 3. Check for orders missing coordinates
-- SELECT id, short_id, delivery_address_id, delivery_lat, delivery_lon 
-- FROM orders 
-- WHERE delivery_address_id IS NOT NULL AND (delivery_lat IS NULL OR delivery_lon IS NULL);

-- 4. Verify address sync trigger works
-- INSERT INTO "UserAddresses" (user_auth_id, label, latitude, longitude, descriptive_directions, is_default)
-- VALUES (auth.uid(), 'Test', -1.2921, 36.8219, 'Test address', false)
-- RETURNING id;
-- -- Then create test order with that address_id and verify lat/lon auto-populate

SELECT 'Migration completed successfully! Address, Order, and Delivery flow is now properly connected.' AS status;
