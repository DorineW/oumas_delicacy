-- ============================================
-- FIX LOCATIONS TABLE - Add updated_at column
-- ============================================
-- This script adds the missing updated_at column to the locations table
-- and creates a trigger to automatically update it on changes

-- ============================================
-- STEP 1: Add updated_at column if it doesn't exist
-- ============================================
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public'
      AND table_name = 'locations' 
      AND column_name = 'updated_at'
  ) THEN
    ALTER TABLE public.locations 
      ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();
    
    -- Set updated_at to created_at for existing rows
    UPDATE public.locations 
    SET updated_at = created_at 
    WHERE updated_at IS NULL;
    
    RAISE NOTICE 'Added updated_at column to locations table';
  ELSE
    RAISE NOTICE 'Column updated_at already exists in locations table';
  END IF;
END $$;

-- ============================================
-- STEP 2: Create or replace the trigger function
-- ============================================
CREATE OR REPLACE FUNCTION update_locations_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- STEP 3: Create the trigger
-- ============================================
DROP TRIGGER IF EXISTS trg_locations_updated_at ON public.locations;

CREATE TRIGGER trg_locations_updated_at
  BEFORE UPDATE ON public.locations
  FOR EACH ROW
  EXECUTE FUNCTION update_locations_updated_at();

-- ============================================
-- STEP 4: Add comment for documentation
-- ============================================
COMMENT ON COLUMN public.locations.updated_at IS 
  'Timestamp when the location record was last updated. Automatically maintained by trigger.';

COMMENT ON FUNCTION update_locations_updated_at() IS 
  'Automatically updates the updated_at column when a location record is modified.';

-- ============================================
-- VERIFICATION
-- ============================================
-- Check the column exists
SELECT 
  column_name, 
  data_type, 
  is_nullable,
  column_default
FROM information_schema.columns 
WHERE table_schema = 'public'
  AND table_name = 'locations' 
  AND column_name = 'updated_at';

-- Check the trigger exists
SELECT 
  trigger_name,
  event_manipulation,
  event_object_table,
  action_statement
FROM information_schema.triggers
WHERE trigger_name = 'trg_locations_updated_at';

SELECT 'Locations table updated_at column and trigger created successfully!' AS status;
