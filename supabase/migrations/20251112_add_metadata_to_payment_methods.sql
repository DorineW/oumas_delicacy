-- Add metadata column to payment_methods table for storing order details
ALTER TABLE payment_methods
ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT NULL;

-- Add comment to explain the column
COMMENT ON COLUMN payment_methods.metadata IS 'Stores order details during payment processing (before order creation)';
