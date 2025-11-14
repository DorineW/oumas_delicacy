-- Add location-related columns to users table
-- This allows users to save their delivery addresses and default location

-- Add addresses column (JSONB array to store multiple addresses)
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS addresses JSONB DEFAULT '[]'::jsonb;

-- Add default_address_index column (index of the default address in addresses array)
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS default_address_index INTEGER;

-- Add comment for documentation
COMMENT ON COLUMN public.users.addresses IS 'Array of delivery addresses stored as JSONB';
COMMENT ON COLUMN public.users.default_address_index IS 'Index of the default delivery address in the addresses array';

-- Log success
DO $$
BEGIN
  RAISE NOTICE '✅ Added location columns to users table';
  RAISE NOTICE '   - addresses (JSONB): Stores array of delivery addresses';
  RAISE NOTICE '   - default_address_index (INTEGER): Index of default address';
END $$;
