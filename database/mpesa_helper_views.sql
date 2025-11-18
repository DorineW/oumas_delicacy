-- ============================================
-- M-PESA HELPER VIEWS AND ANALYTICS
-- ============================================
-- Additional views for reporting and monitoring

-- ============================================
-- Transaction Status Overview
-- ============================================
CREATE OR REPLACE VIEW public.transaction_status_overview AS
SELECT 
    status,
    COUNT(*) as transaction_count,
    SUM(amount) as total_amount,
    ROUND(AVG(amount), 2) as average_amount,
    MIN(amount) as min_amount,
    MAX(amount) as max_amount,
    COUNT(DISTINCT phone_number) as unique_customers
FROM public.mpesa_transactions
GROUP BY status
ORDER BY transaction_count DESC;

COMMENT ON VIEW public.transaction_status_overview IS 
  'Overview of transaction counts and amounts grouped by status';

-- ============================================
-- Monthly Transaction Summary
-- ============================================
CREATE OR REPLACE VIEW public.monthly_transaction_summary AS
SELECT 
    DATE_TRUNC('month', transaction_timestamp) as month,
    COUNT(*) as total_transactions,
    SUM(amount) as total_amount,
    ROUND(AVG(amount), 2) as average_transaction,
    COUNT(DISTINCT phone_number) as unique_customers,
    COUNT(DISTINCT user_auth_id) as registered_users,
    business_short_code
FROM public.mpesa_transactions 
WHERE status = 'completed'
GROUP BY DATE_TRUNC('month', transaction_timestamp), business_short_code
ORDER BY month DESC;

COMMENT ON VIEW public.monthly_transaction_summary IS 
  'Monthly summary of completed M-Pesa transactions';

-- ============================================
-- Failed Transactions Report
-- ============================================
CREATE OR REPLACE VIEW public.failed_transactions_report AS
SELECT 
    transaction_id,
    phone_number,
    amount,
    transaction_timestamp,
    result_code,
    result_desc,
    merchant_request_id,
    checkout_request_id
FROM public.mpesa_transactions
WHERE status = 'failed'
ORDER BY transaction_timestamp DESC;

COMMENT ON VIEW public.failed_transactions_report IS 
  'List of all failed transactions for troubleshooting';

-- ============================================
-- Top Customers by Transaction Volume
-- ============================================
CREATE OR REPLACE VIEW public.top_customers_by_volume AS
SELECT 
    phone_number,
    COUNT(*) as transaction_count,
    SUM(amount) as total_spent,
    ROUND(AVG(amount), 2) as average_transaction,
    MIN(transaction_timestamp) as first_transaction,
    MAX(transaction_timestamp) as last_transaction
FROM public.mpesa_transactions
WHERE status = 'completed'
GROUP BY phone_number
ORDER BY total_spent DESC
LIMIT 100;

COMMENT ON VIEW public.top_customers_by_volume IS 
  'Top 100 customers by total transaction volume';

-- ============================================
-- Hourly Transaction Distribution
-- ============================================
CREATE OR REPLACE VIEW public.hourly_transaction_distribution AS
SELECT 
    EXTRACT(HOUR FROM transaction_timestamp) as hour_of_day,
    COUNT(*) as transaction_count,
    SUM(amount) as total_amount,
    ROUND(AVG(amount), 2) as average_amount
FROM public.mpesa_transactions
WHERE status = 'completed'
GROUP BY EXTRACT(HOUR FROM transaction_timestamp)
ORDER BY hour_of_day;

COMMENT ON VIEW public.hourly_transaction_distribution IS 
  'Transaction patterns by hour of day for business intelligence';

-- ============================================
-- Pending Transactions Monitor
-- ============================================
CREATE OR REPLACE VIEW public.pending_transactions_monitor AS
SELECT 
    transaction_id,
    phone_number,
    amount,
    transaction_timestamp,
    checkout_request_id,
    EXTRACT(EPOCH FROM (NOW() - transaction_timestamp))/60 as minutes_pending,
    order_id
FROM public.mpesa_transactions
WHERE status = 'pending'
ORDER BY transaction_timestamp ASC;

COMMENT ON VIEW public.pending_transactions_monitor IS 
  'Monitor transactions stuck in pending status with time elapsed';

-- ============================================
-- Receipt Generation Status
-- ============================================
CREATE OR REPLACE VIEW public.receipt_generation_status AS
SELECT 
    mt.transaction_id,
    mt.amount,
    mt.transaction_timestamp,
    mt.status as transaction_status,
    CASE 
        WHEN r.id IS NOT NULL THEN 'Generated'
        ELSE 'Missing'
    END as receipt_status,
    r.receipt_number,
    r.is_printed,
    COALESCE(
        (SELECT COUNT(*) FROM public.receipt_items WHERE receipt_id = r.id),
        0
    ) as item_count
FROM public.mpesa_transactions mt
LEFT JOIN public.receipts r ON mt.transaction_id = r.transaction_id
WHERE mt.status = 'completed'
ORDER BY mt.transaction_timestamp DESC;

COMMENT ON VIEW public.receipt_generation_status IS 
  'Track which completed transactions have receipts generated';

-- ============================================
-- Daily Revenue Summary
-- ============================================
CREATE OR REPLACE VIEW public.daily_revenue_summary AS
SELECT 
    DATE(transaction_timestamp) as transaction_date,
    COUNT(*) as total_transactions,
    SUM(amount) as gross_revenue,
    SUM(COALESCE(
        (SELECT SUM(fee_amount) 
         FROM public.transaction_fees 
         WHERE transaction_id = mpesa_transactions.transaction_id),
        0
    )) as total_fees,
    SUM(amount) - SUM(COALESCE(
        (SELECT SUM(fee_amount) 
         FROM public.transaction_fees 
         WHERE transaction_id = mpesa_transactions.transaction_id),
        0
    )) as net_revenue,
    COUNT(DISTINCT phone_number) as unique_customers,
    business_short_code
FROM public.mpesa_transactions 
WHERE status = 'completed'
GROUP BY DATE(transaction_timestamp), business_short_code
ORDER BY transaction_date DESC;

COMMENT ON VIEW public.daily_revenue_summary IS 
  'Daily revenue summary including fees and net revenue calculations';

-- ============================================
-- Reconciliation Dashboard
-- ============================================
CREATE OR REPLACE VIEW public.reconciliation_dashboard AS
SELECT 
    DATE(pr.reconciliation_date) as date,
    COUNT(*) as reconciliations_done,
    SUM(CASE WHEN pr.reconciliation_status = 'matched' THEN 1 ELSE 0 END) as matched_count,
    SUM(CASE WHEN pr.reconciliation_status = 'discrepancy' THEN 1 ELSE 0 END) as discrepancy_count,
    SUM(CASE WHEN pr.reconciliation_status = 'pending' THEN 1 ELSE 0 END) as pending_count,
    SUM(pr.expected_amount) as total_expected,
    SUM(pr.received_amount) as total_received,
    SUM(pr.difference_amount) as total_difference,
    SUM(pr.mpesa_charges) as total_charges,
    SUM(pr.net_amount) as total_net
FROM public.payment_reconciliations pr
GROUP BY DATE(pr.reconciliation_date)
ORDER BY date DESC;

COMMENT ON VIEW public.reconciliation_dashboard IS 
  'Daily reconciliation summary showing matches, discrepancies, and amounts';

-- ============================================
-- Success Message
-- ============================================
SELECT 'M-Pesa Helper Views Created Successfully! 🎉

Available Views:
✅ transaction_status_overview - Status breakdown with counts and amounts
✅ monthly_transaction_summary - Monthly aggregated metrics
✅ failed_transactions_report - Failed transactions for debugging
✅ top_customers_by_volume - Top 100 customers by spending
✅ hourly_transaction_distribution - Transaction patterns by hour
✅ pending_transactions_monitor - Track stuck/pending payments
✅ receipt_generation_status - Verify receipt creation
✅ daily_revenue_summary - Daily revenue with fees and net amounts
✅ reconciliation_dashboard - Reconciliation tracking

Usage Examples:
-- View transaction status breakdown
SELECT * FROM public.transaction_status_overview;

-- Check monthly performance
SELECT * FROM public.monthly_transaction_summary WHERE month >= DATE_TRUNC(''month'', NOW() - INTERVAL ''6 months'');

-- Monitor pending transactions
SELECT * FROM public.pending_transactions_monitor WHERE minutes_pending > 5;

-- Daily revenue for current month
SELECT * FROM public.daily_revenue_summary WHERE transaction_date >= DATE_TRUNC(''month'', NOW());
' AS status;
