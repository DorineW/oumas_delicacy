-- ============================================
-- MIGRATE TO M-PESA TRANSACTION TABLES
-- ============================================
-- Replaces payment_methods table with dedicated M-Pesa transaction tracking
-- Adapted for PostgreSQL and Supabase with existing schema

-- ============================================
-- STEP 1: Drop old payment_methods table
-- ============================================
DROP TABLE IF EXISTS public.payment_methods CASCADE;

-- ============================================
-- STEP 2: Create M-Pesa Transactions Table
-- ============================================
CREATE TABLE IF NOT EXISTS public.mpesa_transactions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id VARCHAR(50) UNIQUE NOT NULL,
    merchant_request_id VARCHAR(50),
    checkout_request_id VARCHAR(50),
    transaction_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    amount NUMERIC(15,2) NOT NULL, -- Amount in KES (using numeric for precise money handling)
    phone_number VARCHAR(20) NOT NULL,
    account_reference VARCHAR(100),
    transaction_desc TEXT,
    transaction_type VARCHAR(20) NOT NULL CHECK (transaction_type IN ('payment', 'withdrawal', 'reversal')),
    status VARCHAR(20) NOT NULL CHECK (status IN ('completed', 'pending', 'failed', 'cancelled')),
    result_code INTEGER,
    result_desc VARCHAR(255),
    balance NUMERIC(15,2), -- Balance in KES
    business_short_code VARCHAR(20) NOT NULL,
    invoice_number VARCHAR(100),
    user_auth_id uuid REFERENCES public.users(auth_id), -- Link to user who made payment
    order_id uuid REFERENCES public.orders(id), -- Link to order if applicable
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Indexes for mpesa_transactions
CREATE INDEX IF NOT EXISTS idx_mpesa_transactions_timestamp ON public.mpesa_transactions(transaction_timestamp);
CREATE INDEX IF NOT EXISTS idx_mpesa_transactions_phone ON public.mpesa_transactions(phone_number);
CREATE INDEX IF NOT EXISTS idx_mpesa_transactions_status ON public.mpesa_transactions(status);
CREATE INDEX IF NOT EXISTS idx_mpesa_transactions_checkout_request ON public.mpesa_transactions(checkout_request_id);
CREATE INDEX IF NOT EXISTS idx_mpesa_transactions_user ON public.mpesa_transactions(user_auth_id);
CREATE INDEX IF NOT EXISTS idx_mpesa_transactions_order ON public.mpesa_transactions(order_id);

COMMENT ON TABLE public.mpesa_transactions IS 
  'Stores all M-Pesa transaction records including STK push payments, callbacks, and transaction statuses';

-- ============================================
-- STEP 3: Create Receipts Master Table
-- ============================================
CREATE TABLE IF NOT EXISTS public.receipts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    receipt_number VARCHAR(100) UNIQUE NOT NULL,
    transaction_id VARCHAR(50) NOT NULL REFERENCES public.mpesa_transactions(transaction_id),
    receipt_type VARCHAR(20) NOT NULL CHECK (receipt_type IN ('payment', 'refund', 'reversal')),
    issue_date TIMESTAMP WITH TIME ZONE NOT NULL,
    customer_name VARCHAR(255),
    customer_phone VARCHAR(20),
    customer_email VARCHAR(255),
    subtotal NUMERIC(15,2) NOT NULL, -- Amount in KES
    tax_amount NUMERIC(15,2) DEFAULT 0,
    discount_amount NUMERIC(15,2) DEFAULT 0,
    total_amount NUMERIC(15,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'KES',
    payment_method VARCHAR(50) DEFAULT 'M-Pesa',
    business_name VARCHAR(255) NOT NULL,
    business_address TEXT,
    business_phone VARCHAR(20),
    business_email VARCHAR(255),
    tax_identification VARCHAR(100),
    notes TEXT,
    qr_code_data TEXT,
    is_printed BOOLEAN DEFAULT FALSE,
    printed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Indexes for receipts
CREATE INDEX IF NOT EXISTS idx_receipts_transaction ON public.receipts(transaction_id);
CREATE INDEX IF NOT EXISTS idx_receipts_number ON public.receipts(receipt_number);
CREATE INDEX IF NOT EXISTS idx_receipts_issue_date ON public.receipts(issue_date);

COMMENT ON TABLE public.receipts IS 
  'Stores receipt information for M-Pesa transactions with full business and customer details';

-- ============================================
-- STEP 4: Create Receipt Line Items Table
-- ============================================
CREATE TABLE IF NOT EXISTS public.receipt_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    receipt_id uuid NOT NULL REFERENCES public.receipts(id) ON DELETE CASCADE,
    item_description VARCHAR(255) NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price NUMERIC(15,2) NOT NULL, -- Price in KES
    total_price NUMERIC(15,2) NOT NULL,
    tax_rate NUMERIC(5,2) DEFAULT 0,
    tax_amount NUMERIC(15,2) DEFAULT 0,
    discount_rate NUMERIC(5,2) DEFAULT 0,
    discount_amount NUMERIC(15,2) DEFAULT 0,
    item_code VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Indexes for receipt_items
CREATE INDEX IF NOT EXISTS idx_receipt_items_receipt ON public.receipt_items(receipt_id);

COMMENT ON TABLE public.receipt_items IS 
  'Line items for each receipt showing individual products/services purchased';

-- ============================================
-- STEP 5: Create Tax Configuration Table
-- ============================================
CREATE TABLE IF NOT EXISTS public.tax_configurations (
    id SERIAL PRIMARY KEY,
    tax_name VARCHAR(100) NOT NULL,
    tax_rate NUMERIC(5,2) NOT NULL,
    tax_type VARCHAR(20) NOT NULL CHECK (tax_type IN ('percentage', 'fixed')),
    is_active BOOLEAN DEFAULT TRUE,
    applies_to VARCHAR(20) DEFAULT 'all' CHECK (applies_to IN ('all', 'specific_items')),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.tax_configurations IS 
  'Configuration for different tax types (VAT, service charge, etc.)';

-- ============================================
-- STEP 6: Create Payment Reconciliation Table
-- ============================================
CREATE TABLE IF NOT EXISTS public.payment_reconciliations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id VARCHAR(50) NOT NULL REFERENCES public.mpesa_transactions(transaction_id),
    reconciliation_date DATE NOT NULL,
    expected_amount NUMERIC(15,2) NOT NULL,
    received_amount NUMERIC(15,2) NOT NULL,
    difference_amount NUMERIC(15,2),
    reconciliation_status VARCHAR(20) NOT NULL CHECK (reconciliation_status IN ('matched', 'discrepancy', 'pending')),
    mpesa_charges NUMERIC(15,2) DEFAULT 0,
    net_amount NUMERIC(15,2) NOT NULL,
    reconciled_by VARCHAR(100),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Index for reconciliations
CREATE INDEX IF NOT EXISTS idx_reconciliations_transaction ON public.payment_reconciliations(transaction_id);
CREATE INDEX IF NOT EXISTS idx_reconciliations_date ON public.payment_reconciliations(reconciliation_date);
CREATE INDEX IF NOT EXISTS idx_reconciliations_status ON public.payment_reconciliations(reconciliation_status);

COMMENT ON TABLE public.payment_reconciliations IS 
  'Tracks reconciliation between expected and received M-Pesa payments';

-- ============================================
-- STEP 7: Create Transaction Fees Table
-- ============================================
CREATE TABLE IF NOT EXISTS public.transaction_fees (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id VARCHAR(50) NOT NULL REFERENCES public.mpesa_transactions(transaction_id),
    fee_type VARCHAR(100) NOT NULL,
    fee_amount NUMERIC(15,2) NOT NULL, -- Fee in KES
    fee_calculation_method VARCHAR(100),
    calculated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Index for transaction fees
CREATE INDEX IF NOT EXISTS idx_transaction_fees_transaction ON public.transaction_fees(transaction_id);

COMMENT ON TABLE public.transaction_fees IS 
  'Stores M-Pesa transaction fees and charges breakdown';

-- ============================================
-- STEP 8: Create Receipt Templates Table
-- ============================================
CREATE TABLE IF NOT EXISTS public.receipt_templates (
    id SERIAL PRIMARY KEY,
    template_name VARCHAR(100) NOT NULL,
    template_type VARCHAR(20) NOT NULL CHECK (template_type IN ('thermal', 'a4', 'email')),
    header_html TEXT,
    body_html TEXT,
    footer_html TEXT,
    css_styles TEXT,
    logo_url VARCHAR(500),
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.receipt_templates IS 
  'HTML templates for generating receipts in different formats';

-- ============================================
-- STEP 9: Create Daily Transaction Summary View
-- ============================================
CREATE OR REPLACE VIEW public.daily_transaction_summary AS
SELECT 
    DATE(transaction_timestamp) as transaction_date,
    COUNT(*) as total_transactions,
    SUM(amount) as total_amount,
    ROUND(AVG(amount)) as average_transaction,
    COUNT(DISTINCT phone_number) as unique_customers,
    business_short_code
FROM public.mpesa_transactions 
WHERE status = 'completed'
GROUP BY DATE(transaction_timestamp), business_short_code;

COMMENT ON VIEW public.daily_transaction_summary IS 
  'Daily summary of M-Pesa transactions for reporting and analytics';

-- ============================================
-- STEP 10: Create updated_at trigger for mpesa_transactions
-- ============================================
CREATE OR REPLACE FUNCTION update_mpesa_transactions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_mpesa_transactions_updated_at ON public.mpesa_transactions;
CREATE TRIGGER trg_mpesa_transactions_updated_at
    BEFORE UPDATE ON public.mpesa_transactions
    FOR EACH ROW
    EXECUTE FUNCTION update_mpesa_transactions_updated_at();

-- ============================================
-- STEP 11: RLS Policies for M-Pesa Transactions
-- ============================================
ALTER TABLE public.mpesa_transactions ENABLE ROW LEVEL SECURITY;

-- Users can view their own transactions
DROP POLICY IF EXISTS "Users view own mpesa transactions" ON public.mpesa_transactions;
CREATE POLICY "Users view own mpesa transactions"
    ON public.mpesa_transactions
    FOR SELECT
    TO authenticated
    USING (user_auth_id = auth.uid());

-- Admins can view all transactions
DROP POLICY IF EXISTS "Admins view all mpesa transactions" ON public.mpesa_transactions;
CREATE POLICY "Admins view all mpesa transactions"
    ON public.mpesa_transactions
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE users.auth_id = auth.uid()
            AND users.role = 'admin'
        )
    );

-- Backend/service can insert transactions
DROP POLICY IF EXISTS "Service insert mpesa transactions" ON public.mpesa_transactions;
CREATE POLICY "Service insert mpesa transactions"
    ON public.mpesa_transactions
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- Backend/service can update transactions
DROP POLICY IF EXISTS "Service update mpesa transactions" ON public.mpesa_transactions;
CREATE POLICY "Service update mpesa transactions"
    ON public.mpesa_transactions
    FOR UPDATE
    TO authenticated
    USING (true);

-- ============================================
-- STEP 12: RLS Policies for Receipts
-- ============================================
ALTER TABLE public.receipts ENABLE ROW LEVEL SECURITY;

-- Users can view receipts for their transactions
DROP POLICY IF EXISTS "Users view own receipts" ON public.receipts;
CREATE POLICY "Users view own receipts"
    ON public.receipts
    FOR SELECT
    TO authenticated
    USING (
        transaction_id IN (
            SELECT transaction_id FROM public.mpesa_transactions
            WHERE user_auth_id = auth.uid()
        )
    );

-- Admins can view all receipts
DROP POLICY IF EXISTS "Admins view all receipts" ON public.receipts;
CREATE POLICY "Admins view all receipts"
    ON public.receipts
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE users.auth_id = auth.uid()
            AND users.role = 'admin'
        )
    );

-- Service can insert receipts
DROP POLICY IF EXISTS "Service insert receipts" ON public.receipts;
CREATE POLICY "Service insert receipts"
    ON public.receipts
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- ============================================
-- STEP 13: RLS Policies for Receipt Items
-- ============================================
ALTER TABLE public.receipt_items ENABLE ROW LEVEL SECURITY;

-- Users can view receipt items for their receipts
DROP POLICY IF EXISTS "Users view own receipt items" ON public.receipt_items;
CREATE POLICY "Users view own receipt items"
    ON public.receipt_items
    FOR SELECT
    TO authenticated
    USING (
        receipt_id IN (
            SELECT r.id FROM public.receipts r
            JOIN public.mpesa_transactions mt ON r.transaction_id = mt.transaction_id
            WHERE mt.user_auth_id = auth.uid()
        )
    );

-- Admins can view all receipt items
DROP POLICY IF EXISTS "Admins view all receipt items" ON public.receipt_items;
CREATE POLICY "Admins view all receipt items"
    ON public.receipt_items
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE users.auth_id = auth.uid()
            AND users.role = 'admin'
        )
    );

-- Service can insert receipt items
DROP POLICY IF EXISTS "Service insert receipt items" ON public.receipt_items;
CREATE POLICY "Service insert receipt items"
    ON public.receipt_items
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- ============================================
-- STEP 14: Helper function to generate receipt number
-- ============================================
-- Create sequence for receipt numbers first
CREATE SEQUENCE IF NOT EXISTS receipt_number_seq START 1;

-- Then create the function that uses it
CREATE OR REPLACE FUNCTION generate_receipt_number()
RETURNS VARCHAR(100) AS $$
DECLARE
    receipt_num VARCHAR(100);
BEGIN
    receipt_num := 'RCP-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(NEXTVAL('receipt_number_seq')::TEXT, 6, '0');
    RETURN receipt_num;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- STEP 15: Insert default tax configuration
-- ============================================
INSERT INTO public.tax_configurations (tax_name, tax_rate, tax_type, is_active, applies_to)
VALUES 
    ('VAT (16%)', 16.00, 'percentage', true, 'all'),
    ('Service Charge', 0.00, 'percentage', false, 'all')
ON CONFLICT DO NOTHING;

-- ============================================
-- SUCCESS MESSAGE
-- ============================================
SELECT 'M-Pesa transaction tables migration complete!

New Tables Created:
✅ mpesa_transactions - Main M-Pesa transaction records
✅ receipts - Receipt master records
✅ receipt_items - Line items for each receipt
✅ tax_configurations - Tax setup
✅ payment_reconciliations - Payment reconciliation tracking
✅ transaction_fees - M-Pesa fee breakdown
✅ receipt_templates - Receipt HTML templates

Key Features:
✅ Links transactions to users (user_auth_id)
✅ Links transactions to orders (order_id)
✅ Row Level Security (RLS) enabled
✅ Users can only see their own transactions/receipts
✅ Admins can see all records
✅ Automatic updated_at timestamps
✅ Daily transaction summary view
✅ Receipt number generation function

Usage:
1. Record M-Pesa transaction: INSERT INTO mpesa_transactions
2. Generate receipt: INSERT INTO receipts (use generate_receipt_number())
3. Add receipt items: INSERT INTO receipt_items
4. View daily summary: SELECT * FROM daily_transaction_summary
5. Reconcile payments: INSERT INTO payment_reconciliations

Integration Points:
- mpesa_transactions.user_auth_id → public.users(auth_id)
- mpesa_transactions.order_id → public.orders(id)
- receipts.transaction_id → mpesa_transactions(transaction_id)
- receipt_items.receipt_id → receipts(id)

Next Steps:
1. Update backend to use mpesa_transactions instead of payment_methods
2. Create Edge Function to auto-generate receipts on successful payment
3. Update M-Pesa callback handler to insert into mpesa_transactions
4. Set up reconciliation process for daily settlements
' AS status;
