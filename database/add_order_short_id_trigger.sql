-- Function to auto-generate short_id for orders
-- This generates a human-readable order ID like "ORD-1234567890"

CREATE OR REPLACE FUNCTION set_order_short_id()
RETURNS TRIGGER AS $$
BEGIN
  -- Only set short_id if it's not already provided
  IF NEW.short_id IS NULL THEN
    NEW.short_id := 'ORD-' || EXTRACT(EPOCH FROM NOW())::BIGINT;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if exists
DROP TRIGGER IF EXISTS trigger_set_order_short_id ON orders;

-- Create trigger to auto-generate short_id on insert
CREATE TRIGGER trigger_set_order_short_id
  BEFORE INSERT ON orders
  FOR EACH ROW
  EXECUTE FUNCTION set_order_short_id();

-- Add comment for documentation
COMMENT ON FUNCTION set_order_short_id() IS 'Automatically generates a short_id (ORD-timestamp) for new orders if not provided';
