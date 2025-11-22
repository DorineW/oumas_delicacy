# Test M-Pesa Callback Function
# This simulates what M-Pesa would send to your callback URL

Write-Host "🧪 Testing M-Pesa Callback Function..." -ForegroundColor Cyan
Write-Host ""

# Sample callback data (what M-Pesa sends on successful payment)
$callbackData = @{
    Body = @{
        stkCallback = @{
            MerchantRequestID = "282b-4e73-b92e-350b61bcdef01396"
            CheckoutRequestID = "ws_CO_18112025170834148700182990"
            ResultCode = 0
            ResultDesc = "The service request is processed successfully."
            CallbackMetadata = @{
                Item = @(
                    @{ Name = "Amount"; Value = 10 }
                    @{ Name = "MpesaReceiptNumber"; Value = "SKL9TEST123" }
                    @{ Name = "TransactionDate"; Value = 20241118170900 }
                    @{ Name = "PhoneNumber"; Value = 254700182990 }
                )
            }
        }
    }
} | ConvertTo-Json -Depth 10

Write-Host "📤 Sending callback to Supabase function..." -ForegroundColor Yellow
Write-Host $callbackData
Write-Host ""

$response = Invoke-RestMethod `
    -Uri "https://hqfixpqwxmwftvhgdrxn.supabase.co/functions/v1/mpesa-callback" `
    -Method Post `
    -Body $callbackData `
    -ContentType "application/json"

Write-Host "✅ Callback processed successfully!" -ForegroundColor Green
Write-Host "Response: $($response | ConvertTo-Json)"
Write-Host ""
Write-Host "🔍 Now check your database:" -ForegroundColor Cyan
Write-Host "SELECT * FROM mpesa_transactions WHERE checkout_request_id = 'ws_CO_18112025170834148700182990';"
