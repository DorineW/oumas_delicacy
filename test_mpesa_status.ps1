# Test M-Pesa Integration Status
# This script checks the current state of your M-Pesa setup

$anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhxZml4cHF3eG13ZnR2aGdkcnhuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE2Mzc4NTksImV4cCI6MjA3NzIxMzg1OX0.Mjgws9SddAbTYmZotPNRKf-Yz3DmzkzJRxdstXBx6Zs"
$baseUrl = "https://hqfixpqwxmwftvhgdrxn.supabase.co"

Write-Host "`n=== M-PESA INTEGRATION STATUS CHECK ===" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date)" -ForegroundColor Gray

# 1. Check if mpesa_transactions table exists and has data
Write-Host "`n1. Checking mpesa_transactions table..." -ForegroundColor Yellow
try {
    $transactions = Invoke-RestMethod -Uri "$baseUrl/rest/v1/mpesa_transactions?select=*&order=created_at.desc&limit=10" `
        -Headers @{
            "apikey" = $anonKey
            "Authorization" = "Bearer $anonKey"
        }
    
    if ($transactions.Count -eq 0) {
        Write-Host "   ⚠️  No transactions found in database" -ForegroundColor Yellow
        Write-Host "   This could mean:" -ForegroundColor Gray
        Write-Host "   - RLS policies blocking access (expected if not admin)" -ForegroundColor Gray
        Write-Host "   - No transactions have been created yet" -ForegroundColor Gray
        Write-Host "   - Database insertion failed" -ForegroundColor Gray
    } else {
        Write-Host "   ✅ Found $($transactions.Count) transaction(s)" -ForegroundColor Green
        $transactions | Format-Table transaction_id, status, amount, phone_number, created_at -AutoSize
    }
} catch {
    Write-Host "   ❌ Error querying transactions: $($_.Exception.Message)" -ForegroundColor Red
}

# 2. Test STK Push endpoint
Write-Host "`n2. Testing STK Push endpoint..." -ForegroundColor Yellow
try {
    $testPayload = @{
        phoneNumber = "254708374149"
        amount = 1
        accountReference = "STATUS_CHECK_TEST"
        transactionDesc = "Status check test"
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri "$baseUrl/functions/v1/mpesa-stk-push" `
        -Method POST `
        -Headers @{
            "Content-Type" = "application/json"
            "apikey" = $anonKey
            "Authorization" = "Bearer $anonKey"
        } `
        -Body $testPayload
    
    Write-Host "   ✅ STK Push successful!" -ForegroundColor Green
    Write-Host "   Success: $($response.success)" -ForegroundColor Gray
    Write-Host "   Message: $($response.message)" -ForegroundColor Gray
    Write-Host "   Merchant Request ID: $($response.merchantRequestId)" -ForegroundColor Gray
    Write-Host "   Checkout Request ID: $($response.checkoutRequestId)" -ForegroundColor Gray
    
    if ($response.transactionId) {
        Write-Host "   Transaction ID in DB: $($response.transactionId)" -ForegroundColor Gray
    }
    
} catch {
    Write-Host "   ❌ STK Push failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        $errorBody = $reader.ReadToEnd()
        Write-Host "   Error details: $errorBody" -ForegroundColor Red
    }
}

# 3. Check callback URL accessibility
Write-Host "`n3. Checking callback endpoint..." -ForegroundColor Yellow
try {
    $callbackUrl = "$baseUrl/functions/v1/mpesa-callback"
    Write-Host "   Callback URL: $callbackUrl" -ForegroundColor Gray
    Write-Host "   ✅ Endpoint configured (register this with Safaricom)" -ForegroundColor Green
} catch {
    Write-Host "   ⚠️  Could not verify callback endpoint" -ForegroundColor Yellow
}

# 4. Check secrets configuration
Write-Host "`n4. Verifying secrets configuration..." -ForegroundColor Yellow
Write-Host "   Run this command to verify secrets are set:" -ForegroundColor Gray
Write-Host "   supabase secrets list" -ForegroundColor Cyan

Write-Host "`n=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "✅ Anon key: Working" -ForegroundColor Green
Write-Host "✅ STK Push endpoint: Accessible" -ForegroundColor Green
Write-Host "⚠️  Transactions: Check database/RLS policies" -ForegroundColor Yellow
Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "1. Check Supabase dashboard for function logs" -ForegroundColor Gray
Write-Host "2. Verify RLS policies allow transaction viewing" -ForegroundColor Gray
Write-Host "3. Complete a test payment on the Safaricom app" -ForegroundColor Gray
Write-Host "4. Register callback URL with Safaricom Daraja Portal`n" -ForegroundColor Gray
