-- ================================================================
-- UPDATE OLD ORDERS TO CONFIRMED
-- ================================================================
-- Manually update orders that were paid but stuck in pending_payment
-- ================================================================

-- Update all orders that have completed M-Pesa payments
UPDATE public.orders o
SET 
    status = 'confirmed',
    updated_at = now()
FROM public.mpesa_transactions mt
WHERE mt.order_id = o.id
  AND mt.status = 'completed'
  AND o.status = 'pending_payment'
RETURNING 
    o.short_id,
    o.status,
    o.total;

-- Verify the update
SELECT 
    o.short_id as order_number,
    o.status as order_status,
    o.total,
    mt.transaction_id,
    mt.status as payment_status
FROM public.orders o
JOIN public.mpesa_transactions mt ON mt.order_id = o.id
WHERE mt.status = 'completed'
ORDER BY o.placed_at DESC
LIMIT 10;
