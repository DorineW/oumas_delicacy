-- ================================================================
-- CREATE RECEIPT NUMBER GENERATOR FUNCTION
-- ================================================================
-- This function generates unique receipt numbers
-- ================================================================

-- Drop existing function if it exists (in case of type mismatch)
DROP FUNCTION IF EXISTS generate_receipt_number();

CREATE OR REPLACE FUNCTION generate_receipt_number()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  new_receipt_number TEXT;
  receipt_count INTEGER;
BEGIN
  -- Get count of receipts today
  SELECT COUNT(*) INTO receipt_count
  FROM receipts
  WHERE DATE(issue_date) = CURRENT_DATE;
  
  -- Generate receipt number: RCP-YYYYMMDD-XXXX
  new_receipt_number := 'RCP-' || 
                        TO_CHAR(CURRENT_DATE, 'YYYYMMDD') || '-' ||
                        LPAD((receipt_count + 1)::TEXT, 4, '0');
  
  -- Check if it already exists (safety check)
  WHILE EXISTS (SELECT 1 FROM receipts WHERE receipt_number = new_receipt_number) LOOP
    receipt_count := receipt_count + 1;
    new_receipt_number := 'RCP-' || 
                          TO_CHAR(CURRENT_DATE, 'YYYYMMDD') || '-' ||
                          LPAD((receipt_count + 1)::TEXT, 4, '0');
  END LOOP;
  
  RETURN new_receipt_number;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION generate_receipt_number() TO authenticated;
GRANT EXECUTE ON FUNCTION generate_receipt_number() TO service_role;

-- ================================================================
-- TEST THE FUNCTION
-- ================================================================

SELECT generate_receipt_number() as sample_receipt_number;
