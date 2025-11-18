# Email Receipt Setup Guide

Email receipts are **already implemented** in your M-Pesa callback function. You just need to configure the email service.

## Quick Setup (5 minutes)

### 1. Sign Up for Resend
1. Go to https://resend.com/signup
2. Create a free account (100 emails/day free)
3. Verify your email address

### 2. Add Your Domain (Optional for Production)
```
Domain: oumasdelicacy.com
```
Or use the test domain: `onboarding.resend.dev`

### 3. Generate API Key
1. Go to https://resend.com/api-keys
2. Click **Create API Key**
3. Name it: `oumas-delicacy-production`
4. Copy the key (starts with `re_`)

### 4. Configure Supabase Secret
```powershell
# Add the Resend API key to Supabase
supabase secrets set RESEND_API_KEY="re_xxxxxxxxxxxxx"
```

### 5. Test It
Make a test M-Pesa payment, and the receipt will be automatically emailed to the customer!

---

## Email Configuration

### Sender Email
**Current:** `receipts@oumasdelicacy.com`

If you want to change this, edit `supabase/functions/mpesa-callback/index.ts`:
```typescript
from: "Ouma's Delicacy <receipts@oumasdelicacy.com>",
```

### Subject Line
**Current:** `Payment Receipt {receipt_number} - Ouma's Delicacy`

---

## What the Email Looks Like

### Header
- **Gradient banner** (purple/blue)
- **Company name**: Ouma's Delicacy
- **Title**: Payment Receipt

### Content
```
Receipt Number: RCP-20251118-000001
Transaction ID: SKJ1H4G42C
Date: November 18, 2025 at 2:30 PM
Payment Method: M-Pesa

Order Details:
┌─────────────────────────────────┬──────┬──────────┬────────────┐
│ Item                            │ Qty  │ Price    │ Total      │
├─────────────────────────────────┼──────┼──────────┼────────────┤
│ Grilled Tilapia                 │ 2    │ KSh 800  │ KSh 1,600 │
│ Ugali                           │ 2    │ KSh 100  │ KSh 200   │
└─────────────────────────────────┴──────┴──────────┴────────────┘

Subtotal:      KSh 1,800
Tax (16%):     KSh 288
Delivery:      KSh 150
─────────────────────────
TOTAL:         KSh 2,238
```

### Footer
- Customer details (name, phone, email)
- Business contact info
- Support message

---

## Email Delivery Status

### Check If Emails Are Sending
1. Go to https://resend.com/emails
2. View sent emails, opens, clicks, bounces
3. Debug delivery issues

### Common Issues

**❌ "RESEND_API_KEY not configured"**
- Run: `supabase secrets set RESEND_API_KEY="your_key"`

**❌ Email not received**
- Check spam/junk folder
- Verify email address in user profile
- Check Resend dashboard for delivery status

**❌ "Domain not verified"**
- Use `onboarding.resend.dev` for testing
- Or verify your domain in Resend settings

---

## Free Tier Limits

**Resend Free Plan:**
- ✅ 100 emails per day
- ✅ 3,000 emails per month
- ✅ All features included

**Upgrade if needed:**
- Pro: $20/month for 50,000 emails
- Business: Custom pricing

---

## Testing Without Real Payments

You can manually trigger a receipt email by simulating a completed transaction:

```sql
-- 1. Create test transaction
INSERT INTO mpesa_transactions (
    transaction_id,
    merchant_request_id,
    checkout_request_id,
    transaction_timestamp,
    amount,
    phone_number,
    transaction_type,
    status,
    business_short_code,
    user_auth_id,
    order_id
) VALUES (
    'TEST123456',
    'test-merchant-req',
    'test-checkout-req',
    NOW(),
    2000,
    '254712345678',
    'payment',
    'completed',
    '174379',
    'YOUR_USER_AUTH_ID',
    'YOUR_ORDER_ID'
);

-- 2. Callback function will auto-generate receipt and send email
```

---

## Customizing the Email Template

The email HTML is in `supabase/functions/mpesa-callback/index.ts` in the `generateReceiptHTML()` function.

**To customize:**
1. Edit the HTML in `generateReceiptHTML()`
2. Add your logo: Replace text with `<img src="https://your-logo-url.com/logo.png">`
3. Change colors: Update gradient values
4. Add custom footer: Add business registration details

**Redeploy after changes:**
```powershell
supabase functions deploy mpesa-callback
```

---

## Production Checklist

- [ ] Sign up for Resend
- [ ] Generate API key
- [ ] Configure `RESEND_API_KEY` in Supabase
- [ ] Verify domain (optional but recommended)
- [ ] Test with a real payment
- [ ] Check email delivery in Resend dashboard
- [ ] Customize email template (optional)
- [ ] Monitor daily email usage

---

## Support

**Resend Documentation:** https://resend.com/docs  
**Resend Status:** https://status.resend.com  
**API Reference:** https://resend.com/docs/api-reference

**Questions?**
- Check Supabase function logs: `supabase functions logs mpesa-callback`
- View Resend dashboard for email delivery status
