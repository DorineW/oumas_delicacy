-- ================================================================
-- DIAGNOSE M-PESA ORDER CREATION ISSUE
-- ================================================================
-- Run this to check what's happening with your orders and payments
-- ================================================================

-- 1. Check recent M-Pesa transactions
SELECT 
    id,
    transaction_id,
    checkout_request_id,
    status,
    amount,
    phone_number,
    order_id,
    user_auth_id,
    created_at,
    updated_at
FROM public.mpesa_transactions
ORDER BY created_at DESC
LIMIT 10;

-- 2. Check recent orders
SELECT 
    id,
    short_id,
    user_auth_id,
    status,
    total,
    placed_at,
    updated_at
FROM public.orders
ORDER BY placed_at DESC
LIMIT 10;

-- 3. Find M-Pesa transactions WITHOUT orders
SELECT 
    mt.id,
    mt.transaction_id,
    mt.checkout_request_id,
    mt.status AS mpesa_status,
    mt.amount,
    mt.order_id,
    mt.created_at,
    CASE 
        WHEN mt.order_id IS NULL THEN '❌ NO ORDER_ID'
        WHEN o.id IS NULL THEN '❌ ORDER NOT FOUND'
        ELSE '✅ ORDER EXISTS'
    END AS order_status
FROM public.mpesa_transactions mt
LEFT JOIN public.orders o ON o.id = mt.order_id
WHERE mt.status = 'completed'
ORDER BY mt.created_at DESC
LIMIT 10;

-- 4. Check if trigger exists and is enabled
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement,
    action_timing
FROM information_schema.triggers
WHERE trigger_name = 'trg_update_order_status_on_payment';

-- 5. Check the trigger function
SELECT 
    p.proname AS function_name,
    pg_get_functiondef(p.oid) AS function_definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'update_order_status_on_payment';

-- 6. Find completed payments with their order status
SELECT 
    mt.transaction_id,
    mt.checkout_request_id,
    mt.status AS payment_status,
    mt.amount,
    mt.order_id,
    o.short_id,
    o.status AS order_status,
    o.total AS order_total,
    mt.created_at AS payment_created,
    mt.updated_at AS payment_updated,
    o.placed_at AS order_placed,
    o.updated_at AS order_updated
FROM public.mpesa_transactions mt
LEFT JOIN public.orders o ON o.id = mt.order_id
WHERE mt.status = 'completed'
ORDER BY mt.created_at DESC
LIMIT 10;

-- 7. Check for orphaned completed payments (no order_id)
SELECT 
    COUNT(*) AS orphaned_payments,
    SUM(amount) AS total_amount
FROM public.mpesa_transactions
WHERE status = 'completed' 
  AND order_id IS NULL;

-- ================================================================
-- COMMON ISSUES & SOLUTIONS
-- ================================================================

-- ISSUE 1: Order created but payment has no order_id
-- SOLUTION: Your Flutter app should pass orderId when initiating payment

-- ISSUE 2: Trigger not firing
-- SOLUTION: Check if trigger is enabled (query #4 above)

-- ISSUE 3: Order status not updating
-- POSSIBLE CAUSES:
--   - Order already has status 'confirmed' (trigger skips it)
--   - RLS policies blocking the update
--   - Trigger function has an error

-- ================================================================
-- TO TEST THE TRIGGER MANUALLY:
-- ================================================================

-- Find a completed payment with an order_id
-- Then check if the order status was updated
-- Example:
/*
DO $$
DECLARE
    test_order_id uuid;
    test_transaction_id uuid;
BEGIN
    -- Get a recent completed payment
    SELECT order_id, id INTO test_order_id, test_transaction_id
    FROM public.mpesa_transactions
    WHERE status = 'completed' AND order_id IS NOT NULL
    ORDER BY created_at DESC
    LIMIT 1;
    
    RAISE NOTICE 'Transaction ID: %', test_transaction_id;
    RAISE NOTICE 'Order ID: %', test_order_id;
    
    -- Check order status
    SELECT status INTO test_order_id
    FROM public.orders
    WHERE id = test_order_id;
    
    RAISE NOTICE 'Order Status: %', test_order_id;
END $$;
*/
