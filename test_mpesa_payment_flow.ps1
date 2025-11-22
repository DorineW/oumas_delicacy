# M-Pesa Payment Testing Script with Polling
# This demonstrates how the payment flow works in sandbox

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║      M-PESA PAYMENT TEST (Polling Method - Sandbox)     ║" -ForegroundColor Cyan  
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Configuration
$apiKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhxZml4cHF3eG13ZnR2aGdkcnhuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE2Mzc4NTksImV4cCI6MjA3NzIxMzg1OX0.Mjgws9SddAbTYmZotPNRKf-Yz3DmzkzJRxdstXBx6Zs"
$baseUrl = "https://hqfixpqwxmwftvhgdrxn.supabase.co/functions/v1"

# Get phone number from user
$phoneNumber = Read-Host "Enter your M-Pesa phone number (e.g., 0700123456)"
$amount = Read-Host "Enter amount in KSh (e.g., 1)"

Write-Host ""
Write-Host "📱 STEP 1: Initiating STK Push..." -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

$pushBody = @{
    phoneNumber = $phoneNumber
    amount = [int]$amount
    accountReference = "TEST-$(Get-Date -Format 'HHmmss')"
    transactionDesc = "Test Payment - Polling Method"
} | ConvertTo-Json

try {
    $pushResponse = Invoke-RestMethod `
        -Uri "$baseUrl/mpesa-stk-push" `
        -Method Post `
        -Body $pushBody `
        -ContentType "application/json" `
        -Headers @{ 'Authorization' = "Bearer $apiKey" }
    
    Write-Host "✅ STK Push Sent Successfully!" -ForegroundColor Green
    Write-Host "   Checkout ID: $($pushResponse.checkoutRequestId)" -ForegroundColor White
    Write-Host "   Transaction ID: $($pushResponse.transactionId)" -ForegroundColor White
    Write-Host ""
    
    $checkoutId = $pushResponse.checkoutRequestId
    
} catch {
    Write-Host "❌ Failed to send STK push" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "📱 Check your phone for the M-Pesa prompt and enter your PIN" -ForegroundColor Cyan
Write-Host ""
Write-Host "🔄 STEP 2: Polling M-Pesa for payment status..." -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "   (Checking every 5 seconds for up to 1 minute)" -ForegroundColor DarkGray
Write-Host ""

$maxAttempts = 12
$attemptCount = 0
$finalStatus = $null

while ($attemptCount -lt $maxAttempts) {
    $attemptCount++
    Start-Sleep -Seconds 5
    
    Write-Host "   [$attemptCount/$maxAttempts] Checking status..." -ForegroundColor Cyan -NoNewline
    
    $queryBody = @{
        checkoutRequestId = $checkoutId
    } | ConvertTo-Json
    
    try {
        $queryResponse = Invoke-RestMethod `
            -Uri "$baseUrl/mpesa-query-status" `
            -Method Post `
            -Body $queryBody `
            -ContentType "application/json" `
            -Headers @{ 'Authorization' = "Bearer $apiKey" }
        
        $status = $queryResponse.status
        $resultCode = $queryResponse.resultCode
        
        if ($status -eq 'completed') {
            Write-Host " ✅ PAID!" -ForegroundColor Green
            $finalStatus = $queryResponse
            break
        } elseif ($status -eq 'failed') {
            Write-Host " ❌ FAILED" -ForegroundColor Red
            $finalStatus = $queryResponse
            break
        } elseif ($status -eq 'cancelled') {
            Write-Host " ⚠️ CANCELLED" -ForegroundColor Yellow
            $finalStatus = $queryResponse
            break
        } else {
            Write-Host " ⏳ Pending..." -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host " ⚠️ Query error" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

if ($finalStatus) {
    Write-Host ""
    Write-Host "🎉 FINAL RESULT" -ForegroundColor Green
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host "Status:      " -NoNewline
    if ($finalStatus.status -eq 'completed') {
        Write-Host "$($finalStatus.status)" -ForegroundColor Green
    } else {
        Write-Host "$($finalStatus.status)" -ForegroundColor Red
    }
    Write-Host "Result Code: $($finalStatus.resultCode)"
    Write-Host "Description: $($finalStatus.resultDesc)"
    Write-Host ""
    Write-Host "✅ Database updated successfully!" -ForegroundColor Green
    Write-Host "   The transaction status has been recorded in your database." -ForegroundColor White
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "⏱️ TIMEOUT" -ForegroundColor Yellow
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host "The payment is still pending after 1 minute." -ForegroundColor Yellow
    Write-Host "You can check the status later in the database." -ForegroundColor White
    Write-Host ""
}

Write-Host "📊 To view transaction in database, run:" -ForegroundColor Cyan
Write-Host "   SELECT * FROM mpesa_transactions WHERE checkout_request_id = '$checkoutId';" -ForegroundColor White
Write-Host ""
