# 🚀 M-Pesa Integration Setup Guide for Ouma's Delicacy

## ✅ What Has Been Implemented

### Backend (Node.js + Express)
**Location:** `c:\Users\dorin\mpesa-backend\`

- ✅ Complete M-Pesa Daraja API integration
- ✅ STK Push payment initiation
- ✅ Payment status querying
- ✅ Callback handling (updates order status automatically)
- ✅ Mock callbacks for testing
- ✅ PostgreSQL integration with your Supabase database
- ✅ Rate limiting and security measures
- ✅ CORS enabled for Flutter app

### Flutter App
- ✅ `MpesaService` - Handles all API communication
- ✅ `MpesaPaymentConfirmationScreen` - Real-time payment status tracking
- ✅ Updated `CheckoutScreen` - Integrated M-Pesa payment flow
- ✅ Test mode with mock callbacks

## 📋 Setup Steps

### Step 1: Install Backend Dependencies

```powershell
cd c:\Users\dorin\mpesa-backend
npm install
```

This installs:
- express - Web server
- axios - HTTP client for Daraja API
- dotenv - Environment variables
- pg - PostgreSQL client
- express-rate-limit - Security
- cors - Enable Flutter communication

### Step 2: Configure Backend URL

The `.env` file is already configured with your credentials. You need to update the `BACKEND_URL` based on your testing approach:

#### Option A: Local Testing (Android Emulator)
```env
BACKEND_URL=http://10.0.2.2:3000
```
Update in `lib/services/mpesa_service.dart`:
```dart
static const String baseUrl = 'http://10.0.2.2:3000/api';
```

#### Option B: Local Testing (Real Device)
Find your computer's IP address:
```powershell
ipconfig
```
Look for "IPv4 Address" (e.g., 192.168.1.100)

Update `.env`:
```env
BACKEND_URL=http://192.168.1.100:3000
```

Update `lib/services/mpesa_service.dart`:
```dart
static const String baseUrl = 'http://192.168.1.100:3000/api';
```

#### Option C: Ngrok (For Real M-Pesa Callbacks)
```powershell
# Terminal 1: Start backend
cd c:\Users\dorin\mpesa-backend
npm start

# Terminal 2: Start ngrok
ngrok http 3000
```

Copy the ngrok URL (e.g., `https://abc123.ngrok.io`) and update `.env`:
```env
BACKEND_URL=https://abc123.ngrok.io
```

Update `lib/services/mpesa_service.dart`:
```dart
static const String baseUrl = 'https://abc123.ngrok.io/api';
```

**Restart the backend after updating .env!**

### Step 3: Start Backend Server

```powershell
cd c:\Users\dorin\mpesa-backend
npm start
```

You should see:
```
🚀 ===============================================
🚀 M-Pesa Backend Server Running
🚀 Port: 3000
🚀 Environment: sandbox
🚀 Backend URL: http://localhost:3000
🚀 ===============================================

📱 Test with Safaricom test numbers:
   ✅ 254708374149 (Success)
   ❌ 254700000000 (Failure)
   📞 254712345678 (General)
```

### Step 4: Run Flutter App

```powershell
cd c:\Users\dorin\oumas_delicacy
flutter pub get
flutter run
```

## 🧪 Testing the Integration

### Test Flow:
1. **Add items to cart** in the Flutter app
2. **Go to checkout** screen
3. **Fill in details**:
   - Contact phone: Any valid number
   - M-Pesa phone: `254708374149` (or `0708374149`)
   - Delivery address (if delivery)
4. **Tap "Pay Now"** button
5. **Payment Confirmation Screen** will appear:
   - Shows "Waiting for Payment"
   - In SANDBOX mode, shows TEST CONTROLS

### Test Scenarios:

#### Scenario 1: Successful Payment (Mock)
1. On confirmation screen, tap **"Simulate Success"**
2. Wait 5 seconds
3. Order status changes to "confirmed" (paid)
4. "Back to Home" button appears

#### Scenario 2: Failed Payment (Mock)
1. On confirmation screen, tap **"Simulate Failure"**
2. Wait 5 seconds
3. Order status changes to "cancelled"
4. "Back to Home" button appears

#### Scenario 3: Real STK Push (Requires ngrok)
1. Use test number `254708374149`
2. M-Pesa will send STK push to that test number
3. In sandbox, this happens instantly
4. Wait for callback (usually 5-30 seconds)
5. Order status updates automatically

## 📊 How It Works

### Payment Flow:

```
1. User taps "Pay Now"
   ↓
2. Order saved to Supabase (status: pending)
   ↓
3. Backend initiates STK Push to M-Pesa
   ↓
4. User sees confirmation screen
   ↓
5. M-Pesa processes payment
   ↓
6. M-Pesa sends callback to backend
   ↓
7. Backend updates order status in Supabase
   ↓
8. App polls database every 5 seconds
   ↓
9. Status changes to "confirmed" or "cancelled"
   ↓
10. User sees final status
```

### Database Updates:
- **Success**: Order status → `confirmed`, payment record saved
- **Failure**: Order status → `cancelled` with reason

## 🔍 Monitoring & Debugging

### Backend Logs
Watch the backend terminal for detailed logs:
- `📱 Initiating STK push` - Payment started
- `✅ Access token obtained` - Connected to M-Pesa
- `✅ Payment record created` - Saved to database
- `📞 Daraja Callback Received` - M-Pesa responded
- `✅ Payment successful!` - Order confirmed

### Flutter Logs
Watch Flutter debug console for:
- `📱 Initiating M-Pesa STK push...` - Starting payment
- `✅ STK push initiated successfully` - Payment request sent
- `📊 Order status: confirmed` - Payment completed
- `❌ Payment initiation failed` - Error occurred

### Database Checks
Check Supabase dashboard:
- **orders table**: Status should change from `pending` → `confirmed` or `cancelled`
- **payment_methods table**: New M-Pesa payment record

## 🐛 Troubleshooting

### "Failed to connect to payment server"
**Problem**: Flutter can't reach backend
**Solutions**:
- ✅ Check backend is running (`npm start`)
- ✅ Verify URL in `mpesa_service.dart` matches your setup
- ✅ For emulator, use `10.0.2.2` instead of `localhost`
- ✅ For real device, ensure both are on same WiFi network

### "Order not found"
**Problem**: Backend can't find order in database
**Solutions**:
- ✅ Check Supabase connection string in `.env`
- ✅ Verify order was created (check Flutter logs)
- ✅ Check database SSL settings (already configured)

### STK Push not received
**Problem**: No M-Pesa prompt on phone
**Solutions**:
- ✅ Use Safaricom sandbox test numbers only
- ✅ In sandbox, STK push is simulated - use mock buttons
- ✅ For real testing, need ngrok + production credentials

### "Invalid phone number format"
**Problem**: Phone number validation failed
**Solutions**:
- ✅ Use format: `254708374149` or `0708374149`
- ✅ Only Kenyan numbers supported (254/07 prefix)
- ✅ Remove spaces and special characters

## 📱 Production Deployment

When ready for production:

1. **Get Production Credentials** from Safaricom:
   - Apply at https://developer.safaricom.co.ke/
   - Get production Consumer Key, Secret, and Shortcode

2. **Update `.env`**:
   ```env
   MPESA_ENVIRONMENT=production
   MPESA_CONSUMER_KEY=your_production_key
   MPESA_CONSUMER_SECRET=your_production_secret
   MPESA_SHORTCODE=your_production_shortcode
   MPESA_PASSKEY=your_production_passkey
   MPESA_BASE_URL=https://api.safaricom.co.ke
   ```

3. **Deploy Backend** to:
   - Heroku
   - Digital Ocean
   - AWS
   - Or any Node.js hosting

4. **Update Flutter App**:
   ```dart
   static const String baseUrl = 'https://your-production-api.com/api';
   ```

5. **Remove Test Controls**:
   In `mpesa_payment_confirmation_screen.dart`, set:
   ```dart
   bool _isTestMode = false; // Instead of kDebugMode
   ```

## 📝 Important Notes

1. **Sandbox Testing**:
   - Only test numbers work (254708374149, etc.)
   - Callbacks may not trigger (use mock buttons)
   - No actual money is transferred

2. **Security**:
   - Never commit `.env` file to git
   - Use environment variables for production
   - Backend has rate limiting (5 payments/minute)

3. **Database**:
   - Orders are created BEFORE payment
   - If payment fails, order is cancelled
   - Payment records stored in `payment_methods` table

4. **User Experience**:
   - Users see real-time status updates
   - Automatic polling every 5 seconds
   - Clear error messages
   - Test mode indicators in sandbox

## 🎉 You're Ready!

Your M-Pesa integration is complete and ready for testing. The system includes:
- ✅ STK Push payments
- ✅ Real-time status tracking
- ✅ Automatic callback handling
- ✅ Database integration
- ✅ Error handling
- ✅ Test mode for development
- ✅ Production-ready architecture

Start the backend, run your Flutter app, and test away!

## 🆘 Need Help?

Common issues:
1. **Backend won't start**: Run `npm install` first
2. **Flutter can't connect**: Check URL configuration
3. **Payment not working**: Use test numbers only in sandbox
4. **Callbacks not received**: Use mock buttons in test mode

Check backend and Flutter logs for detailed error messages.
