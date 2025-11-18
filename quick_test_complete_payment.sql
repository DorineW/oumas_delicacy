-- Quick test: Manually complete the most recent pending transaction
UPDATE mpesa_transactions
SET 
    status = 'completed',
    mpesa_receipt_number = 'TEST' || FLOOR(RANDOM() * 1000000000)::TEXT,
    result_code = '0',
    result_desc = 'Test: The service request is processed successfully.',
    updated_at = NOW()
WHERE id = (
    SELECT id 
    FROM mpesa_transactions 
    WHERE status = 'pending' 
    ORDER BY created_at DESC 
    LIMIT 1
)
RETURNING *;
