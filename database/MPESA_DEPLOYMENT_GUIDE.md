# M-Pesa Edge Functions Deployment Guide

This guide covers deploying the M-Pesa payment integration Edge Functions to Supabase.

## 📋 Prerequisites

1. **Supabase CLI** installed: `npm install -g supabase`
2. **Supabase project** with database migrated (run `migrate_to_mpesa_tables.sql`)
3. **M-Pesa Daraja API** credentials (from [Safaricom Developer Portal](https://developer.safaricom.co.ke/))
4. **Resend API** key (optional, for email receipts from [resend.com](https://resend.com))

## 🔧 Environment Variables Setup

Before deploying, set up the required secrets in your Supabase project:

```bash
# M-Pesa Credentials (Get from Safaricom Daraja Portal)
supabase secrets set MPESA_CONSUMER_KEY=your_consumer_key_here
supabase secrets set MPESA_CONSUMER_SECRET=your_consumer_secret_here
supabase secrets set MPESA_SHORTCODE=174379  # Your paybill/till number
supabase secrets set MPESA_PASSKEY=your_passkey_here

# Callback URL (update with your Supabase project URL)
supabase secrets set MPESA_CALLBACK_URL=https://your-project.supabase.co/functions/v1/mpesa-callback

# Email (Optional - for receipt emails)
supabase secrets set RESEND_API_KEY=re_your_resend_api_key
```

### Getting M-Pesa Credentials

1. Go to [Safaricom Developer Portal](https://developer.safaricom.co.ke/)
2. Create an app (Sandbox or Production)
3. Get your **Consumer Key** and **Consumer Secret**
4. Get your **Business Short Code** (Paybill/Till number)
5. Get your **Passkey** from the app dashboard

## 🚀 Deployment Steps

### 1. Login to Supabase
```bash
supabase login
```

### 2. Link to your project
```bash
supabase link --project-ref your-project-ref
```

### 3. Deploy the functions

Deploy STK Push initiator:
```bash
supabase functions deploy mpesa-stk-push
```

Deploy callback handler:
```bash
supabase functions deploy mpesa-callback
```

### 4. Verify deployment
```bash
supabase functions list
```

You should see:
- `mpesa-stk-push` - Active
- `mpesa-callback` - Active

## 🔗 Function URLs

After deployment, your functions will be available at:

- **STK Push**: `https://your-project.supabase.co/functions/v1/mpesa-stk-push`
- **Callback**: `https://your-project.supabase.co/functions/v1/mpesa-callback`

## 📱 Register Callback URL with Safaricom

**Important**: Register your callback URL with Safaricom:

1. Go to Daraja Portal → Your App → APIs → Lipa Na M-Pesa Online
2. Register URL: `https://your-project.supabase.co/functions/v1/mpesa-callback`
3. Use the C2B Register URL API (see Safaricom docs)

## 🧪 Testing

### Test STK Push locally:
```bash
supabase functions serve mpesa-stk-push
```

Then make a test request:
```bash
curl -X POST http://localhost:54321/functions/v1/mpesa-stk-push \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -d '{
    "phoneNumber": "254712345678",
    "amount": 100,
    "accountReference": "TEST001",
    "transactionDesc": "Test payment"
  }'
```

### Test callback locally:
```bash
supabase functions serve mpesa-callback
```

## 📊 Function Details

### mpesa-stk-push
**Purpose**: Initiates M-Pesa STK push to customer's phone

**Input**:
```json
{
  "phoneNumber": "0712345678",
  "amount": 1500,
  "orderId": "uuid-here",
  "accountReference": "ORDER-123",
  "transactionDesc": "Payment for Order #123"
}
```

**Output**:
```json
{
  "success": true,
  "message": "STK Push sent successfully",
  "merchantRequestId": "...",
  "checkoutRequestId": "...",
  "transactionId": "uuid-here"
}
```

### mpesa-callback
**Purpose**: Receives payment confirmation from Safaricom

**Features**:
- ✅ Updates transaction status in `mpesa_transactions`
- ✅ Updates order status to 'paid'
- ✅ Generates receipt in `receipts` table
- ✅ Sends email receipt to customer (if RESEND_API_KEY configured)

**Triggered**: Automatically by Safaricom after customer completes payment

## 🔍 Monitoring

View function logs:
```bash
# Live logs
supabase functions logs mpesa-stk-push --follow
supabase functions logs mpesa-callback --follow

# Recent logs
supabase functions logs mpesa-stk-push
supabase functions logs mpesa-callback
```

## 🔒 Security Features

- ✅ Row Level Security (RLS) enabled on all tables
- ✅ Users can only view their own transactions
- ✅ Service role key used for callback updates
- ✅ JWT validation for authenticated requests
- ✅ Phone number formatting and validation

## 🐛 Troubleshooting

### "Failed to get M-Pesa access token"
- Check `MPESA_CONSUMER_KEY` and `MPESA_CONSUMER_SECRET` are set correctly
- Verify credentials are from correct environment (Sandbox vs Production)

### "STK Push failed"
- Verify phone number format (254XXXXXXXXX)
- Check amount is greater than 1 KES
- Ensure business short code is correct

### "No pending transaction found"
- Check callback URL is registered with Safaricom
- Verify callback URL matches deployed function URL
- Check function logs for errors

### Callback not received
- Confirm callback URL registered with Safaricom
- Check if callback URL is accessible (test with Postman)
- Look for firewall/security blocking requests from Safaricom IPs

## 🔄 Production Checklist

Before going live:

- [ ] Switch to production M-Pesa credentials
- [ ] Update API URLs from sandbox to production
  - OAuth: `https://api.safaricom.co.ke/oauth/v1/generate`
  - STK Push: `https://api.safaricom.co.ke/mpesa/stkpush/v1/processrequest`
- [ ] Register production callback URL with Safaricom
- [ ] Set up Resend email domain and API key
- [ ] Test with small real transactions
- [ ] Set up monitoring and alerts
- [ ] Review RLS policies for production security

## 📚 Next Steps

1. **Flutter Integration**: Update your Flutter app to call `mpesa-stk-push`
2. **Payment Status**: Poll `mpesa_transactions` table for payment status
3. **Receipts**: Display receipts from `receipts` table
4. **Reconciliation**: Use `payment_reconciliations` for daily settlements

## 🆘 Support

- **Safaricom Daraja**: support@safaricom.co.ke
- **Supabase Docs**: https://supabase.com/docs/guides/functions
- **M-Pesa API Docs**: https://developer.safaricom.co.ke/Documentation
