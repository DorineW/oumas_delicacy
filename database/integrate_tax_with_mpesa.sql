-- ============================================
-- INTEGRATE TAX COLUMN WITH MPESA TRANSACTIONS
-- ============================================
-- Links orders.tax with mpesa_transactions and receipts
-- Ensures tax is properly tracked across payment system

-- ============================================
-- STEP 1: Add tax_amount column to mpesa_transactions if not exists
-- ============================================
ALTER TABLE public.mpesa_transactions 
ADD COLUMN IF NOT EXISTS tax_amount NUMERIC(15,2) DEFAULT 0;

ALTER TABLE public.mpesa_transactions 
ADD COLUMN IF NOT EXISTS subtotal_amount NUMERIC(15,2) DEFAULT 0;

ALTER TABLE public.mpesa_transactions 
ADD COLUMN IF NOT EXISTS delivery_fee NUMERIC(15,2) DEFAULT 0;

COMMENT ON COLUMN public.mpesa_transactions.tax_amount IS 'Tax amount from order (matches orders.tax)';
COMMENT ON COLUMN public.mpesa_transactions.subtotal_amount IS 'Subtotal from order (matches orders.subtotal)';
COMMENT ON COLUMN public.mpesa_transactions.delivery_fee IS 'Delivery fee from order (matches orders.delivery_fee)';

-- ============================================
-- STEP 2: Create function to auto-populate transaction amounts from order
-- ============================================
CREATE OR REPLACE FUNCTION sync_order_amounts_to_mpesa()
RETURNS TRIGGER AS $$
DECLARE
  order_record RECORD;
BEGIN
  -- When order_id is set/updated, fetch order amounts
  IF NEW.order_id IS NOT NULL THEN
    SELECT 
      subtotal,
      delivery_fee,
      tax,
      total
    INTO order_record
    FROM public.orders
    WHERE id = NEW.order_id;
    
    IF FOUND THEN
      NEW.subtotal_amount := order_record.subtotal;
      NEW.delivery_fee := order_record.delivery_fee;
      NEW.tax_amount := order_record.tax;
      -- Ensure amount matches order total
      IF NEW.amount IS NULL OR NEW.amount = 0 THEN
        NEW.amount := order_record.total;
      END IF;
      
      RAISE NOTICE 'Synced amounts from order % to transaction: subtotal=%, tax=%, delivery=%, total=%',
        NEW.order_id, NEW.subtotal_amount, NEW.tax_amount, NEW.delivery_fee, NEW.amount;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- STEP 3: Create trigger to auto-sync amounts
-- ============================================
DROP TRIGGER IF EXISTS trg_sync_order_amounts_to_mpesa ON public.mpesa_transactions;
CREATE TRIGGER trg_sync_order_amounts_to_mpesa
  BEFORE INSERT OR UPDATE OF order_id ON public.mpesa_transactions
  FOR EACH ROW
  WHEN (NEW.order_id IS NOT NULL)
  EXECUTE FUNCTION sync_order_amounts_to_mpesa();

COMMENT ON FUNCTION sync_order_amounts_to_mpesa IS 
  'Auto-populates MPesa transaction amounts (subtotal, tax, delivery_fee) from linked order';

-- ============================================
-- STEP 4: Create comprehensive MPesa transactions view with tax
-- ============================================
CREATE OR REPLACE VIEW public.mpesa_transactions_detailed AS
SELECT 
  mt.id,
  mt.transaction_id,
  mt.merchant_request_id,
  mt.checkout_request_id,
  mt.transaction_timestamp,
  mt.amount as total_amount,
  mt.subtotal_amount,
  mt.delivery_fee,
  mt.tax_amount,
  (mt.tax_amount / NULLIF(mt.subtotal_amount, 0) * 100)::NUMERIC(5,2) as tax_rate_percentage,
  mt.phone_number,
  mt.account_reference,
  mt.transaction_desc,
  mt.transaction_type,
  mt.status,
  mt.result_code,
  mt.result_desc,
  mt.balance,
  mt.business_short_code,
  mt.invoice_number,
  mt.user_auth_id,
  mt.order_id,
  u.name as customer_name,
  u.email as customer_email,
  u.phone as customer_phone,
  o.short_id as order_short_id,
  o.status as order_status,
  o.order_type,
  mt.created_at,
  mt.updated_at
FROM public.mpesa_transactions mt
LEFT JOIN public.users u ON mt.user_auth_id = u.auth_id
LEFT JOIN public.orders o ON mt.order_id = o.id
ORDER BY mt.transaction_timestamp DESC;

COMMENT ON VIEW public.mpesa_transactions_detailed IS 
  'Comprehensive view of MPesa transactions with customer info, order details, and tax breakdown';

-- ============================================
-- STEP 5: Create MPesa daily summary view with tax breakdown
-- ============================================
CREATE OR REPLACE VIEW public.mpesa_daily_summary AS
SELECT 
  DATE(transaction_timestamp) as transaction_date,
  business_short_code,
  COUNT(*) as total_transactions,
  COUNT(*) FILTER (WHERE status = 'completed') as successful_transactions,
  COUNT(*) FILTER (WHERE status = 'failed') as failed_transactions,
  COUNT(*) FILTER (WHERE status = 'pending') as pending_transactions,
  
  -- Amount totals (only completed)
  COALESCE(SUM(amount) FILTER (WHERE status = 'completed'), 0) as total_revenue,
  COALESCE(SUM(subtotal_amount) FILTER (WHERE status = 'completed'), 0) as total_subtotal,
  COALESCE(SUM(tax_amount) FILTER (WHERE status = 'completed'), 0) as total_tax_collected,
  COALESCE(SUM(delivery_fee) FILTER (WHERE status = 'completed'), 0) as total_delivery_fees,
  
  -- Averages (only completed)
  COALESCE(ROUND(AVG(amount) FILTER (WHERE status = 'completed'), 2), 0) as avg_transaction_amount,
  COALESCE(ROUND(AVG(tax_amount) FILTER (WHERE status = 'completed'), 2), 0) as avg_tax_per_transaction,
  
  -- Tax rate (only completed with subtotal)
  COALESCE(
    ROUND(
      (SUM(tax_amount) FILTER (WHERE status = 'completed' AND subtotal_amount > 0) / 
       NULLIF(SUM(subtotal_amount) FILTER (WHERE status = 'completed' AND subtotal_amount > 0), 0) * 100
      )::NUMERIC, 2
    ), 0
  ) as effective_tax_rate_percentage,
  
  COUNT(DISTINCT phone_number) as unique_customers,
  COUNT(DISTINCT user_auth_id) FILTER (WHERE user_auth_id IS NOT NULL) as registered_users_count,
  COUNT(DISTINCT order_id) FILTER (WHERE order_id IS NOT NULL) as orders_linked
FROM public.mpesa_transactions 
GROUP BY DATE(transaction_timestamp), business_short_code
ORDER BY transaction_date DESC;

COMMENT ON VIEW public.mpesa_daily_summary IS 
  'Daily summary of MPesa transactions with tax breakdown and key metrics';

-- ============================================
-- STEP 6: Create MPesa monthly summary view
-- ============================================
CREATE OR REPLACE VIEW public.mpesa_monthly_summary AS
SELECT 
  DATE_TRUNC('month', transaction_timestamp)::DATE as month_start,
  TO_CHAR(transaction_timestamp, 'YYYY-MM') as year_month,
  business_short_code,
  
  COUNT(*) as total_transactions,
  COUNT(*) FILTER (WHERE status = 'completed') as successful_transactions,
  
  -- Revenue breakdown
  COALESCE(SUM(amount) FILTER (WHERE status = 'completed'), 0) as total_revenue,
  COALESCE(SUM(subtotal_amount) FILTER (WHERE status = 'completed'), 0) as meals_revenue,
  COALESCE(SUM(tax_amount) FILTER (WHERE status = 'completed'), 0) as tax_collected,
  COALESCE(SUM(delivery_fee) FILTER (WHERE status = 'completed'), 0) as delivery_revenue,
  
  -- Percentages
  COALESCE(
    ROUND(
      (SUM(tax_amount) FILTER (WHERE status = 'completed') / 
       NULLIF(SUM(amount) FILTER (WHERE status = 'completed'), 0) * 100
      )::NUMERIC, 2
    ), 0
  ) as tax_percentage_of_revenue,
  
  COALESCE(
    ROUND(
      (SUM(delivery_fee) FILTER (WHERE status = 'completed') / 
       NULLIF(SUM(amount) FILTER (WHERE status = 'completed'), 0) * 100
      )::NUMERIC, 2
    ), 0
  ) as delivery_percentage_of_revenue,
  
  -- Customer metrics
  COUNT(DISTINCT phone_number) as unique_customers,
  COUNT(DISTINCT order_id) FILTER (WHERE order_id IS NOT NULL) as orders_count
  
FROM public.mpesa_transactions 
GROUP BY DATE_TRUNC('month', transaction_timestamp), TO_CHAR(transaction_timestamp, 'YYYY-MM'), business_short_code
ORDER BY month_start DESC;

COMMENT ON VIEW public.mpesa_monthly_summary IS 
  'Monthly summary of MPesa transactions with revenue breakdown by category';

-- ============================================
-- STEP 7: Create function to calculate tax for an order
-- ============================================
CREATE OR REPLACE FUNCTION calculate_order_tax(
  p_subtotal NUMERIC,
  p_tax_rate NUMERIC DEFAULT 16.0
)
RETURNS NUMERIC AS $$
BEGIN
  -- Tax rate is percentage (e.g., 16 for 16%)
  -- Returns tax amount
  RETURN ROUND((p_subtotal * p_tax_rate / 100.0)::NUMERIC, 2);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION calculate_order_tax IS 
  'Calculates tax amount from subtotal and tax rate (defaults to 16% VAT)';

-- Example usage:
-- SELECT calculate_order_tax(1000); -- Returns 160 (16% of 1000)
-- SELECT calculate_order_tax(5000, 10); -- Returns 500 (10% of 5000)

-- ============================================
-- STEP 8: Create trigger to auto-calculate tax on orders table
-- ============================================
CREATE OR REPLACE FUNCTION auto_calculate_order_tax()
RETURNS TRIGGER AS $$
DECLARE
  tax_rate NUMERIC;
BEGIN
  -- Get active tax rate from tax_configurations
  SELECT t.tax_rate INTO tax_rate
  FROM public.tax_configurations t
  WHERE t.tax_name LIKE '%VAT%' 
    AND t.is_active = true
  ORDER BY t.id DESC
  LIMIT 1;
  
  -- Default to 16% if no tax config found
  IF tax_rate IS NULL THEN
    tax_rate := 16.0;
  END IF;
  
  -- Calculate tax from subtotal if not provided
  IF NEW.tax IS NULL OR NEW.tax = 0 THEN
    NEW.tax := ROUND((NEW.subtotal * tax_rate / 100.0)::NUMERIC, 2);
  END IF;
  
  -- Recalculate total
  NEW.total := NEW.subtotal + NEW.delivery_fee + NEW.tax;
  
  RAISE NOTICE 'Order tax calculated: subtotal=%, tax_rate=%, tax=%, total=%',
    NEW.subtotal, tax_rate, NEW.tax, NEW.total;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on orders (optional - only if you want automatic calculation)
-- Comment this out if you want to calculate tax in Flutter instead
/*
DROP TRIGGER IF EXISTS trg_auto_calculate_order_tax ON public.orders;
CREATE TRIGGER trg_auto_calculate_order_tax
  BEFORE INSERT OR UPDATE OF subtotal, delivery_fee ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION auto_calculate_order_tax();
*/

COMMENT ON FUNCTION auto_calculate_order_tax IS 
  'Auto-calculates order tax from subtotal using active VAT rate from tax_configurations';

-- ============================================
-- STEP 9: Update existing receipts to include tax breakdown
-- ============================================
-- Sync tax amounts from mpesa_transactions to receipts
UPDATE public.receipts r
SET tax_amount = mt.tax_amount
FROM public.mpesa_transactions mt
WHERE r.transaction_id = mt.transaction_id
  AND r.tax_amount = 0
  AND mt.tax_amount > 0;

-- ============================================
-- STEP 10: Create view combining orders and mpesa with tax
-- ============================================
CREATE OR REPLACE VIEW public.orders_with_payment_details AS
SELECT 
  o.id as order_id,
  o.short_id,
  o.user_auth_id,
  o.status as order_status,
  o.subtotal,
  o.delivery_fee,
  o.tax,
  o.total,
  o.order_type,
  o.placed_at,
  o.delivered_at,
  o.cancelled_at,
  
  -- MPesa transaction details
  mt.id as mpesa_id,
  mt.transaction_id,
  mt.transaction_timestamp,
  mt.amount as mpesa_amount,
  mt.tax_amount as mpesa_tax,
  mt.subtotal_amount as mpesa_subtotal,
  mt.delivery_fee as mpesa_delivery_fee,
  mt.phone_number,
  mt.status as payment_status,
  mt.result_desc as payment_result,
  
  -- Receipt details
  r.id as receipt_id,
  r.receipt_number,
  r.issue_date as receipt_date,
  
  -- User details
  u.name as customer_name,
  u.email as customer_email
  
FROM public.orders o
LEFT JOIN public.mpesa_transactions mt ON o.id = mt.order_id
LEFT JOIN public.receipts r ON mt.transaction_id = r.transaction_id
LEFT JOIN public.users u ON o.user_auth_id = u.auth_id
ORDER BY o.placed_at DESC;

COMMENT ON VIEW public.orders_with_payment_details IS 
  'Complete view of orders with MPesa payments and receipts, including tax breakdown';

-- ============================================
-- STEP 11: Create indexes for performance
-- ============================================
CREATE INDEX IF NOT EXISTS idx_mpesa_tax_amount ON public.mpesa_transactions(tax_amount)
  WHERE tax_amount > 0;

CREATE INDEX IF NOT EXISTS idx_mpesa_date_status ON public.mpesa_transactions(
  DATE(transaction_timestamp), status
) WHERE status = 'completed';

-- ============================================
-- STEP 12: Grant permissions for views
-- ============================================
GRANT SELECT ON public.mpesa_transactions_detailed TO authenticated;
GRANT SELECT ON public.mpesa_daily_summary TO authenticated;
GRANT SELECT ON public.mpesa_monthly_summary TO authenticated;
GRANT SELECT ON public.orders_with_payment_details TO authenticated;

-- ============================================
-- SUCCESS MESSAGE
-- ============================================
SELECT '✅ Tax Integration with MPesa Complete!

New Features:
✅ tax_amount, subtotal_amount, delivery_fee columns added to mpesa_transactions
✅ Auto-sync trigger: order amounts → mpesa_transactions
✅ Tax calculation function: calculate_order_tax(subtotal, rate)
✅ Optional auto-tax trigger for orders table (commented out)

New Views Created:
📊 mpesa_transactions_detailed - Full transaction details with tax
📊 mpesa_daily_summary - Daily metrics with tax breakdown
📊 mpesa_monthly_summary - Monthly revenue with tax percentages
📊 orders_with_payment_details - Orders + MPesa + Receipts unified

Usage Examples:

1. View today''s tax collection:
   SELECT transaction_date, total_tax_collected, effective_tax_rate_percentage
   FROM mpesa_daily_summary
   WHERE transaction_date = CURRENT_DATE;

2. View monthly tax trends:
   SELECT year_month, tax_collected, tax_percentage_of_revenue
   FROM mpesa_monthly_summary
   ORDER BY month_start DESC
   LIMIT 6;

3. Calculate tax for an order:
   SELECT calculate_order_tax(5000); -- 16% VAT = 800
   SELECT calculate_order_tax(10000, 10); -- 10% tax = 1000

4. View complete payment details:
   SELECT order_id, short_id, subtotal, tax, mpesa_tax, payment_status
   FROM orders_with_payment_details
   WHERE payment_status = ''completed''
   LIMIT 10;

Integration Points:
- When creating order: SET tax = calculate_order_tax(subtotal)
- When recording MPesa payment: SET order_id to auto-sync amounts
- Orders.tax → mpesa_transactions.tax_amount → receipts.tax_amount

Next Steps:
1. Update Flutter: OrderProvider to calculate tax before creating order
2. Update Flutter: MPesa callback to link order_id
3. Create admin screen: MPesa transactions dashboard
4. Update reports: Include tax breakdown
' AS status;
