-- ================================================================
-- Migration: Add Flexible Unit Description to StoreItems
-- Date: 2025-11-15
-- Purpose: Replace rigid unit_of_measure constraint with flexible 
--          unit_description to handle real-world scenarios like:
--          - "500g", "1kg", "2kg" for different weight products
--          - "150ml", "250ml", "500ml", "1L", "2L" for beverages
--          - "Half", "Quarter", "Whole" for produce
--          - "1 Piece", "Bundle of 6", "Sack" for varying quantities
-- ================================================================

BEGIN;

-- Step 1: Add new column for flexible unit description
ALTER TABLE public."StoreItems" 
ADD COLUMN IF NOT EXISTS unit_description text NULL;

-- Step 2: Migrate existing data to new format
-- Combine unit_of_measure with a default description for existing items
UPDATE public."StoreItems"
SET unit_description = 
  CASE unit_of_measure
    WHEN 'Piece' THEN '1 Piece'
    WHEN 'Kilogram' THEN '1 Kg'
    WHEN 'Liter' THEN '1 Liter'
    WHEN 'Packet' THEN '1 Packet'
    WHEN 'Set' THEN '1 Set'
    ELSE COALESCE(unit_of_measure, '1 Piece')
  END
WHERE unit_description IS NULL;

-- Step 3: Make unit_description required after migration
ALTER TABLE public."StoreItems" 
ALTER COLUMN unit_description SET NOT NULL,
ALTER COLUMN unit_description SET DEFAULT '1 Piece';

-- Step 4: Drop the old constraint that limited to 5 values
ALTER TABLE public."StoreItems" 
DROP CONSTRAINT IF EXISTS "StoreItems_unit_of_measure_check";

-- Step 5: Make unit_of_measure nullable (legacy field, kept for compatibility)
ALTER TABLE public."StoreItems" 
ALTER COLUMN unit_of_measure DROP NOT NULL;

-- Optional: Set default for backward compatibility
ALTER TABLE public."StoreItems" 
ALTER COLUMN unit_of_measure SET DEFAULT 'Piece';

-- Step 6: Add helpful comment for documentation
COMMENT ON COLUMN public."StoreItems".unit_description IS 
'Flexible unit description allowing specific quantities like "500g", "2L", "Half Cabbage", "1 Sack", "250ml Can", etc. This replaces the rigid unit_of_measure field to handle real-world product variations.';

COMMENT ON COLUMN public."StoreItems".unit_of_measure IS 
'Legacy field kept for backward compatibility. Use unit_description instead for new items.';

-- Step 7: Create index for faster queries on unit_description
CREATE INDEX IF NOT EXISTS idx_storeitems_unit_description 
ON public."StoreItems" (unit_description);

COMMIT;

-- ================================================================
-- Verification Queries
-- ================================================================

-- Check the schema changes
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'StoreItems'
    AND column_name IN ('unit_of_measure', 'unit_description')
ORDER BY ordinal_position;

-- View migrated data
SELECT 
    id,
    name,
    unit_of_measure,
    unit_description,
    price,
    category
FROM public."StoreItems"
ORDER BY created_at DESC
LIMIT 20;

-- ================================================================
-- Example Usage - How to add new items with flexible units
-- ================================================================

-- Example: Different sizes of salt
-- INSERT INTO public."StoreItems" (product_id, name, description, price, category, unit_of_measure, unit_description, available)
-- VALUES 
--   (gen_random_uuid(), 'Salt - Small', 'Quality sea salt', 25.00, 'Groceries', 'Packet', '250g', true),
--   (gen_random_uuid(), 'Salt - Medium', 'Quality sea salt', 45.00, 'Groceries', 'Packet', '500g', true),
--   (gen_random_uuid(), 'Salt - Large', 'Quality sea salt', 85.00, 'Groceries', 'Packet', '1kg', true);

-- Example: Different sizes of soda
-- INSERT INTO public."StoreItems" (product_id, name, description, price, category, unit_of_measure, unit_description, available)
-- VALUES 
--   (gen_random_uuid(), 'Coca-Cola Can', 'Refreshing cola drink', 60.00, 'Beverages', 'Liter', '300ml Can', true),
--   (gen_random_uuid(), 'Coca-Cola Bottle', 'Refreshing cola drink', 100.00, 'Beverages', 'Liter', '500ml Bottle', true),
--   (gen_random_uuid(), 'Coca-Cola Family', 'Refreshing cola drink', 180.00, 'Beverages', 'Liter', '1.5L Bottle', true),
--   (gen_random_uuid(), 'Coca-Cola Party', 'Refreshing cola drink', 250.00, 'Beverages', 'Liter', '2L Bottle', true);

-- Example: Cabbage by portions
-- INSERT INTO public."StoreItems" (product_id, name, description, price, category, unit_of_measure, unit_description, available)
-- VALUES 
--   (gen_random_uuid(), 'Cabbage - Quarter', 'Fresh local cabbage', 25.00, 'Vegetables', 'Piece', 'Quarter', true),
--   (gen_random_uuid(), 'Cabbage - Half', 'Fresh local cabbage', 45.00, 'Vegetables', 'Piece', 'Half', true),
--   (gen_random_uuid(), 'Cabbage - Whole', 'Fresh local cabbage', 80.00, 'Vegetables', 'Piece', 'Whole', true);

-- Example: Potatoes by different measurements
-- INSERT INTO public."StoreItems" (product_id, name, description, price, category, unit_of_measure, unit_description, available)
-- VALUES 
--   (gen_random_uuid(), 'Potatoes - Small Pack', 'Fresh potatoes', 50.00, 'Vegetables', 'Kilogram', '1 Kg', true),
--   (gen_random_uuid(), 'Potatoes - Medium Pack', 'Fresh potatoes', 120.00, 'Vegetables', 'Kilogram', '2.5 Kg', true),
--   (gen_random_uuid(), 'Potatoes - Sack', 'Fresh potatoes bulk', 800.00, 'Vegetables', 'Kilogram', '25 Kg Sack', true);
