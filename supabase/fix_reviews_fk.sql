-- Fix reviews foreign key to point to menu_items instead of products

-- Drop the existing foreign key constraint
ALTER TABLE public.reviews
  DROP CONSTRAINT IF EXISTS reviews_product_id_fkey;

-- Add new foreign key constraint pointing to menu_items
ALTER TABLE public.reviews
  ADD CONSTRAINT reviews_product_id_fkey
  FOREIGN KEY (product_id)
  REFERENCES public.menu_items(id)
  ON DELETE CASCADE;

-- Verify the constraint was created
SELECT
  tc.constraint_name,
  tc.table_name,
  kcu.column_name,
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
  AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_name = 'reviews'
  AND tc.table_schema = 'public';
