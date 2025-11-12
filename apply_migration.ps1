# apply_migration.ps1 - Apply database views migration to Supabase
# Usage: .\apply_migration.ps1

$SUPABASE_URL = "https://hqfixpqwxmwftvhgdrxn.supabase.co"
$SUPABASE_SERVICE_KEY = $env:SUPABASE_SERVICE_ROLE_KEY

if (-not $SUPABASE_SERVICE_KEY) {
    Write-Host "❌ Error: SUPABASE_SERVICE_ROLE_KEY environment variable not set" -ForegroundColor Red
    Write-Host ""
    Write-Host "💡 To set it, run:" -ForegroundColor Yellow
    Write-Host '   $env:SUPABASE_SERVICE_ROLE_KEY = "your-service-role-key-here"' -ForegroundColor Cyan
    Write-Host ""
    Write-Host "🔑 Get your service role key from:" -ForegroundColor Yellow
    Write-Host "   https://supabase.com/dashboard/project/hqfixpqwxmwftvhgdrxn/settings/api" -ForegroundColor Cyan
    exit 1
}

Write-Host "🚀 Starting database migration..." -ForegroundColor Green
Write-Host ""

# Read migration file
$migrationPath = Join-Path $PSScriptRoot "supabase\migrations\20251112_update_reporting_views.sql"
Write-Host "📄 Reading migration file: $migrationPath" -ForegroundColor Cyan

if (-not (Test-Path $migrationPath)) {
    Write-Host "❌ Migration file not found!" -ForegroundColor Red
    exit 1
}

$sqlContent = Get-Content $migrationPath -Raw
Write-Host "✅ Migration SQL loaded successfully" -ForegroundColor Green
Write-Host ""

# Split SQL into individual statements
$statements = $sqlContent -split ';' | Where-Object { 
    $_.Trim() -and 
    -not $_.Trim().StartsWith('--') -and
    $_.Trim().Length -gt 10
}

Write-Host "📝 Found $($statements.Count) SQL statements to execute" -ForegroundColor Cyan
Write-Host ""

$successCount = 0
$failCount = 0

foreach ($i in 0..($statements.Count - 1)) {
    $statement = $statements[$i].Trim()
    
    # Skip NOTIFY statements (not supported via REST API)
    if ($statement -match 'NOTIFY') {
        Write-Host "⏭️  Skipping NOTIFY statement ($($i + 1)/$($statements.Count))" -ForegroundColor Yellow
        continue
    }
    
    Write-Host "▶️  Executing statement $($i + 1)/$($statements.Count)..." -ForegroundColor Cyan
    
    # Prepare the SQL for execution
    $body = @{
        query = $statement
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "$SUPABASE_URL/rest/v1/rpc/query" `
            -Method Post `
            -Headers @{
                "Content-Type" = "application/json"
                "apikey" = $SUPABASE_SERVICE_KEY
                "Authorization" = "Bearer $SUPABASE_SERVICE_KEY"
            } `
            -Body $body `
            -ErrorAction Stop
        
        Write-Host "   ✅ Success" -ForegroundColor Green
        $successCount++
    }
    catch {
        # Try alternate endpoint
        try {
            # Execute directly via SQL Editor endpoint
            $headers = @{
                "Content-Type" = "application/json"
                "apikey" = $SUPABASE_SERVICE_KEY
                "Authorization" = "Bearer $SUPABASE_SERVICE_KEY"
                "Prefer" = "return=minimal"
            }
            
            # Use a different approach - create a temp function
            $tempFunc = @"
CREATE OR REPLACE FUNCTION pg_temp.exec_migration() 
RETURNS void AS `$`$
BEGIN
    $statement;
END;
`$`$ LANGUAGE plpgsql;

SELECT pg_temp.exec_migration();
DROP FUNCTION IF EXISTS pg_temp.exec_migration();
"@
            
            Invoke-WebRequest -Uri "$SUPABASE_URL/rest/v1/rpc/query" `
                -Method Post `
                -Headers $headers `
                -Body (@{ query = $tempFunc } | ConvertTo-Json) `
                -ErrorAction Stop | Out-Null
            
            Write-Host "   ✅ Success (alternate method)" -ForegroundColor Green
            $successCount++
        }
        catch {
            Write-Host "   ⚠️  Skipped (may need manual execution)" -ForegroundColor Yellow
            $failCount++
        }
    }
}

Write-Host ""
Write-Host "📊 Migration Summary:" -ForegroundColor Cyan
Write-Host "   ✅ Successful: $successCount" -ForegroundColor Green
Write-Host "   ⚠️  Skipped: $failCount" -ForegroundColor Yellow
Write-Host ""

Write-Host "💡 Next Steps:" -ForegroundColor Yellow
Write-Host "   1. Go to Supabase SQL Editor: https://supabase.com/dashboard/project/hqfixpqwxmwftvhgdrxn/sql/new" -ForegroundColor Cyan
Write-Host "   2. Copy the contents of: supabase\migrations\20251112_update_reporting_views.sql" -ForegroundColor Cyan
Write-Host "   3. Paste and click 'Run' to ensure all views are created" -ForegroundColor Cyan
Write-Host ""
Write-Host "✨ Once views are created, restart your Flutter app to use them!" -ForegroundColor Green
