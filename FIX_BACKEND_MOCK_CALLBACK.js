// ============================================================================
// FIX: Disable Mock Callback in server.js
// ============================================================================

/*
ISSUE: Your backend is sending TWO callbacks:
1. Mock callback (automatic, always success) - REMOVE THIS
2. Real M-Pesa callback (from sandbox via ngrok) - KEEP THIS

LOCATION: c:\Users\dorin\mpesa-backend\server.js

FIND AND COMMENT OUT THIS CODE (around line 150-200):

// ❌ REMOVE OR COMMENT OUT THIS SECTION:
// Mock callback simulation
setTimeout(() => {
  console.log('🧪 Mock callback: CheckoutRequestID', checkoutRequestID, 'Success:', true);
  
  // Simulate successful callback
  fetch('http://localhost:3000/api/mpesa/callback', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      Body: {
        stkCallback: {
          ResultCode: 0,
          ResultDesc: "The service request is processed successfully.",
          CallbackMetadata: {
            Item: [
              { Name: "Amount", Value: 1 },
              { Name: "MpesaReceiptNumber", Value: "TEST_MOCK123" },
              { Name: "PhoneNumber", Value: phoneNumber }
            ]
          },
          CheckoutRequestID: checkoutRequestID,
          AccountReference: orderReference
        }
      }
    })
  });
}, 1000);

// ============================================================================
// WHAT TO KEEP:
// ============================================================================

✅ Keep the real callback handler at '/api/mpesa/callback'
✅ Keep ngrok tunnel for receiving real M-Pesa callbacks
✅ Keep the payment record creation
✅ Keep the order creation logic (only when ResultCode === 0)

// ============================================================================
// AFTER FIXING:
// ============================================================================

1. Restart your backend server:
   - Close the npm terminal
   - Run: npm start

2. Test payment flow:
   - Only ONE callback will be received (the real one from M-Pesa)
   - Order only created if payment succeeds
   - No duplicate orders!

*/
