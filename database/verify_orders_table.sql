-- Verify and fix orders table structure for M-Pesa backend

-- 1. Check current orders table structure
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'orders'
ORDER BY ordinal_position;

-- 2. Add missing columns if they don't exist
DO $$
BEGIN
    -- Add customer_name if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'customer_name'
    ) THEN
        ALTER TABLE public.orders ADD COLUMN customer_name TEXT;
        RAISE NOTICE 'Added customer_name column';
    END IF;

    -- Add delivery_phone if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'delivery_phone'
    ) THEN
        ALTER TABLE public.orders ADD COLUMN delivery_phone TEXT;
        RAISE NOTICE 'Added delivery_phone column';
    END IF;

    -- Add subtotal if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'subtotal'
    ) THEN
        ALTER TABLE public.orders ADD COLUMN subtotal INTEGER DEFAULT 0;
        RAISE NOTICE 'Added subtotal column';
    END IF;

    -- Add delivery_fee if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'delivery_fee'
    ) THEN
        ALTER TABLE public.orders ADD COLUMN delivery_fee INTEGER DEFAULT 0;
        RAISE NOTICE 'Added delivery_fee column';
    END IF;

    -- Add tax if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'tax'
    ) THEN
        ALTER TABLE public.orders ADD COLUMN tax INTEGER DEFAULT 0;
        RAISE NOTICE 'Added tax column';
    END IF;

    -- Add delivery_type if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'delivery_type'
    ) THEN
        ALTER TABLE public.orders ADD COLUMN delivery_type TEXT DEFAULT 'delivery';
        RAISE NOTICE 'Added delivery_type column';
    END IF;

    -- Add delivery_address if missing (JSONB for flexibility)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'delivery_address'
    ) THEN
        ALTER TABLE public.orders ADD COLUMN delivery_address JSONB;
        RAISE NOTICE 'Added delivery_address column';
    END IF;

    -- Add placed_at if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'placed_at'
    ) THEN
        ALTER TABLE public.orders ADD COLUMN placed_at TIMESTAMPTZ DEFAULT NOW();
        RAISE NOTICE 'Added placed_at column';
    END IF;

    -- Add cancelled_at if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'cancelled_at'
    ) THEN
        ALTER TABLE public.orders ADD COLUMN cancelled_at TIMESTAMPTZ;
        RAISE NOTICE 'Added cancelled_at column';
    END IF;

    -- Add delivered_at if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'delivered_at'
    ) THEN
        ALTER TABLE public.orders ADD COLUMN delivered_at TIMESTAMPTZ;
        RAISE NOTICE 'Added delivered_at column';
    END IF;

    -- Add cancellation_reason if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'cancellation_reason'
    ) THEN
        ALTER TABLE public.orders ADD COLUMN cancellation_reason TEXT;
        RAISE NOTICE 'Added cancellation_reason column';
    END IF;

END $$;

-- 3. Reload schema cache
NOTIFY pgrst, 'reload schema';

-- 4. Verify final structure
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'orders'
ORDER BY ordinal_position;
