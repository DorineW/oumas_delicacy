# 🚀 M-Pesa Setup - Step by Step Guide

## STEP 1: Get M-Pesa Credentials (Do this first!)

### 🌐 Go to Safaricom Daraja Portal
**URL**: https://developer.safaricom.co.ke/

### 📝 Steps:
1. **Sign Up / Login** to Daraja Portal
2. Click **"My Apps"** → **"Add a New App"**
3. Fill in app details:
   - **App Name**: Ouma's Delicacy
   - **Description**: Food delivery payment system
4. Select **"Lipa Na M-Pesa Online"** API
5. Click **"Create App"**

### 🔑 Copy These Credentials:
Once your app is created, you'll see:
- ✅ **Consumer Key** (looks like: `xXxXxXxXxXxXxXxXxXxX`)
- ✅ **Consumer Secret** (looks like: `yYyYyYyYyYyYyYyYyYyY`)
- ✅ **Passkey** (long string, usually in test credentials section)
- ✅ **Business Short Code** (e.g., `174379` for sandbox)

### 📋 For Sandbox Testing:
Safaricom provides test credentials. Look for:
- **Test Short Code**: Usually `174379`
- **Test Passkey**: Available in app dashboard
- **Test Phone**: `254708374149` (or your registered test number)

---

## STEP 2: Configure Supabase Secrets

Once you have your credentials, run these commands:

### Option A: Manual Setup (Copy-paste one by one)

```powershell
# Replace YOUR_XXX with actual values from Daraja Portal

# Consumer Key (from Daraja Portal)
supabase secrets set MPESA_CONSUMER_KEY=YOUR_CONSUMER_KEY_HERE

# Consumer Secret (from Daraja Portal)
supabase secrets set MPESA_CONSUMER_SECRET=YOUR_CONSUMER_SECRET_HERE

# Business Short Code (e.g., 174379 for sandbox)
supabase secrets set MPESA_SHORTCODE=174379

# Passkey (from Daraja Portal - long string)
supabase secrets set MPESA_PASSKEY=YOUR_PASSKEY_HERE

# Callback URL (already set for you)
supabase secrets set MPESA_CALLBACK_URL=https://hqfixpqwxmwftvhgdrxn.supabase.co/functions/v1/mpesa-callback

# Optional: For email receipts (get from resend.com)
supabase secrets set RESEND_API_KEY=re_YOUR_RESEND_KEY
```

### Option B: Interactive Script
```powershell
.\database\setup_mpesa_secrets.ps1
```

### ✅ Verify Secrets Are Set
```powershell
supabase secrets list
```

You should see:
- MPESA_CONSUMER_KEY
- MPESA_CONSUMER_SECRET
- MPESA_SHORTCODE
- MPESA_PASSKEY
- MPESA_CALLBACK_URL
- RESEND_API_KEY (optional)

---

## STEP 3: Register Callback URL with Safaricom

### 🔗 Your Callback URL:
```
https://hqfixpqwxmwftvhgdrxn.supabase.co/functions/v1/mpesa-callback
```

### 📝 How to Register:

#### Method 1: Through Daraja Portal (Easiest)
1. Go to your app in Daraja Portal
2. Look for **"Register URLs"** or **"Callback URLs"** section
3. Add your callback URL
4. Save

#### Method 2: Using C2B Register URL API
If portal doesn't have option, use this API:

```powershell
# This is an example - adjust based on Safaricom docs
curl -X POST "https://sandbox.safaricom.co.ke/mpesa/c2b/v1/registerurl" `
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" `
  -H "Content-Type: application/json" `
  -d '{
    "ShortCode": "YOUR_SHORTCODE",
    "ResponseType": "Completed",
    "ConfirmationURL": "https://hqfixpqwxmwftvhgdrxn.supabase.co/functions/v1/mpesa-callback",
    "ValidationURL": "https://hqfixpqwxmwftvhgdrxn.supabase.co/functions/v1/mpesa-callback"
  }'
```

#### Method 3: Contact Safaricom Support
Email: support@safaricom.co.ke
Provide: Your short code + callback URL

---

## STEP 4: Test the Setup

### 🧪 Quick Test Command
```powershell
# Test if STK push works
curl -X POST https://hqfixpqwxmwftvhgdrxn.supabase.co/functions/v1/mpesa-stk-push `
  -H "Content-Type: application/json" `
  -H "Authorization: Bearer YOUR_SUPABASE_ANON_KEY" `
  -d '{
    "phoneNumber": "254708374149",
    "amount": 10,
    "accountReference": "TEST001",
    "transactionDesc": "Test payment"
  }'
```

### ✅ Expected Response:
```json
{
  "success": true,
  "message": "STK Push sent successfully",
  "checkoutRequestId": "ws_CO_xxx...",
  "merchantRequestId": "xxx-xxx-xxx"
}
```

### 📱 What Should Happen:
1. You make the API call
2. Test phone (254708374149) receives M-Pesa prompt
3. Enter any 4-digit PIN (sandbox doesn't validate)
4. Payment confirms
5. Callback function updates database
6. Check transaction: 
   ```sql
   SELECT * FROM mpesa_transactions ORDER BY created_at DESC LIMIT 1;
   ```

---

## STEP 5: Monitor Function Logs

### 📊 Watch Real-time Logs
```powershell
# STK Push logs
supabase functions logs mpesa-stk-push --follow

# Callback logs (separate terminal)
supabase functions logs mpesa-callback --follow
```

### 🔍 Check Recent Activity
```powershell
# Last 10 log entries
supabase functions logs mpesa-callback
```

---

## 📋 Quick Checklist

- [ ] **Got M-Pesa credentials** from Daraja Portal
- [ ] **Set Supabase secrets** (all 5-6 variables)
- [ ] **Registered callback URL** with Safaricom
- [ ] **Tested STK push** with test phone
- [ ] **Verified transaction** appears in database
- [ ] **Checked function logs** for errors

---

## 🎯 What Happens Next?

Once setup is complete:

1. **Flutter Integration** - Add M-Pesa payment to your app
   - Guide: `MPESA_FLUTTER_INTEGRATION.md`
   - Estimated time: 30 minutes

2. **Testing** - Test full payment flow
   - Place order in app
   - Pay with M-Pesa
   - Verify order updates
   - Check receipt generation

3. **Production** - Switch to live credentials
   - Get production credentials from Daraja
   - Update secrets
   - Change API URLs in functions
   - Test with real money (small amounts)

---

## 🆘 Troubleshooting

### ❌ "Failed to get M-Pesa access token"
**Solution**: Check `MPESA_CONSUMER_KEY` and `MPESA_CONSUMER_SECRET`
```powershell
supabase secrets list  # Verify they're set
```

### ❌ "STK Push failed"
**Possible causes**:
- Wrong phone number format (must be 254XXXXXXXXX)
- Invalid credentials
- Sandbox vs Production mismatch

### ❌ "No callback received"
**Solution**: 
1. Check callback URL is registered with Safaricom
2. View logs: `supabase functions logs mpesa-callback`
3. Verify function is deployed: `supabase functions list`

### ❌ Secrets not updating
```powershell
# Force update a secret
supabase secrets unset MPESA_CONSUMER_KEY
supabase secrets set MPESA_CONSUMER_KEY=new_value_here
```

---

## 📞 Support Resources

- **Daraja Portal**: https://developer.safaricom.co.ke/
- **API Documentation**: https://developer.safaricom.co.ke/Documentation
- **Support Email**: support@safaricom.co.ke
- **Supabase Docs**: https://supabase.com/docs

---

## 🚀 Ready to Start?

**Run this to begin**:
```powershell
# Open Daraja Portal in browser
start https://developer.safaricom.co.ke/

# Or run interactive setup after getting credentials
.\database\setup_mpesa_secrets.ps1
```

Good luck! 🎉
