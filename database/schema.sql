-- ============================================
-- Database Schema for Ouma's Delicacy Food Delivery App
-- Generated from Dart models
-- ============================================

-- ============================================
-- USERS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role ENUM('customer', 'admin', 'rider') DEFAULT 'customer',
    phone VARCHAR(20),
    profile_image_path TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_email (email),
    INDEX idx_role (role)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- MENU ITEMS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS menu_items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    price INT NOT NULL,
    rating DECIMAL(2,1) DEFAULT 4.5,
    category VARCHAR(100) NOT NULL,
    meal_weight ENUM('Light', 'Medium', 'Heavy') DEFAULT 'Medium',
    description TEXT,
    image LONGBLOB,
    image_url VARCHAR(500),
    is_available BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_category (category),
    INDEX idx_meal_weight (meal_weight),
    INDEX idx_available (is_available),
    INDEX idx_title (title)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- ORDERS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS orders (
    id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(255) NOT NULL,
    customer_name VARCHAR(255) NOT NULL,
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total_amount INT NOT NULL,
    status ENUM('pending', 'confirmed', 'preparing', 'outForDelivery', 'delivered', 'cancelled') DEFAULT 'pending',
    delivery_type ENUM('delivery', 'pickup') NOT NULL,
    delivery_address TEXT,
    delivery_phone VARCHAR(20),
    special_instructions TEXT,
    rider_id VARCHAR(255),
    cancellation_reason TEXT,
    cancelled_at TIMESTAMP NULL,
    delivered_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (rider_id) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_customer_id (customer_id),
    INDEX idx_status (status),
    INDEX idx_rider_id (rider_id),
    INDEX idx_order_date (order_date),
    INDEX idx_delivery_type (delivery_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- ORDER ITEMS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS order_items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    order_id VARCHAR(50) NOT NULL,
    item_id VARCHAR(255) NOT NULL,
    title VARCHAR(255) NOT NULL,
    quantity INT NOT NULL,
    price INT NOT NULL,
    rating INT NULL CHECK (rating >= 1 AND rating <= 5),
    review TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    INDEX idx_order_id (order_id),
    INDEX idx_item_id (item_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- CART ITEMS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS cart_items (
    id VARCHAR(255) PRIMARY KEY,
    customer_id VARCHAR(255) NOT NULL,
    meal_title VARCHAR(255) NOT NULL,
    price INT NOT NULL,
    quantity INT NOT NULL,
    meal_image VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_customer_id (customer_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- LOCATIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS locations (
    id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id VARCHAR(255) NOT NULL,
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    delivery_address TEXT NOT NULL,
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_customer_id (customer_id),
    INDEX idx_coordinates (latitude, longitude),
    INDEX idx_is_default (is_default)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- NOTIFICATIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS notifications (
    id VARCHAR(255) PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    type ENUM('order', 'delivery', 'promotion', 'system') DEFAULT 'system',
    is_read BOOLEAN DEFAULT FALSE,
    order_id VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    read_at TIMESTAMP NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL,
    INDEX idx_user_id (user_id),
    INDEX idx_is_read (is_read),
    INDEX idx_created_at (created_at),
    INDEX idx_type (type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- REVIEWS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS reviews (
    id INT AUTO_INCREMENT PRIMARY KEY,
    order_id VARCHAR(50) NOT NULL,
    meal_title VARCHAR(255) NOT NULL,
    user_name VARCHAR(255) NOT NULL,
    is_anonymous BOOLEAN DEFAULT FALSE,
    rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    INDEX idx_order_id (order_id),
    INDEX idx_meal_title (meal_title),
    INDEX idx_rating (rating),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- FAVORITES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS favorites (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    meal_title VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_meal (user_id, meal_title),
    INDEX idx_user_id (user_id),
    INDEX idx_meal_title (meal_title)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- PAYMENT METHODS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS payment_methods (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    card_brand VARCHAR(50) NOT NULL,
    last_four_digits VARCHAR(4) NOT NULL,
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id),
    INDEX idx_is_default (is_default)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- INVENTORY TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS inventory (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    category VARCHAR(100) NOT NULL,
    current_stock DECIMAL(10, 2) NOT NULL DEFAULT 0,
    unit VARCHAR(50) NOT NULL,
    low_stock_threshold DECIMAL(10, 2) NOT NULL,
    cost_price DECIMAL(10, 2) NOT NULL,
    last_restocked TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_category (category),
    INDEX idx_is_active (is_active),
    INDEX idx_low_stock (current_stock, low_stock_threshold)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- STOCK HISTORY TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS stock_history (
    id INT AUTO_INCREMENT PRIMARY KEY,
    item_id VARCHAR(255) NOT NULL,
    type ENUM('restock', 'adjustment', 'sale') NOT NULL,
    quantity DECIMAL(10, 2) NOT NULL,
    note TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (item_id) REFERENCES inventory(id) ON DELETE CASCADE,
    INDEX idx_item_id (item_id),
    INDEX idx_type (type),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- RIDER EARNINGS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS rider_earnings (
    id INT AUTO_INCREMENT PRIMARY KEY,
    rider_id VARCHAR(255) NOT NULL,
    order_id VARCHAR(50) NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    earned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (rider_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    INDEX idx_rider_id (rider_id),
    INDEX idx_order_id (order_id),
    INDEX idx_earned_at (earned_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- SAMPLE DATA INSERTS (Optional - for testing)
-- ============================================

-- Insert sample admin user
INSERT INTO users (id, name, email, password, role, phone) VALUES
('admin-001', 'Admin User', 'admin@oumasdelicacy.com', '$2a$10$hashed_password_here', 'admin', '+254700000001'),
('rider-001', 'John Rider', 'rider@oumasdelicacy.com', '$2a$10$hashed_password_here', 'rider', '+254700000002'),
('customer-001', 'Jane Customer', 'customer@example.com', '$2a$10$hashed_password_here', 'customer', '+254700000003');

-- Insert sample menu items
INSERT INTO menu_items (title, price, rating, category, meal_weight, description, image_url, is_available) VALUES
('Ugali & Sukuma Wiki', 250, 4.8, 'Traditional', 'Heavy', 'Traditional Kenyan meal with sukuma wiki', 'assets/images/ugali_sukuma.jpg', TRUE),
('Beef Stew', 350, 4.6, 'Main Course', 'Heavy', 'Tender beef stew with rich gravy', 'assets/images/beef_stew.jpg', TRUE),
('Pilau Rice', 300, 4.7, 'Rice Dishes', 'Medium', 'Fragrant spiced rice', 'assets/images/pilau.jpg', TRUE),
('Chapati (3 pcs)', 150, 4.5, 'Sides', 'Light', 'Soft homemade chapatis', 'assets/images/chapati.jpg', TRUE),
('Chicken Curry', 400, 4.9, 'Main Course', 'Heavy', 'Spicy chicken curry with coconut', 'assets/images/chicken_curry.jpg', TRUE);

-- Insert sample inventory items
INSERT INTO inventory (id, name, category, current_stock, unit, low_stock_threshold, cost_price) VALUES
('inv-001', 'Ugali Flour', 'Grains', 25.5, 'kg', 10.0, 80.0),
('inv-002', 'Beef (Prime Cut)', 'Meat', 8.5, 'kg', 10.0, 450.0),
('inv-003', 'Rice (Pishori)', 'Grains', 45.0, 'kg', 20.0, 120.0),
('inv-004', 'Cooking Oil', 'Oils', 15.0, 'liters', 8.0, 180.0),
('inv-005', 'Tomatoes', 'Vegetables', 3.0, 'kg', 5.0, 50.0);

-- ============================================
-- VIEWS (Optional - for reporting)
-- ============================================

-- View for order statistics
CREATE OR REPLACE VIEW order_statistics AS
SELECT 
    DATE(order_date) as order_day,
    COUNT(*) as total_orders,
    SUM(total_amount) as total_revenue,
    AVG(total_amount) as avg_order_value,
    COUNT(CASE WHEN status = 'delivered' THEN 1 END) as completed_orders,
    COUNT(CASE WHEN status = 'cancelled' THEN 1 END) as cancelled_orders
FROM orders
GROUP BY DATE(order_date)
ORDER BY order_day DESC;

-- View for popular menu items
CREATE OR REPLACE VIEW popular_menu_items AS
SELECT 
    oi.title,
    COUNT(*) as order_count,
    SUM(oi.quantity) as total_quantity_sold,
    SUM(oi.price * oi.quantity) as total_revenue,
    AVG(oi.rating) as avg_rating
FROM order_items oi
JOIN orders o ON oi.order_id = o.id
WHERE o.status = 'delivered'
GROUP BY oi.title
ORDER BY total_quantity_sold DESC;

-- View for low stock items
CREATE OR REPLACE VIEW low_stock_items AS
SELECT 
    id,
    name,
    category,
    current_stock,
    low_stock_threshold,
    unit,
    (low_stock_threshold - current_stock) as stock_deficit
FROM inventory
WHERE current_stock <= low_stock_threshold
  AND is_active = TRUE
ORDER BY stock_deficit DESC;

-- View for rider performance
CREATE OR REPLACE VIEW rider_performance AS
SELECT 
    u.id as rider_id,
    u.name as rider_name,
    COUNT(o.id) as total_deliveries,
    SUM(o.total_amount) as total_value_delivered,
    COUNT(CASE WHEN o.status = 'delivered' THEN 1 END) as successful_deliveries,
    COALESCE(SUM(re.amount), 0) as total_earnings
FROM users u
LEFT JOIN orders o ON u.id = o.rider_id
LEFT JOIN rider_earnings re ON u.id = re.rider_id
WHERE u.role = 'rider'
GROUP BY u.id, u.name
ORDER BY total_deliveries DESC;

-- ============================================
-- TRIGGERS (Optional - for automation)
-- ============================================

-- Trigger to update order status timestamp
DELIMITER $$
CREATE TRIGGER update_order_delivered_at
BEFORE UPDATE ON orders
FOR EACH ROW
BEGIN
    IF NEW.status = 'delivered' AND OLD.status != 'delivered' THEN
        SET NEW.delivered_at = CURRENT_TIMESTAMP;
    END IF;
    
    IF NEW.status = 'cancelled' AND OLD.status != 'cancelled' THEN
        SET NEW.cancelled_at = CURRENT_TIMESTAMP;
    END IF;
END$$
DELIMITER ;

-- Trigger to mark notification as read
DELIMITER $$
CREATE TRIGGER update_notification_read_at
BEFORE UPDATE ON notifications
FOR EACH ROW
BEGIN
    IF NEW.is_read = TRUE AND OLD.is_read = FALSE THEN
        SET NEW.read_at = CURRENT_TIMESTAMP;
    END IF;
END$$
DELIMITER ;

-- ============================================
-- STORED PROCEDURES (Optional - for common operations)
-- ============================================

-- Procedure to get customer order history
DELIMITER $$
CREATE PROCEDURE get_customer_orders(IN p_customer_id VARCHAR(255))
BEGIN
    SELECT 
        o.*,
        GROUP_CONCAT(
            CONCAT(oi.quantity, 'x ', oi.title)
            SEPARATOR ', '
        ) as items_summary
    FROM orders o
    LEFT JOIN order_items oi ON o.id = oi.order_id
    WHERE o.customer_id = p_customer_id
    GROUP BY o.id
    ORDER BY o.order_date DESC;
END$$
DELIMITER ;

-- Procedure to calculate daily revenue
DELIMITER $$
CREATE PROCEDURE get_daily_revenue(IN p_date DATE)
BEGIN
    SELECT 
        COUNT(*) as total_orders,
        SUM(total_amount) as total_revenue,
        AVG(total_amount) as avg_order_value,
        COUNT(CASE WHEN delivery_type = 'delivery' THEN 1 END) as delivery_orders,
        COUNT(CASE WHEN delivery_type = 'pickup' THEN 1 END) as pickup_orders
    FROM orders
    WHERE DATE(order_date) = p_date
      AND status = 'delivered';
END$$
DELIMITER ;

-- ============================================
-- INDEXES FOR PERFORMANCE (Additional)
-- ============================================

-- Composite indexes for common queries
CREATE INDEX idx_orders_customer_status ON orders(customer_id, status);
CREATE INDEX idx_orders_rider_status ON orders(rider_id, status);
CREATE INDEX idx_order_items_title_rating ON order_items(title, rating);
CREATE INDEX idx_notifications_user_read ON notifications(user_id, is_read);

-- ============================================
-- END OF SCHEMA
-- ============================================

-- ============================================
-- PROFILES TABLE (Supabase/Postgres)
-- Stores app-visible user details referencing Supabase Auth user id.
-- ============================================
-- Note: This block targets Postgres (Supabase). Adjust types if using MySQL locally.
CREATE TABLE IF NOT EXISTS profiles (
    id BIGSERIAL PRIMARY KEY,
    auth_id UUID UNIQUE NOT NULL,        -- references auth.users.id in Supabase
    email TEXT UNIQUE NOT NULL,
    name TEXT,
    phone TEXT,
    role TEXT DEFAULT 'customer',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Update trigger to keep updated_at current (Postgres)
CREATE OR REPLACE FUNCTION set_profiles_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_profiles_updated_at ON profiles;
CREATE TRIGGER trg_profiles_updated_at
BEFORE UPDATE ON profiles
FOR EACH ROW EXECUTE FUNCTION set_profiles_updated_at();
