-- ============================================
-- EMAIL RECEIPT TRIGGER
-- ============================================
-- Automatically sends order receipt via email when order is placed

-- Enable http extension for calling Edge Functions
CREATE EXTENSION IF NOT EXISTS http;

-- Function to send receipt email via Edge Function
CREATE OR REPLACE FUNCTION send_order_receipt_email()
RETURNS TRIGGER AS $$
DECLARE
  edge_function_url TEXT;
  response_status INTEGER;
BEGIN
  -- Only send email for new orders
  IF TG_OP = 'INSERT' AND NEW.status = 'pending' THEN
    
    -- Get the Edge Function URL from environment or use default
    -- You'll need to replace this with your actual Edge Function URL
    edge_function_url := current_setting('app.edge_function_url', true);
    
    IF edge_function_url IS NULL THEN
      edge_function_url := 'YOUR_SUPABASE_PROJECT_URL/functions/v1/send-order-receipt';
    END IF;
    
    -- Call the Edge Function to send email
    -- Note: This requires the http extension and proper configuration
    BEGIN
      SELECT status INTO response_status
      FROM http_post(
        edge_function_url,
        jsonb_build_object('orderId', NEW.id)::text,
        'application/json'
      );
      
      RAISE NOTICE 'Email receipt sent for order % (status: %)', NEW.short_id, response_status;
    EXCEPTION WHEN OTHERS THEN
      -- Log error but don't fail the transaction
      RAISE WARNING 'Failed to send receipt email for order %: %', NEW.short_id, SQLERRM;
    END;
    
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS trg_send_order_receipt_email ON public.orders;
CREATE TRIGGER trg_send_order_receipt_email
  AFTER INSERT ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION send_order_receipt_email();

COMMENT ON FUNCTION send_order_receipt_email IS 
  'Automatically sends order receipt via email when a new order is placed. Calls the send-order-receipt Edge Function.';

-- Note: You can also call the Edge Function directly from Flutter after order creation
-- This trigger provides automatic fallback if Flutter call fails
