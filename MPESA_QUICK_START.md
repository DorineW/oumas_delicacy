# 🚀 Quick Start - M-Pesa Testing

## Start Backend
```powershell
cd c:\Users\dorin\mpesa-backend
npm install
npm start
```

## Run Flutter App
```powershell
cd c:\Users\dorin\oumas_delicacy
flutter run
```

## Test Payment Flow

### 1. In Flutter App:
- Add items to cart
- Go to checkout
- Fill in:
  - **Contact phone**: Any number
  - **M-Pesa phone**: `0708374149` (test number)
  - **Address** (if delivery)
- Tap "Pay Now"

### 2. On Payment Screen:
- See "Waiting for Payment" message
- Use **TEST CONTROLS**:
  - Tap "Simulate Success" → Order confirmed ✅
  - Tap "Simulate Failure" → Order cancelled ❌

## Important URLs

### Flutter Service URL (Android Emulator)
In `lib/services/mpesa_service.dart`:
```dart
static const String baseUrl = 'http://10.0.2.2:3000/api';
```

### Flutter Service URL (Real Device on Same WiFi)
Find your PC IP: `ipconfig` → Look for IPv4 Address (e.g., 192.168.1.100)
```dart
static const String baseUrl = 'http://192.168.1.100:3000/api';
```

## Test Numbers (Sandbox)
- ✅ **254708374149** - Success
- ❌ **254700000000** - Failure
- 📞 **254712345678** - General

## Backend API Endpoints
- POST `/api/payments/initiate-stk` - Start payment
- POST `/api/payments/query-stk-status` - Check status
- POST `/api/payments/callback` - M-Pesa callback
- POST `/api/payments/mock-callback` - Test callback
- GET `/api/orders/:orderId/status` - Order status
- GET `/health` - Health check

## Check If Backend Is Running
Open browser: http://localhost:3000/health

Should see:
```json
{
  "status": "ok",
  "environment": "sandbox",
  "timestamp": "2025-11-12T..."
}
```

## Troubleshooting

### Can't connect from Flutter
1. Backend running? → `npm start`
2. Correct URL? → Check `mpesa_service.dart`
3. Emulator? → Use `10.0.2.2:3000`
4. Real device? → Same WiFi + correct IP

### Payment not working
1. Using test number? → `0708374149`
2. Backend shows logs? → Should see "Initiating STK push"
3. In sandbox? → Use mock buttons

### Order not updating
1. Check backend terminal for callback logs
2. Use mock buttons in test mode
3. Check Supabase orders table

## See Full Guide
Read `MPESA_SETUP_GUIDE.md` for complete documentation.
