# Quick M-Pesa Production Setup Commands

## 🚀 Quick Setup (Copy & Paste)

### 1. Set Production Credentials
```powershell
# Replace with your actual credentials from Safaricom
supabase secrets set MPESA_CONSUMER_KEY="your_production_consumer_key"
supabase secrets set MPESA_CONSUMER_SECRET="your_production_consumer_secret"
supabase secrets set MPESA_SHORTCODE="your_paybill_number"
supabase secrets set MPESA_PASSKEY="your_production_passkey"
supabase secrets set MPESA_ENVIRONMENT="production"
```

### 2. Deploy Functions
```powershell
supabase functions deploy mpesa-stk-push
supabase functions deploy mpesa-callback
```

### 3. Verify Setup
```powershell
supabase secrets list
```

---

## 🧪 Testing Commands

### Check Function Logs
```powershell
# View STK Push logs
supabase functions logs mpesa-stk-push

# View Callback logs
supabase functions logs mpesa-callback
```

### Check Database Transactions
```sql
-- In Supabase SQL Editor
SELECT 
  id,
  status,
  amount,
  phone_number,
  result_desc,
  created_at
FROM mpesa_transactions
ORDER BY created_at DESC
LIMIT 10;
```

---

## 🔄 Switch Between Sandbox and Production

### Use Production (Default)
```powershell
supabase secrets set MPESA_ENVIRONMENT="production"
supabase functions deploy mpesa-stk-push
supabase functions deploy mpesa-callback
```

### Use Sandbox (Testing)
```powershell
supabase secrets set MPESA_ENVIRONMENT="sandbox"
supabase functions deploy mpesa-stk-push
supabase functions deploy mpesa-callback
```

---

## 📝 Your Callback URL

Register this URL with Safaricom:
```
https://hqfixpqwxmwftvhgdrxn.supabase.co/functions/v1/mpesa-callback
```

**Where to Register:**
1. Go to https://developer.safaricom.co.ke/
2. Navigate to your production app
3. Under "Lipa Na M-Pesa Online", add the callback URL

---

## ⚡ Automated Setup Script

Run the interactive setup script:
```powershell
.\setup_production_mpesa.ps1
```

This will prompt you for credentials and automatically configure everything.

---

## 🔍 Troubleshooting

### Check if secrets are set
```powershell
supabase secrets list
```

Expected output:
- MPESA_CONSUMER_KEY
- MPESA_CONSUMER_SECRET
- MPESA_SHORTCODE
- MPESA_PASSKEY
- MPESA_ENVIRONMENT

### Test with small amount
Use KES 10 for first test to avoid losing money if something fails.

### Check Edge Function status
```powershell
supabase functions list
```

### View real-time logs
```powershell
# Keep this running while testing
supabase functions logs mpesa-stk-push --follow
```

---

## 📚 Full Documentation

See `PRODUCTION_MPESA_SETUP.md` for complete guide including:
- How to apply for production credentials
- Business documentation required
- Security best practices
- Go-live checklist
- Common issues and solutions

---

## 🎯 Testing Checklist

- [ ] Secrets configured
- [ ] Functions deployed
- [ ] Callback URL registered with Safaricom
- [ ] Test payment with KES 10
- [ ] STK Push received on phone
- [ ] Callback received (check logs)
- [ ] Transaction updated in database
- [ ] Receipt generated

---

## 🆘 Need Help?

**Safaricom Support:**
- Email: apisupport@safaricom.co.ke
- Portal: https://developer.safaricom.co.ke/

**Check Logs:**
```powershell
# Open Supabase dashboard
Start-Process "https://supabase.com/dashboard/project/hqfixpqwxmwftvhgdrxn/logs/edge-functions"
```

---

**Ready? Copy the commands above and let's go live!** 🚀
