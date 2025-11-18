# M-Pesa Environment Variables Setup Script
# Run these commands to configure your Supabase project

Write-Host "🔧 M-Pesa Configuration Setup" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Check if supabase CLI is logged in
Write-Host "Checking Supabase CLI status..." -ForegroundColor Yellow
supabase projects list

Write-Host ""
Write-Host "📝 Set up your M-Pesa credentials below:" -ForegroundColor Green
Write-Host ""

# Prompt for M-Pesa credentials
$consumerKey = Read-Host "Enter your M-Pesa Consumer Key"
$consumerSecret = Read-Host "Enter your M-Pesa Consumer Secret" -AsSecureString
$consumerSecretPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($consumerSecret))
$shortcode = Read-Host "Enter your M-Pesa Business Shortcode (e.g., 174379)"
$passkey = Read-Host "Enter your M-Pesa Passkey"

# Get Supabase project URL
Write-Host ""
$projectRef = Read-Host "Enter your Supabase project reference (from URL)"
$callbackUrl = "https://$projectRef.supabase.co/functions/v1/mpesa-callback"

Write-Host ""
Write-Host "📧 Email configuration (optional - press Enter to skip):" -ForegroundColor Green
$resendKey = Read-Host "Enter your Resend API Key (optional)"

# Set secrets
Write-Host ""
Write-Host "🚀 Setting up secrets..." -ForegroundColor Yellow

supabase secrets set MPESA_CONSUMER_KEY=$consumerKey
supabase secrets set MPESA_CONSUMER_SECRET=$consumerSecretPlain
supabase secrets set MPESA_SHORTCODE=$shortcode
supabase secrets set MPESA_PASSKEY=$passkey
supabase secrets set MPESA_CALLBACK_URL=$callbackUrl

if ($resendKey) {
    supabase secrets set RESEND_API_KEY=$resendKey
}

Write-Host ""
Write-Host "✅ Configuration complete!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Your function URLs:" -ForegroundColor Cyan
Write-Host "  STK Push: https://$projectRef.supabase.co/functions/v1/mpesa-stk-push" -ForegroundColor White
Write-Host "  Callback: https://$projectRef.supabase.co/functions/v1/mpesa-callback" -ForegroundColor White
Write-Host ""
Write-Host "⚠️  IMPORTANT: Register this callback URL with Safaricom:" -ForegroundColor Yellow
Write-Host "  $callbackUrl" -ForegroundColor White
Write-Host ""
Write-Host "📚 Next: Check MPESA_FLUTTER_INTEGRATION.md for Flutter code" -ForegroundColor Cyan
