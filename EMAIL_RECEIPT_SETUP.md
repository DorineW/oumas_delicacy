# Email Receipt Setup Guide

This guide will help you set up automated email receipts for orders in Ouma's Delicacy.

## Prerequisites

1. **Resend Account** (Recommended - Free tier: 3,000 emails/month)
   - Sign up at: https://resend.com
   - Verify your domain OR use their testing domain
   - Get your API key from the dashboard

2. **Supabase CLI** installed
   ```bash
   npm install -g supabase
   ```

## Step 1: Set up Resend

1. Go to https://resend.com and sign up
2. Navigate to **API Keys** and create a new key
3. Copy the API key (starts with `re_`)

### Option A: Use Resend's Test Domain (Quick Start)
- You can send emails from `onboarding@resend.dev`
- Emails will be delivered immediately
- Limited to your own email for testing

### Option B: Verify Your Own Domain (Production)
- Add your domain (e.g., `oumasdelicacy.com`)
- Add the required DNS records
- Verify the domain
- Send from `receipts@oumasdelicacy.com`

## Step 2: Deploy the Edge Function

1. **Login to Supabase CLI:**
   ```bash
   supabase login
   ```

2. **Link your project:**
   ```bash
   supabase link --project-ref YOUR_PROJECT_REF
   ```
   (Find your project ref in Supabase Dashboard → Project Settings → General)

3. **Set the Resend API key as a secret:**
   ```bash
   supabase secrets set RESEND_API_KEY=re_your_api_key_here
   ```

4. **Deploy the function:**
   ```bash
   supabase functions deploy send-order-receipt
   ```

5. **Note the function URL** (you'll need this):
   ```
   https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-order-receipt
   ```

## Step 3: Update Your Flutter App

Add the email sending call after order creation. Find your order creation code (likely in `checkout_screen.dart` or `order_provider.dart`) and add:

```dart
// After successfully creating the order
try {
  await supabase.functions.invoke(
    'send-order-receipt',
    body: {'orderId': createdOrder.id},
  );
  debugPrint('✅ Receipt email sent');
} catch (e) {
  debugPrint('⚠️ Failed to send receipt email: $e');
  // Don't fail the order if email fails
}
```

Example integration:

```dart
Future<void> placeOrder() async {
  try {
    // Create order in database
    final orderResponse = await supabase
        .from('orders')
        .insert({
          'user_id': userId,
          'total_amount': totalAmount,
          'status': 'pending',
          // ... other fields
        })
        .select()
        .single();

    // Send receipt email
    await supabase.functions.invoke(
      'send-order-receipt',
      body: {'orderId': orderResponse['id']},
    );

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Order placed! Receipt sent to your email.')),
    );

  } catch (e) {
    debugPrint('Error: $e');
  }
}
```

## Step 4: (Optional) Set up Database Trigger

If you want automatic email sending even if Flutter call fails:

1. Run the SQL script in Supabase SQL Editor:
   ```sql
   -- Copy content from database/add_email_receipt_trigger.sql
   ```

2. Update the edge function URL in the trigger or set it as a project setting

## Step 5: Test the Setup

1. **Place a test order** in your app
2. **Check your email** for the receipt
3. **Monitor logs:**
   ```bash
   supabase functions logs send-order-receipt
   ```

## Customization

### Change Email Template
Edit `supabase/functions/send-order-receipt/index.ts`:
- Modify the `generateReceiptHTML()` function
- Update colors, fonts, layout as needed
- Add your logo by hosting it and using `<img src="YOUR_LOGO_URL">`

### Change Sender Email
Update in `index.ts`:
```typescript
from: 'Your Business Name <receipts@yourdomain.com>',
```

### Add More Email Types
Create similar Edge Functions for:
- Order status updates
- Delivery notifications
- Promotional emails

## Troubleshooting

### Email not sending?
1. Check Edge Function logs: `supabase functions logs send-order-receipt`
2. Verify RESEND_API_KEY is set: `supabase secrets list`
3. Check Resend dashboard for delivery status
4. Ensure user has valid email in database

### Email goes to spam?
1. Verify your domain with Resend
2. Set up SPF, DKIM, and DMARC records
3. Use a professional sender name and email

### Function timeout?
1. Increase timeout in Supabase dashboard
2. Optimize the HTML generation
3. Consider using background jobs for bulk emails

## Cost Estimate

**Resend Pricing:**
- Free: 3,000 emails/month, 100 emails/day
- Pro: $20/month for 50,000 emails
- Very affordable for most small businesses

**Supabase Edge Functions:**
- Included in free tier
- 500,000 invocations/month free
- After that: $2 per million invocations

## Next Steps

1. ✅ Set up Resend account
2. ✅ Deploy Edge Function
3. ✅ Add Flutter integration
4. 🎨 Customize email template
5. 📊 Monitor email delivery
6. 🚀 Launch to production!

## Support

If you encounter issues:
1. Check Supabase Edge Function logs
2. Check Resend delivery logs
3. Review this guide again
4. Contact Resend support (very responsive!)
