-- ============================================================================
-- Migration: Update and Create Comprehensive Reporting Views
-- Created: 2025-11-12
-- Description: Updates existing views and creates new comprehensive views for
--              detailed revenue analysis, hourly statistics, and menu analytics
-- ============================================================================

-- 1. UPDATE: order_statistics view
-- Purpose: Core daily statistics with revenue breakdown
DROP VIEW IF EXISTS order_statistics CASCADE;
CREATE OR REPLACE VIEW order_statistics AS
SELECT 
    DATE(placed_at) as order_day,
    COUNT(*) as total_orders,
    SUM(total) as total_revenue,
    AVG(total) as avg_order_value,
    MIN(total) as min_order_value,
    MAX(total) as max_order_value,
    SUM(subtotal) as total_subtotal,
    SUM(delivery_fee) as total_delivery_fees,
    SUM(tax) as total_tax,
    COUNT(CASE WHEN status = 'delivered' THEN 1 END) as completed_orders,
    COUNT(CASE WHEN status = 'cancelled' THEN 1 END) as cancelled_orders,
    COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_orders,
    COUNT(CASE WHEN status = 'confirmed' THEN 1 END) as confirmed_orders,
    COUNT(CASE WHEN status = 'preparing' THEN 1 END) as preparing_orders,
    COUNT(CASE WHEN status = 'outForDelivery' THEN 1 END) as out_for_delivery_orders
FROM orders
GROUP BY DATE(placed_at)
ORDER BY order_day DESC;

-- 2. UPDATE: popular_menu_items view
-- Purpose: Menu item performance with detailed pricing analytics
DROP VIEW IF EXISTS popular_menu_items CASCADE;
CREATE OR REPLACE VIEW popular_menu_items AS
SELECT 
    oi.name as item_name,
    oi.product_id,
    COUNT(DISTINCT oi.order_id) as order_count,
    SUM(oi.quantity) as total_quantity_sold,
    SUM(oi.total_price) as total_revenue,
    AVG(oi.unit_price) as avg_unit_price,
    MIN(oi.unit_price) as min_price,
    MAX(oi.unit_price) as max_price,
    AVG(oi.quantity) as avg_quantity_per_order,
    MIN(o.placed_at) as first_ordered,
    MAX(o.placed_at) as last_ordered
FROM order_items oi
JOIN orders o ON oi.order_id = o.id
WHERE o.status = 'delivered'
GROUP BY oi.name, oi.product_id
ORDER BY total_quantity_sold DESC;

-- 3. NEW: daily_revenue_breakdown view
-- Purpose: Detailed daily revenue analysis with breakdowns
DROP VIEW IF EXISTS daily_revenue_breakdown CASCADE;
CREATE OR REPLACE VIEW daily_revenue_breakdown AS
SELECT 
    DATE(placed_at) as order_day,
    -- Revenue breakdowns
    SUM(total) as daily_revenue,
    SUM(subtotal) as items_revenue,
    SUM(delivery_fee) as delivery_revenue,
    SUM(tax) as tax_collected,
    -- Order statistics
    COUNT(*) as order_count,
    COUNT(CASE WHEN status = 'delivered' THEN 1 END) as completed_count,
    COUNT(CASE WHEN status = 'cancelled' THEN 1 END) as cancelled_count,
    -- Order value analytics
    AVG(total) as avg_order_value,
    MIN(total) as min_order_value,
    MAX(total) as max_order_value,
    -- Revenue composition percentages
    CASE 
        WHEN SUM(total) > 0 THEN ROUND((SUM(subtotal)::numeric / SUM(total)::numeric * 100), 2)
        ELSE 0 
    END as items_revenue_percent,
    CASE 
        WHEN SUM(total) > 0 THEN ROUND((SUM(delivery_fee)::numeric / SUM(total)::numeric * 100), 2)
        ELSE 0 
    END as delivery_revenue_percent,
    CASE 
        WHEN SUM(total) > 0 THEN ROUND((SUM(tax)::numeric / SUM(total)::numeric * 100), 2)
        ELSE 0 
    END as tax_percent
FROM orders
WHERE status IN ('delivered', 'confirmed', 'preparing', 'outForDelivery')
GROUP BY DATE(placed_at)
ORDER BY order_day DESC;

-- 4. NEW: hourly_order_statistics view
-- Purpose: Hour-by-hour analysis for daily performance charts
DROP VIEW IF EXISTS hourly_order_statistics CASCADE;
CREATE OR REPLACE VIEW hourly_order_statistics AS
SELECT 
    DATE(placed_at) as order_day,
    EXTRACT(HOUR FROM placed_at)::integer as order_hour,
    COUNT(*) as total_orders,
    SUM(total) as total_revenue,
    AVG(total) as avg_order_value,
    MIN(total) as min_order_value,
    MAX(total) as max_order_value,
    SUM(subtotal) as items_revenue,
    SUM(delivery_fee) as delivery_revenue,
    COUNT(CASE WHEN status = 'delivered' THEN 1 END) as completed_orders,
    COUNT(CASE WHEN status = 'cancelled' THEN 1 END) as cancelled_orders,
    COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_orders
FROM orders
GROUP BY DATE(placed_at), EXTRACT(HOUR FROM placed_at)
ORDER BY order_day DESC, order_hour ASC;

-- Reload schema cache to make views immediately available
NOTIFY pgrst, 'reload schema';
