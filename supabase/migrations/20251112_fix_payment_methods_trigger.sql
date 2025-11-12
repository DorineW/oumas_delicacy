-- ============================================================================
-- Migration: Fix payment_methods table trigger error
-- Created: 2025-11-12
-- Description: Removes or fixes the trigger that's trying to set updated_at
--              column that doesn't exist in payment_methods table
-- ============================================================================

-- Check if updated_at column exists, if not, add it
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'payment_methods'
      AND column_name = 'updated_at'
  ) THEN
    ALTER TABLE public.payment_methods
    ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();
    
    RAISE NOTICE 'Added updated_at column to payment_methods table';
  ELSE
    RAISE NOTICE 'updated_at column already exists in payment_methods table';
  END IF;
END $$;

-- Create or replace the trigger function to set updated_at
CREATE OR REPLACE FUNCTION set_payment_methods_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS trg_payment_methods_updated_at ON public.payment_methods;

-- Create the trigger
CREATE TRIGGER trg_payment_methods_updated_at
  BEFORE UPDATE ON public.payment_methods
  FOR EACH ROW
  EXECUTE FUNCTION set_payment_methods_updated_at();

-- Reload schema cache
NOTIFY pgrst, 'reload schema';
