# Generate Missing Receipt for Recent Payment
# This script connects to your Supabase database and generates a receipt

$dbUrl = "postgresql://postgres.hqfixpqwxmwftvhgdrxn:Dorine%40123@aws-0-us-west-1.pooler.supabase.com:6543/postgres"

Write-Host "🔧 Generating missing receipt..." -ForegroundColor Cyan
Write-Host ""

# Read the SQL file
$sqlScript = Get-Content ".\database\generate_missing_receipt.sql" -Raw

# Execute using Supabase CLI (recommended method)
if (Get-Command supabase -ErrorAction SilentlyContinue) {
    Write-Host "✅ Using Supabase CLI..." -ForegroundColor Green
    
    # Save to temp file
    $tempFile = [System.IO.Path]::GetTempFileName() + ".sql"
    $sqlScript | Out-File -FilePath $tempFile -Encoding UTF8
    
    # Execute
    supabase db execute --file $tempFile
    
    # Cleanup
    Remove-Item $tempFile
    
} else {
    Write-Host "❌ Supabase CLI not found" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please run this SQL manually in Supabase SQL Editor:" -ForegroundColor Yellow
    Write-Host "https://supabase.com/dashboard/project/hqfixpqwxmwftvhgdrxn/sql" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Or install Supabase CLI:" -ForegroundColor Yellow
    Write-Host "  scoop install supabase" -ForegroundColor White
    Write-Host ""
}

Write-Host ""
Write-Host "📋 To verify receipt was created, run:" -ForegroundColor Yellow
Write-Host '  supabase db execute --file check_receipt_status.sql' -ForegroundColor White
Write-Host ""
