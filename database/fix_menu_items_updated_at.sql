-- Fix menu_items table to have updated_at column with proper trigger
-- Run this in your Supabase SQL Editor

-- 1. Add updated_at column if it doesn't exist
ALTER TABLE public.menu_items 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 2. Create or replace the trigger function
CREATE OR REPLACE FUNCTION public.set_menu_items_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Drop existing trigger if it exists
DROP TRIGGER IF EXISTS trg_menu_items_updated_at ON public.menu_items;

-- 4. Create the trigger
CREATE TRIGGER trg_menu_items_updated_at
  BEFORE UPDATE ON public.menu_items
  FOR EACH ROW
  EXECUTE FUNCTION public.set_menu_items_updated_at();

-- 5. Verify the column exists
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'menu_items'
  AND column_name = 'updated_at';
