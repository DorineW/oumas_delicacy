-- Fix order_items foreign key to point to menu_items table instead of products

-- Drop the incorrect constraint
ALTER TABLE public.order_items DROP CONSTRAINT IF EXISTS order_items_product_id_fkey;

-- Add correct constraint pointing to menu_items
ALTER TABLE public.order_items 
ADD CONSTRAINT order_items_product_id_fkey 
FOREIGN KEY (product_id) REFERENCES public.menu_items(id) ON DELETE CASCADE;
