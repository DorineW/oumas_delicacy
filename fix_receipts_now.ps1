# Create missing receipts immediately
$url = "https://hqfixpqwxmwftvhgdrxn.supabase.co/rest/v1/rpc/create_missing_receipt"
$anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhxZml4cHF3eG13ZnR2aGdkcnhuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzEzMDk3MzksImV4cCI6MjA0Njg4NTczOX0.m9EAW0yY8cwVrJwMfRVJ7BLABYGLUUOiPFm7EYc1M0w"

# First create the function if it doesn't exist
$createFunctionSQL = @"
CREATE OR REPLACE FUNCTION create_receipt_for_transaction(p_transaction_id VARCHAR)
RETURNS VARCHAR AS `$`$
DECLARE
    v_receipt_number VARCHAR;
    v_receipt_id UUID;
    v_transaction_record RECORD;
    v_order_record RECORD;
BEGIN
    -- Get transaction details
    SELECT * INTO v_transaction_record
    FROM mpesa_transactions
    WHERE transaction_id = p_transaction_id;
    
    IF NOT FOUND THEN
        RETURN 'Transaction not found: ' || p_transaction_id;
    END IF;
    
    -- Check if receipt already exists
    IF EXISTS (SELECT 1 FROM receipts WHERE transaction_id = p_transaction_id) THEN
        RETURN 'Receipt already exists for: ' || p_transaction_id;
    END IF;
    
    -- Get order details
    SELECT * INTO v_order_record
    FROM orders
    WHERE id = v_transaction_record.order_id;
    
    -- Generate receipt number
    v_receipt_number := generate_receipt_number();
    v_receipt_id := gen_random_uuid();
    
    -- Insert receipt
    INSERT INTO receipts (
        id,
        receipt_number,
        transaction_id,
        issue_date,
        customer_name,
        customer_phone,
        subtotal,
        tax_amount,
        discount_amount,
        total_amount,
        payment_method,
        currency
    ) VALUES (
        v_receipt_id,
        v_receipt_number,
        v_transaction_record.transaction_id,
        COALESCE(v_transaction_record.created_at, NOW()),
        v_transaction_record.customer_name,
        v_transaction_record.phone_number,
        v_order_record.total_amount,
        0,
        0,
        v_transaction_record.amount,
        'M-Pesa',
        'KES'
    );
    
    -- Insert receipt items from order
    INSERT INTO receipt_items (
        id,
        receipt_id,
        item_description,
        quantity,
        unit_price,
        total_price
    )
    SELECT 
        gen_random_uuid(),
        v_receipt_id,
        oi.name,
        oi.quantity,
        oi.price,
        oi.quantity * oi.price
    FROM order_items oi
    WHERE oi.order_id = v_order_record.id;
    
    RETURN 'Receipt created: ' || v_receipt_number;
END;
`$`$ LANGUAGE plpgsql SECURITY DEFINER;
"@

Write-Host "Creating receipt generation function..." -ForegroundColor Cyan
$createHeaders = @{
    "apikey" = $anonKey
    "Authorization" = "Bearer $anonKey"
    "Content-Type" = "application/json"
}

try {
    $response = Invoke-RestMethod -Uri "https://hqfixpqwxmwftvhgdrxn.supabase.co/rest/v1/rpc/exec_sql" -Method Post -Headers $createHeaders -Body (@{ sql = $createFunctionSQL } | ConvertTo-Json)
    Write-Host "Function created" -ForegroundColor Green
} catch {
    Write-Host "Note: Function may already exist" -ForegroundColor Yellow
}

# Now create the missing receipt
Write-Host "`nCreating receipt for TXN-1763753984913-1yzv6xm..." -ForegroundColor Cyan

$body = @{
    transaction_id = "TXN-1763753984913-1yzv6xm"
} | ConvertTo-Json

try {
    $result = Invoke-RestMethod -Uri "$url/create_receipt_for_transaction" -Method Post -Headers $createHeaders -Body $body
    Write-Host "Success: $result" -ForegroundColor Green
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "Creating directly via INSERT..." -ForegroundColor Yellow
    
    # Fallback: Create directly
    $insertSQL = @"
DO `$`$
DECLARE
    v_receipt_number VARCHAR;
    v_receipt_id UUID;
BEGIN
    v_receipt_number := generate_receipt_number();
    v_receipt_id := gen_random_uuid();
    
    INSERT INTO receipts (id, receipt_number, transaction_id, issue_date, customer_name, customer_phone, subtotal, tax_amount, discount_amount, total_amount, payment_method, currency)
    SELECT v_receipt_id, v_receipt_number, mt.transaction_id, mt.created_at, mt.customer_name, mt.phone_number, o.total_amount, 0, 0, mt.amount, 'M-Pesa', 'KES'
    FROM mpesa_transactions mt
    JOIN orders o ON mt.order_id = o.id
    WHERE mt.transaction_id = 'TXN-1763753984913-1yzv6xm';
    
    INSERT INTO receipt_items (id, receipt_id, item_description, quantity, unit_price, total_price)
    SELECT gen_random_uuid(), v_receipt_id, oi.name, oi.quantity, oi.price, oi.quantity * oi.price
    FROM mpesa_transactions mt
    JOIN order_items oi ON oi.order_id = mt.order_id
    WHERE mt.transaction_id = 'TXN-1763753984913-1yzv6xm';
    
    RAISE NOTICE 'Receipt created: %', v_receipt_number;
END;
`$`$;
"@
    
    Write-Host "SQL: $insertSQL"
}

Write-Host "`nDone! Try viewing the receipt now." -ForegroundColor Green
