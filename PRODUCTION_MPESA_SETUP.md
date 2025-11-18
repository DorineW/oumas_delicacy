# Production M-Pesa Integration Guide

## Overview
This guide walks you through setting up **real M-Pesa payments** for your production environment.

---

## Prerequisites

### 1. M-Pesa Go-Live Application
You need to apply for M-Pesa Daraja API production credentials:

1. **Register at Safaricom Daraja Portal**
   - Go to: https://developer.safaricom.co.ke/
   - Create an account or log in
   - Navigate to "My Apps"

2. **Create Production App**
   - Click "Create App"
   - Fill in business details
   - Select "Lipa Na M-Pesa Online" API
   - Submit for approval

3. **Business Documentation Required**
   - Business Registration Certificate
   - KRA PIN Certificate
   - ID of Directors
   - Till/Paybill Number (if you have one)

4. **Wait for Approval** (usually 1-5 business days)
   - You'll receive production credentials via email
   - Consumer Key and Consumer Secret
   - Business Short Code (Paybill or Till Number)
   - Passkey for Lipa Na M-Pesa

---

## Production Credentials You'll Receive

After approval, you'll get:

```env
MPESA_CONSUMER_KEY=your_production_consumer_key
MPESA_CONSUMER_SECRET=your_production_consumer_secret
MPESA_SHORTCODE=your_paybill_or_till_number
MPESA_PASSKEY=your_production_passkey
```

**Important Notes:**
- **Paybill** (recommended for businesses): 6-7 digit number (e.g., 4001234)
- **Till Number**: 6 digit number (e.g., 123456)
- **Passkey**: Unique string provided by Safaricom for your business

---

## Configuration Steps

### 1. Update Supabase Edge Function Secrets

Run these commands in your terminal (replace with your actual credentials):

```powershell
# Set production M-Pesa credentials
supabase secrets set MPESA_CONSUMER_KEY="your_production_consumer_key"
supabase secrets set MPESA_CONSUMER_SECRET="your_production_consumer_secret"
supabase secrets set MPESA_SHORTCODE="your_paybill_number"
supabase secrets set MPESA_PASSKEY="your_production_passkey"

# Optional: Set custom callback URL (uses default Supabase URL if not set)
supabase secrets set MPESA_CALLBACK_URL="https://your-project.supabase.co/functions/v1/mpesa-callback"

# Optional: Email receipt configuration (for sending receipts via email)
supabase secrets set RESEND_API_KEY="your_resend_api_key"
```

### 2. Update Edge Functions to Production URLs

The functions have been updated to automatically use **production** URLs. No code changes needed!

### 3. Register Callback URL with Safaricom

**Important:** You must register your callback URL with Safaricom in production.

**Your Callback URL:**
```
https://hqfixpqwxmwftvhgdrxn.supabase.co/functions/v1/mpesa-callback
```

**How to Register:**
1. Go to Safaricom Daraja Portal
2. Navigate to your production app
3. Under "Lipa Na M-Pesa Online", add your callback URL
4. Or use the C2B Register URL API to programmatically register

### 4. Deploy Updated Edge Functions

```powershell
# Deploy both functions
supabase functions deploy mpesa-stk-push
supabase functions deploy mpesa-callback
```

### 5. Test with Small Amount First

Before going live, test with a small amount (e.g., KES 10):

```dart
// In your app
MpesaPaymentButton(
  phoneNumber: '0712345678', // Your test number
  amount: 10, // Small amount
  orderReference: 'TEST-ORDER',
  onSuccess: () => print('Payment successful!'),
  onCancel: () => print('Payment cancelled'),
)
```

---

## Production vs Sandbox Differences

| Feature | Sandbox | Production |
|---------|---------|------------|
| **Base URL** | `https://sandbox.safaricom.co.ke` | `https://api.safaricom.co.ke` |
| **Credentials** | Free, instant access | Requires business verification |
| **Callbacks** | Unreliable, often don't work | Real-time, reliable |
| **Test Amount** | Any amount | Real money deducted |
| **Phone Numbers** | Only test numbers work | All Kenyan M-Pesa numbers |
| **Short Code** | 174379 (test) | Your business Paybill/Till |

---

## Updated API Endpoints

### Production URLs (automatically used after credential update):

1. **OAuth Token:**
   ```
   https://api.safaricom.co.ke/oauth/v1/generate?grant_type=client_credentials
   ```

2. **STK Push:**
   ```
   https://api.safaricom.co.ke/mpesa/stkpush/v1/processrequest
   ```

3. **Callback URL (your webhook):**
   ```
   https://hqfixpqwxmwftvhgdrxn.supabase.co/functions/v1/mpesa-callback
   ```

---

## Testing Production Integration

### 1. Check Function Logs
```powershell
supabase functions logs mpesa-stk-push
supabase functions logs mpesa-callback
```

### 2. Verify Secrets are Set
```powershell
supabase secrets list
```

You should see:
- MPESA_CONSUMER_KEY
- MPESA_CONSUMER_SECRET
- MPESA_SHORTCODE
- MPESA_PASSKEY

### 3. Test Payment Flow
1. Make a small payment (KES 10)
2. Check phone for STK push prompt
3. Enter M-Pesa PIN
4. Verify callback is received (check logs)
5. Verify transaction updated in database
6. Verify receipt generated

---

## Database Verification

Check your transactions in Supabase SQL Editor:

```sql
-- View recent transactions
SELECT 
  id,
  status,
  amount,
  phone_number,
  account_reference,
  transaction_id,
  result_desc,
  created_at,
  updated_at
FROM mpesa_transactions
ORDER BY created_at DESC
LIMIT 10;

-- Check for completed payments
SELECT COUNT(*) as completed_payments
FROM mpesa_transactions
WHERE status = 'completed'
AND created_at > NOW() - INTERVAL '1 day';

-- Check receipts generated
SELECT 
  r.receipt_number,
  r.total_amount,
  r.customer_name,
  r.customer_phone,
  r.issue_date
FROM receipts r
JOIN mpesa_transactions t ON t.transaction_id = r.transaction_id
ORDER BY r.issue_date DESC
LIMIT 5;
```

---

## Common Production Issues & Solutions

### Issue 1: "Invalid Access Token"
**Cause:** Production credentials not set or incorrect
**Solution:**
```powershell
supabase secrets set MPESA_CONSUMER_KEY="correct_key"
supabase secrets set MPESA_CONSUMER_SECRET="correct_secret"
supabase functions deploy mpesa-stk-push
```

### Issue 2: "Invalid Short Code"
**Cause:** Using sandbox short code (174379) in production
**Solution:**
```powershell
supabase secrets set MPESA_SHORTCODE="your_paybill_number"
supabase functions deploy mpesa-stk-push
```

### Issue 3: Callbacks Not Received
**Cause:** Callback URL not registered with Safaricom
**Solution:** Register your callback URL in Daraja Portal under your production app

### Issue 4: "The service request is processed successfully"
**Cause:** This is SUCCESS! STK push was sent to phone
**Action:** User should check their phone and enter M-Pesa PIN

### Issue 5: Payment Times Out
**Cause:** User didn't enter PIN within 2 minutes
**Solution:** User should retry payment and complete promptly

---

## Security Best Practices

1. **Never commit credentials to Git**
   - Always use environment variables
   - Use Supabase Secrets for production

2. **Use HTTPS Only**
   - Callback URL must be HTTPS
   - Supabase Edge Functions use HTTPS by default

3. **Validate All Callbacks**
   - Check ResultCode (0 = success)
   - Verify MerchantRequestID matches
   - Store all transaction data for audit

4. **Enable RLS (Row Level Security)**
   - Already configured in your database schema
   - Users can only view their own transactions

5. **Monitor Transaction Logs**
   - Check for failed transactions daily
   - Set up alerts for high failure rates

---

## Go-Live Checklist

- [ ] Production credentials received from Safaricom
- [ ] Secrets configured in Supabase
- [ ] Callback URL registered with Safaricom
- [ ] Edge Functions deployed with production URLs
- [ ] Test payment completed successfully (small amount)
- [ ] Callback received and transaction updated
- [ ] Receipt generated correctly
- [ ] Order created after payment
- [ ] RLS policies tested
- [ ] Error handling tested (cancel, timeout)
- [ ] Email receipts working (if configured)
- [ ] Monitoring set up for transaction logs

---

## Support & Resources

### Safaricom Daraja Support
- Portal: https://developer.safaricom.co.ke/
- Email: apisupport@safaricom.co.ke
- Documentation: https://developer.safaricom.co.ke/Documentation

### Your Edge Function URLs
- STK Push: `https://hqfixpqwxmwftvhgdrxn.supabase.co/functions/v1/mpesa-stk-push`
- Callback: `https://hqfixpqwxmwftvhgdrxn.supabase.co/functions/v1/mpesa-callback`

### Supabase Dashboard
- Project: https://supabase.com/dashboard/project/hqfixpqwxmwftvhgdrxn
- Logs: https://supabase.com/dashboard/project/hqfixpqwxmwftvhgdrxn/logs/edge-functions

---

## Quick Reference: Command Summary

```powershell
# Set production secrets
supabase secrets set MPESA_CONSUMER_KEY="your_key"
supabase secrets set MPESA_CONSUMER_SECRET="your_secret"
supabase secrets set MPESA_SHORTCODE="your_shortcode"
supabase secrets set MPESA_PASSKEY="your_passkey"

# Deploy functions
supabase functions deploy mpesa-stk-push
supabase functions deploy mpesa-callback

# Check logs
supabase functions logs mpesa-stk-push
supabase functions logs mpesa-callback

# Verify secrets
supabase secrets list
```

---

## Next Steps After Go-Live

1. **Monitor Daily**
   - Check transaction success rates
   - Review failed payments
   - Monitor callback response times

2. **Optimize**
   - Add retry logic for failed payments
   - Implement payment reminders
   - Add transaction reports

3. **Scale**
   - Consider adding M-Pesa Express (C2B)
   - Add B2C for refunds
   - Implement payment reconciliation

---

**Ready to go live? Follow the checklist above and test thoroughly before enabling for customers!** 🚀
