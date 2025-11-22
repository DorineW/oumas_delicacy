# ================================================================
# M-Pesa Order Issue - Diagnostic and Fix Script
# ================================================================
# This script helps diagnose and fix the M-Pesa order creation issue
# ================================================================

Write-Host "🔍 M-Pesa Order Issue Diagnostic Tool" -ForegroundColor Cyan
Write-Host "======================================`n" -ForegroundColor Cyan

# Check if user wants to run diagnostics or apply fix
Write-Host "What would you like to do?" -ForegroundColor Yellow
Write-Host "1. Run diagnostics (check what's wrong)" -ForegroundColor White
Write-Host "2. Apply fix (update trigger and backfill)" -ForegroundColor White
Write-Host "3. Both (recommended)" -ForegroundColor Green
Write-Host ""

$choice = Read-Host "Enter choice (1-3)"

$diagnosticFile = "database\diagnose_mpesa_order_issue.sql"
$fixFile = "database\fix_mpesa_order_trigger.sql"

# Function to check if Supabase CLI is available
function Test-SupabaseCLI {
    try {
        $null = Get-Command supabase -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# Function to prompt for connection method
function Get-ConnectionMethod {
    Write-Host "`nHow do you want to connect to your database?" -ForegroundColor Yellow
    Write-Host "1. Supabase CLI (supabase db)" -ForegroundColor White
    Write-Host "2. Manual (I'll copy the SQL and run it myself)" -ForegroundColor White
    $method = Read-Host "Enter choice (1-2)"
    return $method
}

# Run diagnostics
if ($choice -eq "1" -or $choice -eq "3") {
    Write-Host "`n📊 Running diagnostics..." -ForegroundColor Cyan
    
    if (-not (Test-Path $diagnosticFile)) {
        Write-Host "❌ Diagnostic file not found: $diagnosticFile" -ForegroundColor Red
        exit 1
    }
    
    $method = Get-ConnectionMethod
    
    if ($method -eq "1") {
        if (Test-SupabaseCLI) {
            Write-Host "`n🔄 Running diagnostic queries..." -ForegroundColor Yellow
            Write-Host "Note: This will connect to your linked Supabase project" -ForegroundColor Gray
            
            # Read SQL file and execute via psql through Supabase
            $sqlContent = Get-Content $diagnosticFile -Raw
            $tempFile = [System.IO.Path]::GetTempFileName() + ".sql"
            $sqlContent | Out-File -FilePath $tempFile -Encoding UTF8
            
            try {
                supabase db execute --file $tempFile --linked
                Write-Host "`n✅ Diagnostics complete!" -ForegroundColor Green
            } catch {
                Write-Host "❌ Error running diagnostics: $_" -ForegroundColor Red
                Write-Host "Try option 2 (Manual) instead" -ForegroundColor Yellow
                $method = "2"
            } finally {
                if (Test-Path $tempFile) { Remove-Item $tempFile }
            }
        } else {
            Write-Host "❌ Supabase CLI not found. Please install it or choose manual method." -ForegroundColor Red
            $method = "2"
        }
    }
    
    if ($method -eq "2") {
        Write-Host "`n📋 Copy and run this SQL in your Supabase SQL Editor:" -ForegroundColor Yellow
        Write-Host "=" * 60 -ForegroundColor Gray
        Get-Content $diagnosticFile
        Write-Host "=" * 60 -ForegroundColor Gray
        Write-Host "`nPress Enter after you've reviewed the results..." -ForegroundColor Yellow
        Read-Host
    }
}

# Apply fix
if ($choice -eq "2" -or $choice -eq "3") {
    Write-Host "`n🔧 Applying fix..." -ForegroundColor Cyan
    
    if (-not (Test-Path $fixFile)) {
        Write-Host "❌ Fix file not found: $fixFile" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "`n⚠️  This will:" -ForegroundColor Yellow
    Write-Host "   • Drop and recreate the M-Pesa order status trigger" -ForegroundColor White
    Write-Host "   • Attempt to backfill any missing order_id links" -ForegroundColor White
    Write-Host "   • Update pending orders to confirmed status" -ForegroundColor White
    Write-Host ""
    
    $confirm = Read-Host "Do you want to proceed? (yes/no)"
    
    if ($confirm -ne "yes") {
        Write-Host "❌ Fix cancelled by user" -ForegroundColor Red
        exit 0
    }
    
    $method = Get-ConnectionMethod
    
    if ($method -eq "1") {
        if (Test-SupabaseCLI) {
            Write-Host "`n🔄 Applying fix..." -ForegroundColor Yellow
            Write-Host "Note: This will connect to your linked Supabase project" -ForegroundColor Gray
            
            # Read SQL file and execute via psql through Supabase
            $sqlContent = Get-Content $fixFile -Raw
            $tempFile = [System.IO.Path]::GetTempFileName() + ".sql"
            $sqlContent | Out-File -FilePath $tempFile -Encoding UTF8
            
            try {
                supabase db execute --file $tempFile --linked
                Write-Host "`n✅ Fix applied successfully!" -ForegroundColor Green
            } catch {
                Write-Host "❌ Error applying fix: $_" -ForegroundColor Red
                Write-Host "Try option 2 (Manual) instead" -ForegroundColor Yellow
                $method = "2"
            } finally {
                if (Test-Path $tempFile) { Remove-Item $tempFile }
            }
        } else {
            Write-Host "❌ Supabase CLI not found. Please install it or choose manual method." -ForegroundColor Red
            $method = "2"
        }
    }
    
    if ($method -eq "2") {
        Write-Host "`n📋 Copy and run this SQL in your Supabase SQL Editor:" -ForegroundColor Yellow
        Write-Host "=" * 60 -ForegroundColor Gray
        Get-Content $fixFile
        Write-Host "=" * 60 -ForegroundColor Gray
        Write-Host "`nPress Enter after you've applied the fix..." -ForegroundColor Yellow
        Read-Host
    }
}

Write-Host "`n" + "=" * 60 -ForegroundColor Cyan
Write-Host "📝 SUMMARY OF CHANGES" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host ""
Write-Host "✅ Improved trigger function with better logging" -ForegroundColor Green
Write-Host "✅ Handles both INSERT and UPDATE operations" -ForegroundColor Green
Write-Host "✅ Only updates orders with 'pending_payment' or 'pending' status" -ForegroundColor Green
Write-Host "✅ Added error handling to prevent transaction failures" -ForegroundColor Green
Write-Host "✅ Backfilled historical transactions (if any)" -ForegroundColor Green
Write-Host ""
Write-Host "📱 NEXT STEPS:" -ForegroundColor Yellow
Write-Host "1. Test the payment flow in your Flutter app" -ForegroundColor White
Write-Host "2. Check that orders appear after payment completes" -ForegroundColor White
Write-Host "3. Monitor the database logs for any NOTICE/WARNING messages" -ForegroundColor White
Write-Host ""
Write-Host "🔍 TO CHECK LOGS IN SUPABASE:" -ForegroundColor Yellow
Write-Host "   Go to: Database > Logs in your Supabase dashboard" -ForegroundColor White
Write-Host "   Look for: Messages starting with 'M-Pesa payment completed...'" -ForegroundColor White
Write-Host ""
Write-Host "📞 TROUBLESHOOTING:" -ForegroundColor Yellow
Write-Host "   If orders still don't appear, check:" -ForegroundColor White
Write-Host "   • RLS policies on 'orders' table" -ForegroundColor White
Write-Host "   • Order query filters in your app" -ForegroundColor White
Write-Host "   • Database logs for error messages" -ForegroundColor White
Write-Host ""
