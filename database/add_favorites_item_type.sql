-- Add support for favoriting both menu items and store items
-- This allows users to favorite food (menu_items) and grocery items (StoreItems)

-- Step 1: Add item_type column to favorites table
ALTER TABLE favorites 
ADD COLUMN IF NOT EXISTS item_type TEXT NOT NULL DEFAULT 'menu_item';

-- Step 2: Add constraint to ensure valid item types
ALTER TABLE favorites 
ADD CONSTRAINT favorites_item_type_check 
CHECK (item_type IN ('menu_item', 'store_item'));

-- Step 3: Drop the old foreign key constraint that only allowed menu_items
ALTER TABLE favorites 
DROP CONSTRAINT IF EXISTS favorites_product_id_fkey;

-- Step 4: Recreate unique constraint to include item_type
-- This allows same product_id to be favorited if it's a different type
ALTER TABLE favorites 
DROP CONSTRAINT IF EXISTS favorites_user_auth_id_product_id_key;

ALTER TABLE favorites 
ADD CONSTRAINT favorites_user_auth_id_product_id_type_key 
UNIQUE (user_auth_id, product_id, item_type);

-- Step 5: Add indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_favorites_item_type 
ON favorites USING btree (item_type);

CREATE INDEX IF NOT EXISTS idx_favorites_product_type 
ON favorites USING btree (product_id, item_type);

-- NOTE: We removed the foreign key constraint because:
-- - menu_item favorites: product_id references menu_items.id
-- - store_item favorites: product_id references StoreItems.id
-- Without polymorphic foreign keys in PostgreSQL, we handle referential integrity in application code

-- Step 6: Create function to validate favorites based on item_type
CREATE OR REPLACE FUNCTION validate_favorite_reference()
RETURNS TRIGGER AS $$
BEGIN
  -- Validate menu_item exists
  IF NEW.item_type = 'menu_item' THEN
    IF NOT EXISTS (SELECT 1 FROM menu_items WHERE id = NEW.product_id) THEN
      RAISE EXCEPTION 'menu_item with id % does not exist', NEW.product_id;
    END IF;
  END IF;
  
  -- Validate store_item exists
  IF NEW.item_type = 'store_item' THEN
    IF NOT EXISTS (SELECT 1 FROM "StoreItems" WHERE id = NEW.product_id) THEN
      RAISE EXCEPTION 'store_item with id % does not exist', NEW.product_id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 7: Create trigger to validate references before insert/update
DROP TRIGGER IF EXISTS validate_favorite_reference_trigger ON favorites;

CREATE TRIGGER validate_favorite_reference_trigger
BEFORE INSERT OR UPDATE ON favorites
FOR EACH ROW
EXECUTE FUNCTION validate_favorite_reference();

-- Verify the changes
SELECT 
  column_name, 
  data_type, 
  column_default, 
  is_nullable
FROM information_schema.columns 
WHERE table_name = 'favorites'
ORDER BY ordinal_position;
