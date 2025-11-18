-- ============================================
-- SINGLE LOCATION WITH INVENTORY MANAGEMENT
-- ============================================
-- Simplified for: 1 Restaurant + 1 Store at same location
-- Focus: Inventory tracking for store items only
-- Location: Used only for delivery settings (not item filtering)

-- ============================================
-- STEP 1: Remove location_id requirement from items
-- ============================================
-- Since there's only one location, items don't need location_id

DO $$ 
BEGIN
  -- Make location_id nullable in menu_items (not needed for single location)
  ALTER TABLE public.menu_items 
    ALTER COLUMN location_id DROP NOT NULL;
  
  -- Make location_id nullable in StoreItems (not needed for single location)
  ALTER TABLE public."StoreItems" 
    ALTER COLUMN location_id DROP NOT NULL;
  
  RAISE NOTICE 'Made location_id nullable in menu_items and StoreItems';
END $$;

-- ============================================
-- STEP 2: Add track_inventory flag to StoreItems
-- ============================================
DO $$
BEGIN
  -- Add track_inventory column to control which items use inventory
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'StoreItems' AND column_name = 'track_inventory'
  ) THEN
    ALTER TABLE public."StoreItems" 
      ADD COLUMN track_inventory BOOLEAN NOT NULL DEFAULT true;
    
    RAISE NOTICE 'Added track_inventory column to StoreItems';
  END IF;
END $$;

COMMENT ON COLUMN public."StoreItems".track_inventory IS 
  'If true, this item uses ProductInventory for stock tracking. If false, item is always available (like made-to-order items or services).';

-- ============================================
-- STEP 3: Simplify ProductInventory - Remove location_id
-- ============================================
-- Inventory is global, not per-location

-- First, drop dependent views and policies
DROP VIEW IF EXISTS low_stock_alerts CASCADE;
DROP VIEW IF EXISTS customer_available_store_items CASCADE;

DROP POLICY IF EXISTS "Customers can view available inventory" ON public."ProductInventory";
DROP POLICY IF EXISTS "Admins see their location inventory" ON public."ProductInventory";

DO $$
DECLARE
  has_location_id BOOLEAN;
BEGIN
  -- Check if location_id column exists before trying to query it
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'ProductInventory' AND column_name = 'location_id'
  ) INTO has_location_id;
  
  -- Only check for multi-location data if column exists
  IF has_location_id THEN
    IF EXISTS (
      SELECT 1 FROM public."ProductInventory" 
      WHERE location_id IS NOT NULL
      GROUP BY product_id 
      HAVING COUNT(*) > 1
    ) THEN
      RAISE NOTICE 'WARNING: Found products with inventory at multiple locations. Consolidating...';
      
      -- Consolidate inventory: sum quantities per product
      CREATE TEMP TABLE consolidated_inventory AS
      SELECT 
        product_id,
        SUM(quantity) as total_quantity,
        MIN(minimum_stock_alert) as minimum_stock_alert,
        MAX(last_restock_date) as last_restock_date,
        MIN(created_at) as created_at,
        MAX(updated_at) as updated_at
      FROM public."ProductInventory"
      GROUP BY product_id;
      
      -- Delete old records
      DELETE FROM public."ProductInventory";
      
      -- Insert consolidated records
      INSERT INTO public."ProductInventory" (
        product_id, 
        quantity, 
        minimum_stock_alert, 
        last_restock_date, 
        created_at, 
        updated_at
      )
      SELECT 
        product_id,
        total_quantity,
        minimum_stock_alert,
        last_restock_date,
        created_at,
        updated_at
      FROM consolidated_inventory;
      
      DROP TABLE consolidated_inventory;
      
      RAISE NOTICE 'Consolidated inventory records';
    ELSE
      RAISE NOTICE 'No multi-location inventory found to consolidate';
    END IF;
  ELSE
    RAISE NOTICE 'location_id column does not exist, skipping consolidation check';
  END IF;
  
  -- Remove location_id column if it exists
  IF has_location_id THEN
    -- Drop foreign key first
    ALTER TABLE public."ProductInventory" 
      DROP CONSTRAINT IF EXISTS "ProductInventory_location_id_fkey";
    
    -- Drop the column
    ALTER TABLE public."ProductInventory" 
      DROP COLUMN location_id CASCADE;
    
    RAISE NOTICE 'Removed location_id from ProductInventory';
  ELSE
    RAISE NOTICE 'location_id column already removed from ProductInventory';
  END IF;
  
  -- Ensure product_id is unique (one inventory record per product)
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE indexname = 'idx_productinventory_product_unique'
  ) THEN
    CREATE UNIQUE INDEX idx_productinventory_product_unique 
      ON public."ProductInventory" (product_id);
    
    RAISE NOTICE 'Added unique constraint on product_id';
  END IF;
END $$;

-- Recreate simplified RLS policies without location_id
DROP POLICY IF EXISTS "Customers can view all inventory" ON public."ProductInventory";
CREATE POLICY "Customers can view all inventory"
  ON public."ProductInventory"
  FOR SELECT
  TO authenticated
  USING (quantity > 0);

DROP POLICY IF EXISTS "Admins can manage all inventory" ON public."ProductInventory";
CREATE POLICY "Admins can manage all inventory"
  ON public."ProductInventory"
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE users.auth_id = auth.uid()
        AND users.role = 'admin'
    )
  );

COMMENT ON TABLE public."ProductInventory" IS 
  'Global inventory tracking for store items. One record per product (not location-specific).';

-- ============================================
-- STEP 3: Auto-deduct inventory on order placement
-- ============================================
CREATE OR REPLACE FUNCTION deduct_inventory_on_order()
RETURNS TRIGGER AS $$
DECLARE
  item_record RECORD;
  current_stock INTEGER;
  tracks_inventory BOOLEAN;
BEGIN
  -- Only process if order is newly placed (status = pending)
  IF NEW.status = 'pending' AND (OLD IS NULL OR OLD.status != 'pending') THEN
    
    -- Loop through order items
    FOR item_record IN 
      SELECT 
        oi.product_id,
        oi.quantity,
        oi.item_type
      FROM public.order_items oi
      WHERE oi.order_id = NEW.id
        AND oi.item_type = 'Store Item' -- Only deduct for store items, not restaurant food
    LOOP
      -- Check if this store item tracks inventory
      SELECT track_inventory INTO tracks_inventory
      FROM public."StoreItems"
      WHERE product_id = item_record.product_id;
      
      -- Skip if item doesn't track inventory
      IF tracks_inventory IS NULL OR tracks_inventory = false THEN
        RAISE NOTICE 'Skipping inventory deduction for product % (track_inventory=false)', item_record.product_id;
        CONTINUE;
      END IF;
      
      -- Get current stock for items that track inventory
      SELECT quantity INTO current_stock
      FROM public."ProductInventory"
      WHERE product_id = item_record.product_id;
      
      IF current_stock IS NULL THEN
        RAISE EXCEPTION 'Product % tracks inventory but has no inventory record', item_record.product_id;
      END IF;
      
      IF current_stock < item_record.quantity THEN
        RAISE EXCEPTION 'Insufficient stock for product %. Available: %, Requested: %', 
          item_record.product_id, current_stock, item_record.quantity;
      END IF;
      
      -- Deduct inventory
      UPDATE public."ProductInventory"
      SET 
        quantity = quantity - item_record.quantity,
        updated_at = NOW()
      WHERE product_id = item_record.product_id;
      
      -- Log to stock history
      INSERT INTO public.stock_history (
        inventory_item_id,
        change,
        reason,
        created_at
      )
      SELECT 
        pi.id,
        -item_record.quantity,
        'Order placed: ' || NEW.short_id,
        NOW()
      FROM public."ProductInventory" pi
      WHERE pi.product_id = item_record.product_id;
      
      RAISE NOTICE 'Deducted % units of product % for order %', 
        item_record.quantity, item_record.product_id, NEW.short_id;
    END LOOP;
    
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS trg_deduct_inventory_on_order ON public.orders;
CREATE TRIGGER trg_deduct_inventory_on_order
  AFTER INSERT OR UPDATE OF status ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION deduct_inventory_on_order();

COMMENT ON FUNCTION deduct_inventory_on_order IS 
  'Automatically deducts inventory ONLY for store items with track_inventory=true. Skips items with track_inventory=false and all restaurant items.';

-- ============================================
-- STEP 4: Restore inventory on order cancellation
-- ============================================
CREATE OR REPLACE FUNCTION restore_inventory_on_cancel()
RETURNS TRIGGER AS $$
DECLARE
  item_record RECORD;
  tracks_inventory BOOLEAN;
BEGIN
  -- Only process if order was cancelled (from non-cancelled to cancelled)
  IF NEW.cancelled_at IS NOT NULL AND OLD.cancelled_at IS NULL THEN
    
    -- Loop through order items
    FOR item_record IN 
      SELECT 
        oi.product_id,
        oi.quantity,
        oi.item_type
      FROM public.order_items oi
      WHERE oi.order_id = NEW.id
        AND oi.item_type = 'Store Item' -- Only restore store items
    LOOP
      -- Check if this store item tracks inventory
      SELECT track_inventory INTO tracks_inventory
      FROM public."StoreItems"
      WHERE product_id = item_record.product_id;
      
      -- Skip if item doesn't track inventory
      IF tracks_inventory IS NULL OR tracks_inventory = false THEN
        CONTINUE;
      END IF;
      
      -- Restore inventory
      UPDATE public."ProductInventory"
      SET 
        quantity = quantity + item_record.quantity,
        updated_at = NOW()
      WHERE product_id = item_record.product_id;
      
      -- Log to stock history
      INSERT INTO public.stock_history (
        inventory_item_id,
        change,
        reason,
        created_at
      )
      SELECT 
        pi.id,
        item_record.quantity,
        'Order cancelled: ' || NEW.short_id,
        NOW()
      FROM public."ProductInventory" pi
      WHERE pi.product_id = item_record.product_id;
      
      RAISE NOTICE 'Restored % units of product % from cancelled order %', 
        item_record.quantity, item_record.product_id, NEW.short_id;
    END LOOP;
    
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS trg_restore_inventory_on_cancel ON public.orders;
CREATE TRIGGER trg_restore_inventory_on_cancel
  AFTER UPDATE OF cancelled_at ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION restore_inventory_on_cancel();

COMMENT ON FUNCTION restore_inventory_on_cancel IS 
  'Automatically restores inventory for store items when order is cancelled, but ONLY if StoreItems.track_inventory = true.';

-- ============================================
-- STEP 6: View for store items with current stock (optional inventory)
-- ============================================
CREATE OR REPLACE VIEW store_items_with_stock AS
SELECT 
  si.id,
  si.product_id,
  si.name,
  si.description,
  si.price,
  si.available,
  si.image_url,
  si.category,
  si.unit_of_measure,
  si.unit_description,
  si.track_inventory,
  CASE 
    WHEN si.track_inventory = false THEN NULL -- No stock tracking
    ELSE COALESCE(pi.quantity, 0)
  END as current_stock,
  pi.minimum_stock_alert,
  CASE 
    WHEN si.track_inventory = false THEN false -- Always in stock if not tracking
    WHEN pi.quantity IS NULL THEN false
    ELSE COALESCE(pi.quantity, 0) <= COALESCE(pi.minimum_stock_alert, 10)
  END as is_low_stock,
  CASE 
    WHEN si.track_inventory = false THEN false -- Never out of stock if not tracking
    ELSE COALESCE(pi.quantity, 0) = 0
  END as is_out_of_stock,
  pi.last_restock_date,
  si.created_at,
  si.updated_at
FROM public."StoreItems" si
LEFT JOIN public."ProductInventory" pi ON si.product_id = pi.product_id
WHERE si.available = true
  AND (si.track_inventory = false OR COALESCE(pi.quantity, 0) > 0); -- Show items without tracking OR with stock

COMMENT ON VIEW store_items_with_stock IS 
  'Store items with optional inventory tracking. Items with track_inventory=false are always shown as available. Items with track_inventory=true show only if in stock.';

-- ============================================
-- STEP 7: Function to check if store item can be added to cart
-- ============================================
CREATE OR REPLACE FUNCTION check_store_item_availability(
  product_id_param uuid,
  requested_quantity INTEGER
)
RETURNS jsonb AS $$
DECLARE
  current_stock INTEGER;
  item_name TEXT;
  tracks_inventory BOOLEAN;
  result jsonb;
BEGIN
  -- Get item details
  SELECT 
    si.name,
    si.track_inventory
  INTO 
    item_name,
    tracks_inventory
  FROM public."StoreItems" si
  WHERE si.product_id = product_id_param;
  
  IF item_name IS NULL THEN
    RETURN jsonb_build_object(
      'available', false,
      'reason', 'Product not found'
    );
  END IF;
  
  -- If item doesn't track inventory, always available
  IF tracks_inventory = false THEN
    RETURN jsonb_build_object(
      'available', true,
      'tracks_inventory', false,
      'message', 'Item does not track inventory - always available'
    );
  END IF;
  
  -- Get current stock for items that track inventory
  SELECT pi.quantity
  INTO current_stock
  FROM public."ProductInventory" pi
  WHERE pi.product_id = product_id_param;
  
  IF current_stock IS NULL THEN
    RETURN jsonb_build_object(
      'available', false,
      'reason', 'Product tracks inventory but has no inventory record',
      'tracks_inventory', true,
      'current_stock', 0
    );
  END IF;
  
  IF current_stock = 0 THEN
    RETURN jsonb_build_object(
      'available', false,
      'reason', 'Out of stock',
      'tracks_inventory', true,
      'current_stock', 0
    );
  END IF;
  
  IF current_stock < requested_quantity THEN
    RETURN jsonb_build_object(
      'available', false,
      'reason', 'Insufficient stock',
      'tracks_inventory', true,
      'current_stock', current_stock,
      'requested', requested_quantity,
      'max_available', current_stock
    );
  END IF;
  
  RETURN jsonb_build_object(
    'available', true,
    'tracks_inventory', true,
    'current_stock', current_stock,
    'requested', requested_quantity
  );
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION check_store_item_availability IS 
  'Checks if a store item can be added to cart. Returns available=true if item doesnt track inventory OR has sufficient stock.';

-- ============================================
-- STEP 8: View for low stock alerts (only tracked items)
-- ============================================
CREATE OR REPLACE VIEW low_stock_items AS
SELECT 
  pi.id,
  pi.product_id,
  si.name as product_name,
  si.category,
  si.track_inventory,
  pi.quantity as current_stock,
  pi.minimum_stock_alert,
  pi.minimum_stock_alert - pi.quantity as units_below_minimum,
  pi.last_restock_date,
  pi.updated_at
FROM public."ProductInventory" pi
JOIN public."StoreItems" si ON si.product_id = pi.product_id
WHERE pi.quantity <= pi.minimum_stock_alert
  AND si.track_inventory = true -- Only show items that track inventory
ORDER BY (pi.minimum_stock_alert - pi.quantity) DESC;

COMMENT ON VIEW low_stock_items IS 
  'Items that track inventory and are at or below minimum stock alert level. Items with track_inventory=false are excluded.';

-- ============================================
-- STEP 9: Keep single location for delivery settings
-- ============================================
COMMENT ON TABLE public.locations IS 
  'Single location record for delivery settings. Used to calculate delivery fees and set delivery radius. NOT used for inventory or item filtering.';

COMMENT ON COLUMN public.locations.delivery_radius_km IS 
  'Delivery radius in kilometers. Orders outside this radius will be rejected.';

COMMENT ON COLUMN public.locations.delivery_base_fee IS 
  'Base delivery fee in KSh. Starting price for any delivery.';

COMMENT ON COLUMN public.locations.delivery_rate_per_km IS 
  'Per-kilometer delivery rate in KSh. Added to base fee based on distance.';

COMMENT ON COLUMN public.locations.minimum_order_amount IS 
  'Minimum order amount in KSh required for delivery.';

COMMENT ON COLUMN public.locations.free_delivery_threshold IS 
  'Order amount in KSh above which delivery is free. NULL if no free delivery.';

-- ============================================
-- STEP 10: Function to calculate delivery (single location)
-- ============================================
CREATE OR REPLACE FUNCTION calculate_delivery()
RETURNS TABLE(
  location_id uuid,
  base_fee INTEGER,
  rate_per_km INTEGER,
  radius_km NUMERIC,
  min_order INTEGER,
  free_threshold INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    l.id,
    l.delivery_base_fee,
    l.delivery_rate_per_km,
    l.delivery_radius_km,
    l.minimum_order_amount,
    l.free_delivery_threshold
  FROM public.locations l
  WHERE l.is_active = true
  ORDER BY l.created_at DESC
  LIMIT 1;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION calculate_delivery IS 
  'Returns delivery settings from the active location. Use this to calculate delivery fees in the app.';

-- ============================================
-- STEP 11: Cleanup unused columns
-- ============================================
-- Remove stock_quantity from StoreItems (use ProductInventory instead)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'StoreItems' AND column_name = 'stock_quantity'
  ) THEN
    ALTER TABLE public."StoreItems" DROP COLUMN stock_quantity;
    RAISE NOTICE 'Removed stock_quantity from StoreItems';
  END IF;
  
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'StoreItems' AND column_name = 'low_stock_threshold'
  ) THEN
    ALTER TABLE public."StoreItems" DROP COLUMN low_stock_threshold;
    RAISE NOTICE 'Removed low_stock_threshold from StoreItems';
  END IF;
END $$;

-- ============================================
-- SUCCESS MESSAGE
-- ============================================
SELECT 'Single location inventory management setup complete!

Key Changes:
✅ Removed location_id requirement from items (single location)
✅ ProductInventory is now global (not per-location)
✅ Added track_inventory flag to StoreItems
   - track_inventory = true: Uses ProductInventory (deducts stock)
   - track_inventory = false: Always available (no stock tracking)
✅ Automatic inventory deduction when order placed (only tracked items)
✅ Automatic inventory restoration when order cancelled (only tracked items)
✅ Restaurant items (menu_items): NEVER track inventory
✅ Store items: OPTIONAL inventory tracking per item
✅ Low stock alerts: Only for items with track_inventory = true
✅ Location table used ONLY for delivery settings

Usage:
- Restaurant items (menu_items): Always available (made-to-order)
- Store items WITH tracking: Set track_inventory=true, add to ProductInventory
- Store items WITHOUT tracking: Set track_inventory=false (e.g., services, digital goods, unlimited items)
- Check availability: Call check_store_item_availability(product_id, quantity)
- View with stock: Use store_items_with_stock view
- Low stock alerts: Query low_stock_items view
- Delivery settings: Call calculate_delivery()

Examples:
1. Bottled Water (tracks inventory): track_inventory=true, add to ProductInventory
2. Made-to-order Sandwich (no tracking): track_inventory=false
3. Gift Voucher (no tracking): track_inventory=false
4. Limited Stock Item (tracks inventory): track_inventory=true, set minimum_stock_alert

Inventory flows automatically:
✅ Customer places order → Stock deducted ONLY for items with track_inventory=true
✅ Customer cancels order → Stock restored ONLY for items with track_inventory=true
✅ Items with track_inventory=false → Always available, never deducted
' AS status;
