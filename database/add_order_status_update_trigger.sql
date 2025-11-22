-- Creates a trigger to automatically update the order status when an M-Pesa payment is marked as completed.
-- This removes the need for manual intervention to link payments to orders.

CREATE OR REPLACE FUNCTION public.update_order_status_on_payment()
RETURNS TRIGGER AS $$
BEGIN
  -- Check if the transaction status is updated to 'completed' and it has an associated order.
  -- The condition OLD.status IS DISTINCT FROM 'completed' ensures this only runs once when the status changes to completed.
  IF NEW.status = 'completed' AND OLD.status IS DISTINCT FROM 'completed' AND NEW.order_id IS NOT NULL THEN
    -- Update the corresponding order's status to 'confirmed'.
    UPDATE public.orders
    SET status = 'confirmed'
    WHERE id = NEW.order_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop the trigger if it already exists to avoid duplicates
DROP TRIGGER IF EXISTS trg_update_order_status_on_payment ON public.mpesa_transactions;

-- Create the trigger that executes the function after a row is inserted or updated in mpesa_transactions.
CREATE TRIGGER trg_update_order_status_on_payment
AFTER INSERT OR UPDATE OF status ON public.mpesa_transactions
FOR EACH ROW
EXECUTE FUNCTION public.update_order_status_on_payment();

COMMENT ON FUNCTION public.update_order_status_on_payment() IS 'Trigger function to update the order status to "confirmed" upon successful M-Pesa payment.';
COMMENT ON TRIGGER trg_update_order_status_on_payment ON public.mpesa_transactions IS 'After an M-Pesa transaction is inserted or its status is updated, this trigger updates the corresponding order status if the payment is complete.';
