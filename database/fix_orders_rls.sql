-- Allow authenticated users to insert their own orders
DROP POLICY IF EXISTS "Users Insert Own Orders" ON public.orders;
CREATE POLICY "Users Insert Own Orders"
  ON public.orders
  FOR INSERT
  TO authenticated
  WITH CHECK (user_auth_id = auth.uid());

-- Allow users to select their own orders
DROP POLICY IF EXISTS "Users Select Own Orders" ON public.orders;
CREATE POLICY "Users Select Own Orders"
  ON public.orders
  FOR SELECT
  TO authenticated
  USING (user_auth_id = auth.uid());

-- Verify RLS is enabled
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
