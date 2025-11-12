-- ============================================================================
-- Migration: Fix Orders and Payment Methods Relationship
-- Created: 2025-11-12
-- Description: Adds proper relationship between orders and payment_methods,
--              and fixes RLS policies to ensure orders load correctly after payment
-- ============================================================================

-- 1. Add payment_method_id column to orders table (optional but recommended for audit trail)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'orders'
      AND column_name = 'payment_method_id'
  ) THEN
    ALTER TABLE public.orders
    ADD COLUMN payment_method_id UUID;
    
    -- Add foreign key constraint
    ALTER TABLE public.orders
    ADD CONSTRAINT fk_orders_payment_method
    FOREIGN KEY (payment_method_id)
    REFERENCES public.payment_methods(id)
    ON DELETE SET NULL;
    
    RAISE NOTICE 'Added payment_method_id column to orders table';
  ELSE
    RAISE NOTICE 'payment_method_id column already exists in orders table';
  END IF;
END $$;

-- 2. Drop existing RLS policies on orders table
DROP POLICY IF EXISTS "Users Insert Own Orders" ON public.orders;
DROP POLICY IF EXISTS "Users Select Own Orders" ON public.orders;
DROP POLICY IF EXISTS "Users Update Own Orders" ON public.orders;
DROP POLICY IF EXISTS "Service role can insert orders" ON public.orders;
DROP POLICY IF EXISTS "Admins can view all orders" ON public.orders;
DROP POLICY IF EXISTS "Riders can view assigned orders" ON public.orders;

-- 3. Enable RLS (if not already enabled)
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

-- 4. Create comprehensive RLS policies

-- Policy 1: Allow service role (backend) to insert orders after payment
CREATE POLICY "Service role can insert orders"
  ON public.orders
  FOR INSERT
  TO service_role
  WITH CHECK (true);

-- Policy 2: Allow authenticated users to insert their own orders (for direct orders)
CREATE POLICY "Users can insert own orders"
  ON public.orders
  FOR INSERT
  TO authenticated
  WITH CHECK (user_auth_id = auth.uid());

-- Policy 3: Allow users to SELECT their own orders
CREATE POLICY "Users can select own orders"
  ON public.orders
  FOR SELECT
  TO authenticated
  USING (user_auth_id = auth.uid());

-- Policy 4: Allow admins to view ALL orders
CREATE POLICY "Admins can view all orders"
  ON public.orders
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE users.auth_id = auth.uid()
      AND users.role = 'admin'
    )
  );

-- Policy 5: Allow riders to view orders assigned to them
CREATE POLICY "Riders can view assigned orders"
  ON public.orders
  FOR SELECT
  TO authenticated
  USING (
    rider_id IN (
      SELECT auth_id FROM public.users
      WHERE auth_id = auth.uid()
      AND role = 'rider'
    )
  );

-- Policy 6: Allow users to update their own orders (for cancellations)
CREATE POLICY "Users can update own orders"
  ON public.orders
  FOR UPDATE
  TO authenticated
  USING (user_auth_id = auth.uid())
  WITH CHECK (user_auth_id = auth.uid());

-- Policy 7: Allow admins to update any order
CREATE POLICY "Admins can update all orders"
  ON public.orders
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE users.auth_id = auth.uid()
      AND users.role = 'admin'
    )
  );

-- Policy 8: Allow riders to update orders assigned to them
CREATE POLICY "Riders can update assigned orders"
  ON public.orders
  FOR UPDATE
  TO authenticated
  USING (
    rider_id IN (
      SELECT auth_id FROM public.users
      WHERE auth_id = auth.uid()
      AND role = 'rider'
    )
  );

-- 5. Ensure order_items table has proper RLS policies
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own order items" ON public.order_items;
DROP POLICY IF EXISTS "Service role can insert order items" ON public.order_items;
DROP POLICY IF EXISTS "Admins can view all order items" ON public.order_items;

-- Allow service role to insert order items
CREATE POLICY "Service role can insert order items"
  ON public.order_items
  FOR INSERT
  TO service_role
  WITH CHECK (true);

-- Allow users to view order items for their orders
CREATE POLICY "Users can view own order items"
  ON public.order_items
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.orders
      WHERE orders.id = order_items.order_id
      AND orders.user_auth_id = auth.uid()
    )
  );

-- Allow admins to view all order items
CREATE POLICY "Admins can view all order items"
  ON public.order_items
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE users.auth_id = auth.uid()
      AND users.role = 'admin'
    )
  );

-- 6. Create index for payment_method_id
CREATE INDEX IF NOT EXISTS idx_orders_payment_method_id 
ON public.orders(payment_method_id);

-- 7. Add helpful comments
COMMENT ON COLUMN public.orders.payment_method_id IS 'Links order to the payment method used (optional for audit trail)';
COMMENT ON COLUMN public.payment_methods.metadata IS 'Stores order details during payment processing (before order creation)';

-- 8. Verify the changes
DO $$
DECLARE
  policy_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO policy_count
  FROM pg_policies
  WHERE schemaname = 'public' AND tablename = 'orders';
  
  RAISE NOTICE 'Total RLS policies on orders table: %', policy_count;
END $$;

-- 9. Show all columns in orders table
SELECT 
  column_name, 
  data_type, 
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'orders'
ORDER BY ordinal_position;

-- 10. Reload schema cache
NOTIFY pgrst, 'reload schema';

-- 11. Final success message
DO $$
BEGIN
  RAISE NOTICE '✅ Migration completed successfully!';
END $$;
