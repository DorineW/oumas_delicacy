# Production M-Pesa Setup Script
# Run this script to configure your production M-Pesa credentials

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "   Production M-Pesa Configuration Setup" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "This script will help you set up production M-Pesa credentials." -ForegroundColor Yellow
Write-Host "Make sure you have received your production credentials from Safaricom." -ForegroundColor Yellow
Write-Host ""

# Check if supabase CLI is installed
$supabaseVersion = supabase --version 2>$null
if (-not $supabaseVersion) {
    Write-Host "ERROR: Supabase CLI is not installed!" -ForegroundColor Red
    Write-Host "Install it first: https://supabase.com/docs/guides/cli" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Supabase CLI found: $supabaseVersion" -ForegroundColor Green
Write-Host ""

# Prompt for credentials
Write-Host "Enter your Production M-Pesa Credentials:" -ForegroundColor Cyan
Write-Host "(Press Enter to skip and keep existing value)" -ForegroundColor DarkGray
Write-Host ""

$consumerKey = Read-Host "Consumer Key"
$consumerSecret = Read-Host "Consumer Secret" -AsSecureString
$shortCode = Read-Host "Business Short Code (Paybill/Till Number)"
$passkey = Read-Host "Passkey" -AsSecureString

Write-Host ""
Write-Host "Optional Configuration:" -ForegroundColor Cyan

$callbackUrl = Read-Host "Callback URL (press Enter for default)"
$environment = Read-Host "Environment (production/sandbox, default: production)"

if ([string]::IsNullOrWhiteSpace($environment)) {
    $environment = "production"
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "   Configuring Supabase Secrets..." -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

$errors = @()

# Set Consumer Key
if (-not [string]::IsNullOrWhiteSpace($consumerKey)) {
    Write-Host "Setting MPESA_CONSUMER_KEY..." -ForegroundColor Yellow
    try {
        supabase secrets set "MPESA_CONSUMER_KEY=$consumerKey"
        Write-Host "✓ MPESA_CONSUMER_KEY set" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed to set MPESA_CONSUMER_KEY" -ForegroundColor Red
        $errors += "MPESA_CONSUMER_KEY"
    }
}

# Set Consumer Secret
if ($consumerSecret.Length -gt 0) {
    Write-Host "Setting MPESA_CONSUMER_SECRET..." -ForegroundColor Yellow
    try {
        $plainSecret = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($consumerSecret)
        )
        supabase secrets set "MPESA_CONSUMER_SECRET=$plainSecret"
        Write-Host "✓ MPESA_CONSUMER_SECRET set" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed to set MPESA_CONSUMER_SECRET" -ForegroundColor Red
        $errors += "MPESA_CONSUMER_SECRET"
    }
}

# Set Short Code
if (-not [string]::IsNullOrWhiteSpace($shortCode)) {
    Write-Host "Setting MPESA_SHORTCODE..." -ForegroundColor Yellow
    try {
        supabase secrets set "MPESA_SHORTCODE=$shortCode"
        Write-Host "✓ MPESA_SHORTCODE set" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed to set MPESA_SHORTCODE" -ForegroundColor Red
        $errors += "MPESA_SHORTCODE"
    }
}

# Set Passkey
if ($passkey.Length -gt 0) {
    Write-Host "Setting MPESA_PASSKEY..." -ForegroundColor Yellow
    try {
        $plainPasskey = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($passkey)
        )
        supabase secrets set "MPESA_PASSKEY=$plainPasskey"
        Write-Host "✓ MPESA_PASSKEY set" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed to set MPESA_PASSKEY" -ForegroundColor Red
        $errors += "MPESA_PASSKEY"
    }
}

# Set Environment
Write-Host "Setting MPESA_ENVIRONMENT..." -ForegroundColor Yellow
try {
    supabase secrets set "MPESA_ENVIRONMENT=$environment"
    Write-Host "✓ MPESA_ENVIRONMENT set to $environment" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to set MPESA_ENVIRONMENT" -ForegroundColor Red
    $errors += "MPESA_ENVIRONMENT"
}

# Set Callback URL (optional)
if (-not [string]::IsNullOrWhiteSpace($callbackUrl)) {
    Write-Host "Setting MPESA_CALLBACK_URL..." -ForegroundColor Yellow
    try {
        supabase secrets set "MPESA_CALLBACK_URL=$callbackUrl"
        Write-Host "✓ MPESA_CALLBACK_URL set" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed to set MPESA_CALLBACK_URL" -ForegroundColor Red
        $errors += "MPESA_CALLBACK_URL"
    }
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "   Verifying Configuration..." -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Fetching configured secrets..." -ForegroundColor Yellow
supabase secrets list

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "   Deploying Edge Functions..." -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Deploying mpesa-stk-push..." -ForegroundColor Yellow
try {
    supabase functions deploy mpesa-stk-push
    Write-Host "✓ mpesa-stk-push deployed" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to deploy mpesa-stk-push" -ForegroundColor Red
    $errors += "mpesa-stk-push deployment"
}

Write-Host ""
Write-Host "Deploying mpesa-callback..." -ForegroundColor Yellow
try {
    supabase functions deploy mpesa-callback
    Write-Host "✓ mpesa-callback deployed" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to deploy mpesa-callback" -ForegroundColor Red
    $errors += "mpesa-callback deployment"
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "   Setup Summary" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

if ($errors.Count -eq 0) {
    Write-Host "✓ All configuration steps completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "1. Register your callback URL with Safaricom:" -ForegroundColor White
    Write-Host "   https://hqfixpqwxmwftvhgdrxn.supabase.co/functions/v1/mpesa-callback" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "2. Test with a small payment (KES 10) first" -ForegroundColor White
    Write-Host ""
    Write-Host "3. Monitor Edge Function logs:" -ForegroundColor White
    Write-Host "   supabase functions logs mpesa-stk-push" -ForegroundColor Yellow
    Write-Host "   supabase functions logs mpesa-callback" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "4. Check database for transactions:" -ForegroundColor White
    Write-Host "   SELECT * FROM mpesa_transactions ORDER BY created_at DESC LIMIT 5;" -ForegroundColor Yellow
    Write-Host ""
} else {
    Write-Host "⚠ Setup completed with some errors:" -ForegroundColor Yellow
    foreach ($error in $errors) {
        Write-Host "  - $error" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "Please fix the errors and run the script again." -ForegroundColor Yellow
}

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "For detailed documentation, see:" -ForegroundColor White
Write-Host "  PRODUCTION_MPESA_SETUP.md" -ForegroundColor Yellow
Write-Host ""
