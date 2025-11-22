-- Check order_items table structure
SELECT 
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'order_items'
ORDER BY ordinal_position;

-- Show sample data
SELECT * FROM order_items LIMIT 1;
