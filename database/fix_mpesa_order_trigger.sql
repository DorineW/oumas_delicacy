-- ================================================================
-- FIX M-PESA ORDER STATUS UPDATE TRIGGER
-- ================================================================
-- This ensures orders are properly updated when payments complete
-- ================================================================

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS trg_update_order_status_on_payment ON public.mpesa_transactions;
DROP FUNCTION IF EXISTS public.update_order_status_on_payment();

-- Create improved trigger function
CREATE OR REPLACE FUNCTION public.update_order_status_on_payment()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_order_status text;
    v_rows_updated int;
BEGIN
    -- Only proceed if payment is completed and has an order_id
    IF NEW.status = 'completed' AND NEW.order_id IS NOT NULL THEN
        
        -- Check if this is a new completion (not already completed)
        IF TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM 'completed') THEN
            
            -- Get current order status
            SELECT status INTO v_order_status
            FROM public.orders
            WHERE id = NEW.order_id;
            
            -- Log for debugging
            RAISE NOTICE 'M-Pesa payment completed for order %. Current status: %', NEW.order_id, v_order_status;
            
            -- Update order status if it's still pending payment
            IF v_order_status = 'pending_payment' OR v_order_status = 'pending' THEN
                UPDATE public.orders
                SET 
                    status = 'confirmed',
                    updated_at = now()
                WHERE id = NEW.order_id;
                
                GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
                RAISE NOTICE 'Updated % order(s) to confirmed status', v_rows_updated;
            ELSE
                RAISE NOTICE 'Order % already has status %, skipping update', NEW.order_id, v_order_status;
            END IF;
            
        END IF;
    END IF;
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        -- Log error but don't fail the transaction insert/update
        RAISE WARNING 'Error updating order status for M-Pesa transaction %: %', NEW.id, SQLERRM;
        RETURN NEW;
END;
$$;

-- Create the trigger
CREATE TRIGGER trg_update_order_status_on_payment
AFTER INSERT OR UPDATE OF status ON public.mpesa_transactions
FOR EACH ROW
EXECUTE FUNCTION public.update_order_status_on_payment();

-- Add helpful comments
COMMENT ON FUNCTION public.update_order_status_on_payment() IS 
'Automatically updates order status to confirmed when M-Pesa payment completes. 
Only updates orders with status pending_payment or pending.';

COMMENT ON TRIGGER trg_update_order_status_on_payment ON public.mpesa_transactions IS 
'Triggers when M-Pesa transaction is inserted or status updated to completed';

-- ================================================================
-- BACKFILL: Link completed payments to their orders
-- ================================================================
-- This fixes any historical transactions that are missing order_id

DO $$
DECLARE
    v_updated_count int := 0;
    v_transaction record;
BEGIN
    RAISE NOTICE '🔍 Searching for completed M-Pesa transactions without order_id...';
    
    -- Find completed transactions without order_id
    FOR v_transaction IN 
        SELECT 
            mt.id,
            mt.transaction_id,
            mt.checkout_request_id,
            mt.user_auth_id,
            mt.amount,
            mt.transaction_timestamp
        FROM public.mpesa_transactions mt
        WHERE mt.status = 'completed'
          AND mt.order_id IS NULL
          AND mt.user_auth_id IS NOT NULL
    LOOP
        -- Try to find matching order by user, amount, and time (within 5 minutes)
        DECLARE
            v_matching_order_id uuid;
        BEGIN
            SELECT o.id INTO v_matching_order_id
            FROM public.orders o
            WHERE o.user_auth_id = v_transaction.user_auth_id
              AND o.total = v_transaction.amount
              AND o.status IN ('pending_payment', 'pending')
              AND ABS(EXTRACT(EPOCH FROM (o.placed_at - v_transaction.transaction_timestamp))) < 300 -- 5 minutes
            ORDER BY o.placed_at DESC
            LIMIT 1;
            
            IF v_matching_order_id IS NOT NULL THEN
                -- Link transaction to order
                UPDATE public.mpesa_transactions
                SET order_id = v_matching_order_id
                WHERE id = v_transaction.id;
                
                -- Update order status
                UPDATE public.orders
                SET status = 'confirmed'
                WHERE id = v_matching_order_id;
                
                v_updated_count := v_updated_count + 1;
                RAISE NOTICE '✅ Linked transaction % to order %', v_transaction.transaction_id, v_matching_order_id;
            END IF;
        END;
    END LOOP;
    
    RAISE NOTICE '📊 Backfill complete: % transactions linked and orders updated', v_updated_count;
END $$;

-- ================================================================
-- VERIFY THE FIX
-- ================================================================

SELECT 
    'Trigger Status' AS check_type,
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ Trigger exists and is enabled'
        ELSE '❌ Trigger not found'
    END AS status
FROM information_schema.triggers
WHERE trigger_name = 'trg_update_order_status_on_payment'
  AND event_object_table = 'mpesa_transactions';

-- Show completed payments and their order status
SELECT 
    mt.transaction_id,
    mt.status AS payment_status,
    mt.amount,
    mt.order_id,
    o.short_id,
    o.status AS order_status,
    CASE 
        WHEN mt.order_id IS NULL THEN '❌ No order linked'
        WHEN o.status = 'confirmed' THEN '✅ Order confirmed'
        WHEN o.status = 'pending_payment' THEN '⚠️ Still pending'
        ELSE '⚠️ Status: ' || o.status
    END AS result
FROM public.mpesa_transactions mt
LEFT JOIN public.orders o ON o.id = mt.order_id
WHERE mt.status = 'completed'
ORDER BY mt.created_at DESC
LIMIT 10;
