# ✅ M-Pesa Integration - Next Steps

## 🎉 What's Been Completed

### ✅ Database Migration
- Created `mpesa_transactions` table
- Created `receipts` and `receipt_items` tables
- Created supporting tables (tax_configurations, payment_reconciliations, etc.)
- Dropped old `payment_methods` table
- Set up Row Level Security (RLS) policies

### ✅ Edge Functions Deployed
- **mpesa-stk-push**: Initiates M-Pesa payments (ACTIVE)
- **mpesa-callback**: Receives payment confirmations (ACTIVE)
- **send-order-receipt**: Existing email receipt function (ACTIVE)

### 📍 Function URLs
Your project: `hqfixpqwxmwftvhgdrxn`

- STK Push: `https://hqfixpqwxmwftvhgdrxn.supabase.co/functions/v1/mpesa-stk-push`
- Callback: `https://hqfixpqwxmwftvhgdrxn.supabase.co/functions/v1/mpesa-callback`

## 🚀 Next Steps (In Order)

### 1. Get M-Pesa Credentials (15 minutes)

Visit [Safaricom Daraja Portal](https://developer.safaricom.co.ke/):

1. **Create Account** / Login
2. **Create New App** → Choose "Lipa Na M-Pesa Online"
3. **Get Credentials**:
   - Consumer Key
   - Consumer Secret
   - Business Short Code (Paybill/Till number)
   - Passkey

**For Testing**: Use Sandbox credentials first

### 2. Configure Environment Variables (5 minutes)

Run the setup script:
```powershell
.\database\setup_mpesa_secrets.ps1
```

Or manually set secrets:
```powershell
# M-Pesa credentials
supabase secrets set MPESA_CONSUMER_KEY=your_key_here
supabase secrets set MPESA_CONSUMER_SECRET=your_secret_here
supabase secrets set MPESA_SHORTCODE=174379
supabase secrets set MPESA_PASSKEY=your_passkey_here

# Callback URL (your project reference)
supabase secrets set MPESA_CALLBACK_URL=https://hqfixpqwxmwftvhgdrxn.supabase.co/functions/v1/mpesa-callback

# Optional: Email receipts
supabase secrets set RESEND_API_KEY=re_your_key_here
```

### 3. Register Callback URL (5 minutes)

**Important**: Register your callback URL with Safaricom:

**Callback URL**: `https://hqfixpqwxmwftvhgdrxn.supabase.co/functions/v1/mpesa-callback`

Options:
- Register through Daraja Portal (if available)
- Use C2B Register URL API
- Contact Safaricom support

### 4. Integrate into Flutter App (30 minutes)

Follow the complete guide: `database/MPESA_FLUTTER_INTEGRATION.md`

**Quick implementation**:

1. **Create service** (`lib/services/mpesa_service.dart`) - Copy from guide
2. **Create provider** (`lib/providers/mpesa_provider.dart`) - Copy from guide
3. **Add payment button** to checkout screen - Copy from guide
4. **Register provider** in `main.dart`

### 5. Test the Integration (10 minutes)

**Test flow**:
```
1. User places order
2. Click "Pay with M-Pesa"
3. Enter phone number (254712345678 for sandbox)
4. Check phone for STK prompt
5. Enter PIN (any 4 digits in sandbox)
6. Payment confirms → Order updates → Receipt generated
```

**Monitor in real-time**:
```powershell
# Watch callback logs
supabase functions logs mpesa-callback --follow

# Check transactions in database
# Use Supabase Studio: http://127.0.0.1:54323
```

### 6. Verify Everything Works

✅ **Checklist**:
- [ ] STK push received on phone
- [ ] Payment successful
- [ ] Transaction recorded in `mpesa_transactions` table
- [ ] Order status updated to 'paid'
- [ ] Receipt generated in `receipts` table
- [ ] Email receipt sent (if configured)

## 📁 Reference Documents

1. **MPESA_DEPLOYMENT_GUIDE.md** - Deployment & configuration details
2. **MPESA_FLUTTER_INTEGRATION.md** - Complete Flutter code examples
3. **setup_mpesa_secrets.ps1** - Interactive secrets setup script
4. **migrate_to_mpesa_tables.sql** - Database schema (already applied)

## 🔍 Quick Database Queries

Check transactions:
```sql
SELECT * FROM mpesa_transactions ORDER BY created_at DESC LIMIT 10;
```

Check receipts:
```sql
SELECT * FROM receipts ORDER BY created_at DESC LIMIT 10;
```

Check pending payments:
```sql
SELECT * FROM mpesa_transactions WHERE status = 'pending';
```

## 🐛 Troubleshooting

**No STK push received?**
- Check phone number format (254XXXXXXXXX)
- Verify M-Pesa credentials are correct
- Check function logs for errors

**Payment successful but order not updated?**
- Verify callback URL is registered with Safaricom
- Check callback function logs
- Verify RLS policies allow updates

**Function errors?**
- View logs: `supabase functions logs mpesa-callback`
- Check all secrets are set: `supabase secrets list`

## 📞 Support Resources

- **Safaricom Daraja**: [developer.safaricom.co.ke](https://developer.safaricom.co.ke/)
- **Safaricom Support**: support@safaricom.co.ke
- **M-Pesa API Docs**: [Documentation](https://developer.safaricom.co.ke/Documentation)
- **Supabase Docs**: [supabase.com/docs](https://supabase.com/docs)

## 🎯 Current Status

✅ **Backend**: 100% Complete (Database + Edge Functions)
⏳ **Configuration**: Need M-Pesa credentials
⏳ **Flutter Integration**: Ready to implement
⏳ **Testing**: Ready to test once configured

**Estimated time to complete**: 1-2 hours

## 🚀 Quick Start Command

To get started right now:
```powershell
# 1. Get M-Pesa credentials from Daraja Portal
# 2. Run this:
.\database\setup_mpesa_secrets.ps1
```

Then follow the Flutter integration guide!
