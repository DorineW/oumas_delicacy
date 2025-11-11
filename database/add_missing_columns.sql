-- Quick fix: Add missing columns to orders table
-- Copy and paste this into Supabase SQL Editor

-- Add delivery_phone column
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_phone text;

-- Add rider_id column with foreign key
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS rider_id uuid;
ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_rider_id_fkey;
ALTER TABLE public.orders ADD CONSTRAINT orders_rider_id_fkey 
    FOREIGN KEY (rider_id) REFERENCES public.users(auth_id);

-- Add rider_name column
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS rider_name text;

-- Add cancellation_reason column
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS cancellation_reason text;

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_orders_rider_id ON public.orders(rider_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON public.orders(status);

-- Verify columns were added
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'orders'
ORDER BY ordinal_position;
