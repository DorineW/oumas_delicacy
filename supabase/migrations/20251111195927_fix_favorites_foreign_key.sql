-- Fix favorites foreign key to point to menu_items table

-- Drop the incorrect constraint
ALTER TABLE public.favorites DROP CONSTRAINT IF EXISTS favorites_product_id_fkey;

-- Add correct constraint pointing to menu_items
ALTER TABLE public.favorites 
ADD CONSTRAINT favorites_product_id_fkey 
FOREIGN KEY (product_id) REFERENCES public.menu_items(id) ON DELETE CASCADE;
