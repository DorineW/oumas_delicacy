-- Phase 3: Inventory Management System
-- This creates ProductInventory table and related triggers/policies

-- 1. Create ProductInventory table
CREATE TABLE IF NOT EXISTS public."ProductInventory" (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL,
  location_id uuid NOT NULL,
  quantity integer NOT NULL DEFAULT 0,
  minimum_stock_alert integer NOT NULL DEFAULT 10,
  last_restock_date timestamp with time zone NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT ProductInventory_pkey PRIMARY KEY (id),
  CONSTRAINT ProductInventory_product_id_location_id_key UNIQUE (product_id, location_id),
  CONSTRAINT ProductInventory_location_id_fkey FOREIGN KEY (location_id) REFERENCES locations (id) ON DELETE CASCADE,
  CONSTRAINT ProductInventory_product_id_fkey FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE,
  CONSTRAINT ProductInventory_minimum_stock_alert_check CHECK (minimum_stock_alert >= 0),
  CONSTRAINT ProductInventory_quantity_check CHECK (quantity >= 0)
) TABLESPACE pg_default;

-- 2. Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_product_inventory_product_id ON public."ProductInventory"(product_id);
CREATE INDEX IF NOT EXISTS idx_product_inventory_location_id ON public."ProductInventory"(location_id);
CREATE INDEX IF NOT EXISTS idx_product_inventory_low_stock ON public."ProductInventory"(location_id) 
  WHERE quantity <= minimum_stock_alert;

-- 3. Create updated_at trigger
CREATE OR REPLACE FUNCTION update_product_inventory_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_product_inventory_updated_at_trigger
  BEFORE UPDATE ON public."ProductInventory"
  FOR EACH ROW
  EXECUTE FUNCTION update_product_inventory_updated_at();

-- 4. Add location_id to menu_items (if not exists)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'menu_items' 
    AND column_name = 'location_id'
  ) THEN
    ALTER TABLE public.menu_items 
    ADD COLUMN location_id uuid NULL,
    ADD CONSTRAINT menu_items_location_id_fkey 
      FOREIGN KEY (location_id) REFERENCES locations (id) ON DELETE SET NULL;
    
    CREATE INDEX idx_menu_items_location_id ON public.menu_items(location_id);
  END IF;
END $$;

-- 5. Add location_id to StoreItems (if not exists)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'StoreItems' 
    AND column_name = 'location_id'
  ) THEN
    ALTER TABLE public."StoreItems" 
    ADD COLUMN location_id uuid NULL,
    ADD CONSTRAINT StoreItems_location_id_fkey 
      FOREIGN KEY (location_id) REFERENCES locations (id) ON DELETE SET NULL;
    
    CREATE INDEX idx_store_items_location_id ON public."StoreItems"(location_id);
  END IF;
END $$;

-- 6. Row Level Security Policies for ProductInventory

-- Enable RLS
ALTER TABLE public."ProductInventory" ENABLE ROW LEVEL SECURITY;

-- Admin can do everything
CREATE POLICY "Admins can manage inventory"
  ON public."ProductInventory"
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE users.auth_id = auth.uid()
      AND users.role = 'admin'
    )
  );

-- Riders can view inventory for their assigned orders
CREATE POLICY "Riders can view inventory"
  ON public."ProductInventory"
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE users.auth_id = auth.uid()
      AND users.role = 'rider'
    )
  );

-- Customers can view available inventory (quantity > 0)
CREATE POLICY "Customers can view available inventory"
  ON public."ProductInventory"
  FOR SELECT
  USING (
    quantity > 0
    AND EXISTS (
      SELECT 1 FROM public.locations
      WHERE locations.id = "ProductInventory".location_id
      AND locations.is_active = true
    )
  );

-- 7. Create view for low stock alerts
CREATE OR REPLACE VIEW low_stock_alerts AS
SELECT 
  pi.id,
  pi.product_id,
  p.name as product_name,
  pi.location_id,
  l.name as location_name,
  pi.quantity,
  pi.minimum_stock_alert,
  (pi.minimum_stock_alert - pi.quantity) as units_below_minimum,
  pi.last_restock_date,
  pi.updated_at
FROM public."ProductInventory" pi
JOIN public.products p ON p.id = pi.product_id
JOIN public.locations l ON l.id = pi.location_id
WHERE pi.quantity <= pi.minimum_stock_alert
ORDER BY (pi.minimum_stock_alert - pi.quantity) DESC, l.name, p.name;

-- Grant access to view
GRANT SELECT ON low_stock_alerts TO authenticated;

-- 8. Create function to get available products at location
CREATE OR REPLACE FUNCTION get_available_products_at_location(
  p_location_id uuid,
  p_category_filter text DEFAULT NULL
)
RETURNS TABLE (
  product_id uuid,
  product_name text,
  category text,
  price numeric,
  quantity integer,
  in_stock boolean
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id as product_id,
    p.name as product_name,
    p.category,
    p.price,
    COALESCE(pi.quantity, 0) as quantity,
    COALESCE(pi.quantity, 0) > 0 as in_stock
  FROM public.products p
  LEFT JOIN public."ProductInventory" pi 
    ON pi.product_id = p.id 
    AND pi.location_id = p_location_id
  WHERE 
    (p_category_filter IS NULL OR p.category = p_category_filter)
    AND p.is_available = true
  ORDER BY p.category, p.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 9. Create function to update stock after order
CREATE OR REPLACE FUNCTION update_inventory_on_order(
  p_order_id uuid
)
RETURNS void AS $$
DECLARE
  v_location_id uuid;
  v_item record;
BEGIN
  -- Get order location
  SELECT location_id INTO v_location_id
  FROM public.orders
  WHERE id = p_order_id;

  IF v_location_id IS NULL THEN
    RAISE EXCEPTION 'Order location not found';
  END IF;

  -- Update inventory for each order item
  FOR v_item IN 
    SELECT oi.product_id, oi.quantity
    FROM public.order_items oi
    WHERE oi.order_id = p_order_id
  LOOP
    UPDATE public."ProductInventory"
    SET quantity = quantity - v_item.quantity
    WHERE product_id = v_item.product_id
      AND location_id = v_location_id
      AND quantity >= v_item.quantity;

    -- Check if update was successful
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Insufficient stock for product % at location %', 
        v_item.product_id, v_location_id;
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 10. Create function to restock inventory
CREATE OR REPLACE FUNCTION restock_inventory(
  p_product_id uuid,
  p_location_id uuid,
  p_quantity integer
)
RETURNS void AS $$
BEGIN
  -- Upsert inventory record
  INSERT INTO public."ProductInventory" (
    product_id,
    location_id,
    quantity,
    last_restock_date
  )
  VALUES (
    p_product_id,
    p_location_id,
    p_quantity,
    now()
  )
  ON CONFLICT (product_id, location_id)
  DO UPDATE SET
    quantity = "ProductInventory".quantity + p_quantity,
    last_restock_date = now();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 11. Add location_id to orders table (for tracking which location fulfills order)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'orders' 
    AND column_name = 'fulfillment_location_id'
  ) THEN
    ALTER TABLE public.orders 
    ADD COLUMN fulfillment_location_id uuid NULL,
    ADD CONSTRAINT orders_fulfillment_location_id_fkey 
      FOREIGN KEY (fulfillment_location_id) REFERENCES locations (id) ON DELETE SET NULL;
    
    CREATE INDEX idx_orders_fulfillment_location_id ON public.orders(fulfillment_location_id);
    
    COMMENT ON COLUMN public.orders.fulfillment_location_id IS 'Which location is fulfilling this order';
  END IF;
END $$;

-- 12. Sample data: Initialize inventory for existing products
-- This will create inventory records at the first active location for all products
-- Run this AFTER you have locations in your database
/*
DO $$ 
DECLARE
  v_first_location_id uuid;
BEGIN
  -- Get first active location
  SELECT id INTO v_first_location_id
  FROM public.locations
  WHERE is_active = true
  ORDER BY created_at
  LIMIT 1;

  IF v_first_location_id IS NOT NULL THEN
    -- Create inventory records for all products
    INSERT INTO public."ProductInventory" (product_id, location_id, quantity, minimum_stock_alert)
    SELECT 
      p.id,
      v_first_location_id,
      50, -- Default quantity
      10  -- Default minimum alert
    FROM public.products p
    WHERE NOT EXISTS (
      SELECT 1 FROM public."ProductInventory" pi
      WHERE pi.product_id = p.id AND pi.location_id = v_first_location_id
    );
    
    RAISE NOTICE 'Initialized inventory for % products at location %', 
      (SELECT COUNT(*) FROM public.products), v_first_location_id;
  END IF;
END $$;
*/

-- 13. Verification queries
-- Uncomment to check the setup

-- Check ProductInventory table structure
-- SELECT column_name, data_type, is_nullable, column_default
-- FROM information_schema.columns
-- WHERE table_schema = 'public' AND table_name = 'ProductInventory'
-- ORDER BY ordinal_position;

-- Check low stock alerts
-- SELECT * FROM low_stock_alerts;

-- Check inventory by location
-- SELECT 
--   l.name as location,
--   COUNT(pi.id) as products_stocked,
--   SUM(CASE WHEN pi.quantity <= pi.minimum_stock_alert THEN 1 ELSE 0 END) as low_stock_items
-- FROM public.locations l
-- LEFT JOIN public."ProductInventory" pi ON pi.location_id = l.id
-- GROUP BY l.name;
