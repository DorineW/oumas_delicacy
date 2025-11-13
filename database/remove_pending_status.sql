-- ============================================
-- Migration: Remove 'pending' status from orders
-- Date: 2024
-- Description: Removes the 'pending' status from order status enum
--              and updates existing pending orders to 'confirmed'
-- ============================================

-- Step 1: Update any existing 'pending' orders to 'confirmed'
UPDATE orders 
SET status = 'confirmed' 
WHERE status = 'pending';

-- Step 2: Modify the status enum to remove 'pending'
-- Note: In MySQL/PostgreSQL, modifying ENUMs requires recreating the column
ALTER TABLE orders 
MODIFY COLUMN status ENUM('confirmed', 'preparing', 'outForDelivery', 'delivered', 'cancelled') 
DEFAULT 'confirmed' NOT NULL;

-- Step 3: Verify the change
SELECT DISTINCT status FROM orders;

-- Step 4: Show count of orders by status
SELECT status, COUNT(*) as count 
FROM orders 
GROUP BY status 
ORDER BY count DESC;

-- ============================================
-- For Supabase (PostgreSQL):
-- ============================================
-- If using Supabase/PostgreSQL, use this instead:
/*
-- Step 1: Update existing pending orders
UPDATE orders 
SET status = 'confirmed' 
WHERE status = 'pending';

-- Step 2: Create new enum type without 'pending'
CREATE TYPE order_status_new AS ENUM ('confirmed', 'preparing', 'outForDelivery', 'delivered', 'cancelled');

-- Step 3: Alter the column to use the new type
ALTER TABLE orders 
ALTER COLUMN status TYPE order_status_new 
USING status::text::order_status_new;

-- Step 4: Set the default value
ALTER TABLE orders 
ALTER COLUMN status SET DEFAULT 'confirmed';

-- Step 5: Drop the old enum type
DROP TYPE IF EXISTS order_status CASCADE;

-- Step 6: Rename the new type to the original name
ALTER TYPE order_status_new RENAME TO order_status;

-- Step 7: Verify the change
SELECT DISTINCT status FROM orders;
*/
