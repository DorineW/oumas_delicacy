-- ================================================================
-- Migration: Create UserAddresses Table
-- Date: 2025-11-15
-- Purpose: Centralize all user delivery addresses in database
--          Replaces SharedPreferences storage for addresses
--          Links to orders table for delivery tracking
-- ================================================================

BEGIN;

-- Step 1: Create UserAddresses table
CREATE TABLE IF NOT EXISTS public."UserAddresses" (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_auth_id uuid NOT NULL,
  label text NOT NULL,
  latitude numeric NOT NULL,
  longitude numeric NOT NULL,
  descriptive_directions text NOT NULL,
  street_address text NULL,
  is_default boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT UserAddresses_pkey PRIMARY KEY (id),
  CONSTRAINT UserAddresses_user_auth_id_fkey FOREIGN KEY (user_auth_id) 
    REFERENCES users (auth_id) ON DELETE CASCADE
) TABLESPACE pg_default;

-- Step 2: Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_useraddresses_user_auth_id 
  ON public."UserAddresses" USING btree (user_auth_id);

CREATE INDEX IF NOT EXISTS idx_useraddresses_is_default 
  ON public."UserAddresses" USING btree (user_auth_id, is_default) 
  WHERE is_default = true;

-- Step 3: Add trigger for updated_at timestamp
CREATE TRIGGER trg_useraddresses_updated_at 
  BEFORE UPDATE ON public."UserAddresses"
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

-- Step 4: Add constraint to ensure only one default address per user
CREATE UNIQUE INDEX IF NOT EXISTS idx_useraddresses_one_default_per_user
  ON public."UserAddresses" (user_auth_id)
  WHERE is_default = true;

-- Step 5: Update orders table to reference UserAddresses (if not already done)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'orders' AND column_name = 'delivery_address_id'
  ) THEN
    ALTER TABLE public.orders 
      ADD COLUMN delivery_address_id uuid NULL;
    
    ALTER TABLE public.orders
      ADD CONSTRAINT orders_delivery_address_id_fkey 
      FOREIGN KEY (delivery_address_id) 
      REFERENCES public."UserAddresses" (id) 
      ON DELETE SET NULL;
    
    CREATE INDEX IF NOT EXISTS idx_orders_delivery_address_id 
      ON public.orders USING btree (delivery_address_id);
  END IF;
END $$;

-- Step 6: Add helpful comments
COMMENT ON TABLE public."UserAddresses" IS 
  'Stores all user delivery addresses. Replaces SharedPreferences storage. Links to orders for delivery tracking.';

COMMENT ON COLUMN public."UserAddresses".label IS 
  'User-friendly name for the address (e.g., "Home", "Work", "Mom''s Place")';

COMMENT ON COLUMN public."UserAddresses".descriptive_directions IS 
  'Human-readable directions or landmark-based description';

COMMENT ON COLUMN public."UserAddresses".street_address IS 
  'Optional formal street address from geocoding service';

COMMENT ON COLUMN public."UserAddresses".is_default IS 
  'Whether this is the user''s default delivery address. Only one per user can be true.';

-- Step 7: Enable RLS (Row Level Security)
ALTER TABLE public."UserAddresses" ENABLE ROW LEVEL SECURITY;

-- Step 8: Create RLS policies

-- Policy: Users can view their own addresses
DROP POLICY IF EXISTS "Users can view own addresses" ON public."UserAddresses";
CREATE POLICY "Users can view own addresses" 
  ON public."UserAddresses"
  FOR SELECT
  USING (auth.uid() = user_auth_id);

-- Policy: Users can insert their own addresses
DROP POLICY IF EXISTS "Users can insert own addresses" ON public."UserAddresses";
CREATE POLICY "Users can insert own addresses" 
  ON public."UserAddresses"
  FOR INSERT
  WITH CHECK (auth.uid() = user_auth_id);

-- Policy: Users can update their own addresses
DROP POLICY IF EXISTS "Users can update own addresses" ON public."UserAddresses";
CREATE POLICY "Users can update own addresses" 
  ON public."UserAddresses"
  FOR UPDATE
  USING (auth.uid() = user_auth_id)
  WITH CHECK (auth.uid() = user_auth_id);

-- Policy: Users can delete their own addresses
DROP POLICY IF EXISTS "Users can delete own addresses" ON public."UserAddresses";
CREATE POLICY "Users can delete own addresses" 
  ON public."UserAddresses"
  FOR DELETE
  USING (auth.uid() = user_auth_id);

-- Policy: Admins can view all addresses
DROP POLICY IF EXISTS "Admins can view all addresses" ON public."UserAddresses";
CREATE POLICY "Admins can view all addresses" 
  ON public."UserAddresses"
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE auth_id = auth.uid() 
      AND role = 'admin'
    )
  );

-- Policy: Riders can view addresses for their assigned orders
DROP POLICY IF EXISTS "Riders can view order addresses" ON public."UserAddresses";
CREATE POLICY "Riders can view order addresses" 
  ON public."UserAddresses"
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE auth_id = auth.uid() 
      AND role = 'rider'
    )
    AND EXISTS (
      SELECT 1 FROM orders 
      WHERE orders.delivery_address_id = "UserAddresses".id
      AND orders.rider_id = auth.uid()
    )
  );

COMMIT;

-- ================================================================
-- Verification Queries
-- ================================================================

-- Check table structure
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'UserAddresses'
ORDER BY ordinal_position;

-- Check indexes
SELECT 
  indexname,
  indexdef
FROM pg_indexes
WHERE tablename = 'UserAddresses';

-- Check constraints
SELECT
  con.conname AS constraint_name,
  con.contype AS constraint_type,
  pg_get_constraintdef(con.oid) AS constraint_definition
FROM pg_constraint con
JOIN pg_class rel ON rel.oid = con.conrelid
WHERE rel.relname = 'UserAddresses';

-- Check RLS policies
SELECT 
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'UserAddresses';

-- ================================================================
-- Example Usage
-- ================================================================

-- Add a sample address (replace UUID with actual user auth_id)
/*
INSERT INTO public."UserAddresses" (
  user_auth_id,
  label,
  latitude,
  longitude,
  descriptive_directions,
  street_address,
  is_default
) VALUES (
  '00000000-0000-0000-0000-000000000000', -- Replace with real user auth_id
  'Home',
  -1.286389,
  36.817223,
  'Near Westlands Roundabout, blue gate',
  'Waiyaki Way, Nairobi',
  true
);
*/

-- Query user addresses
/*
SELECT 
  id,
  label,
  descriptive_directions,
  is_default,
  created_at
FROM public."UserAddresses"
WHERE user_auth_id = '00000000-0000-0000-0000-000000000000'
ORDER BY is_default DESC, created_at DESC;
*/

-- Get order with address details
/*
SELECT 
  o.id AS order_id,
  o.short_id,
  o.status,
  o.total,
  ua.label AS address_label,
  ua.descriptive_directions,
  ua.latitude,
  ua.longitude
FROM orders o
LEFT JOIN "UserAddresses" ua ON o.delivery_address_id = ua.id
WHERE o.user_auth_id = '00000000-0000-0000-0000-000000000000'
ORDER BY o.placed_at DESC;
*/
