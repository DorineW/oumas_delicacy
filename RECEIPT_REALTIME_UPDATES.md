# Receipt Realtime Updates Implementation

## Overview
Implemented realtime receipt updates following the same pattern as M-Pesa and Orders auto-filling, ensuring receipts appear automatically when generated without manual polling.

## Architecture Pattern

### Similar to MpesaProvider
```
MpesaService → MpesaProvider → UI Components
- Service: Database operations + Supabase .stream()
- Provider: State management + Realtime subscriptions
- UI: Consumer widgets for reactive updates
```

### New ReceiptProvider Pattern
```
ReceiptService → ReceiptProvider → UI Components
- Service: Fetch receipts from database
- Provider: Cache + Realtime subscriptions + Stream listeners
- UI: Consumer<ReceiptProvider> for automatic updates
```

## Implementation Details

### 1. Created ReceiptProvider (`lib/providers/receipt_provider.dart`)

**Features:**
- **Realtime Subscriptions**: Uses `Supabase.stream(primaryKey: ['id'])` like MpesaProvider
- **Multi-layered Caching**: 
  - `_receiptCache`: By transaction ID
  - `_receiptsByOrder`: By order ID (for quick lookups)
  - `_receipts`: Full list for user history
- **Automatic Listening**: Sets up listeners when receipt doesn't exist yet
- **Polling Fallback**: 3-retry polling as backup (like M-Pesa payment checking)
- **Order-Based Lookup**: Links receipts to orders via `mpesa_transactions` table

**Key Methods:**
```dart
// Load receipt for specific order with realtime updates
Future<bool> loadReceiptForOrder(String orderId)

// Listen for receipt creation in realtime
Future<void> _listenForReceiptByOrder(String orderId)

// Get receipt from cache (instant)
Receipt? getReceiptByOrderId(String orderId)

// Manual refresh as fallback
Future<bool> refreshReceiptForOrder(String orderId)

// Load all user receipts with realtime stream
Future<void> loadUserReceipts()
```

### 2. Registered Provider in `main.dart`

```dart
ChangeNotifierProvider(create: (_) => ReceiptProvider()),
```

### 3. Updated Dashboard Screen (`lib/screens/dashboard_screen.dart`)

**Before (Manual Polling Only):**
```dart
// Fetch receipt with 3 retries
final receiptService = ReceiptService();
for (int attempt = 1; attempt <= 3; attempt++) {
  receipt = await receiptService.getReceiptByOrderId(order.id);
  if (receipt != null) break;
  await Future.delayed(const Duration(seconds: 2));
}
```

**After (Realtime + Polling):**
```dart
final receiptProvider = context.read<ReceiptProvider>();

// Load with realtime updates
final hasReceipt = await receiptProvider.loadReceiptForOrder(order.id);

// Fallback polling if not found
if (!hasReceipt) {
  for (int attempt = 1; attempt <= 3; attempt++) {
    await Future.delayed(const Duration(seconds: 2));
    final found = await receiptProvider.refreshReceiptForOrder(order.id);
    if (found) break;
  }
}

// Use Consumer to get updates while dialog is open
showDialog(
  context: context,
  builder: (context) => Consumer<ReceiptProvider>(
    builder: (context, provider, child) {
      final currentReceipt = provider.getReceiptByOrderId(order.id) ?? validReceipt;
      return AlertDialog(...); // Uses currentReceipt throughout
    },
  ),
);
```

## How It Works

### Scenario 1: Receipt Already Exists
1. User taps "View Receipt" button
2. `loadReceiptForOrder()` checks cache → **Found immediately**
3. Dialog shows receipt instantly
4. Consumer continues listening for updates (e.g., if receipt is marked as printed)

### Scenario 2: Receipt Being Generated
1. User taps "View Receipt" right after payment completes
2. `loadReceiptForOrder()` checks database → **Not found yet**
3. Sets up realtime listener: `Supabase.stream().eq('transaction_id', ...)`
4. Falls back to polling: 3 attempts × 2 seconds = 6 seconds max wait
5. **As soon as edge function creates receipt**, Supabase realtime pushes update
6. Provider fetches full receipt (with items) and adds to cache
7. `notifyListeners()` triggers Consumer rebuild
8. Dialog automatically shows receipt (even if still open!)

### Scenario 3: User Browsing History
1. User opens order history
2. Receipts load from cache (instant display)
3. Provider sets up global listener for user's receipts
4. **New receipts auto-appear** as they're generated in background
5. No manual refresh needed

## Database Flow

```
Payment Completes
  ↓
mpesa_transactions.status = 'completed'
  ↓
Edge Function (mpesa-query-status) called
  ↓
generateReceipt() creates:
  - receipts row
  - receipt_items rows
  ↓
Supabase Realtime broadcasts INSERT event
  ↓
ReceiptProvider.stream() receives update
  ↓
Provider fetches full receipt
  ↓
notifyListeners()
  ↓
Consumer<ReceiptProvider> rebuilds
  ↓
UI shows receipt automatically!
```

## Advantages Over Manual Polling

### Old Approach (Manual Polling Only)
- ❌ Fixed 3 retries × 2 seconds = 6 seconds delay
- ❌ Receipt might generate after 6 seconds (user sees error)
- ❌ Must manually retry
- ❌ No updates if dialog already open
- ❌ Wastes database queries even when receipt exists

### New Approach (Realtime + Polling)
- ✅ **Instant** if receipt already exists (cached)
- ✅ **Sub-second** updates when receipt generates
- ✅ Polling as backup (works even if realtime fails)
- ✅ **Auto-updates** while dialog is open
- ✅ Efficient: No queries if cached
- ✅ Scales: Realtime notifications to all users

## Testing

### Test Case 1: Existing Receipt
```
1. Complete payment
2. Wait 10 seconds (receipt generates)
3. Tap "View Receipt"
Expected: Receipt shows IMMEDIATELY (< 100ms)
```

### Test Case 2: Generating Receipt
```
1. Complete payment
2. Immediately tap "View Receipt"
Expected: 
  - Loading dialog shows
  - Receipt appears within 2-6 seconds
  - No errors even if generation takes longer
```

### Test Case 3: Realtime Updates
```
1. Keep receipt dialog open
2. Admin marks receipt as printed (future feature)
Expected: Dialog updates automatically to show "Printed" badge
```

### Test Case 4: Offline/Polling Fallback
```
1. Disable realtime connection (simulate network issues)
2. Complete payment
3. Tap "View Receipt"
Expected: Polling still finds receipt within 6 seconds
```

## Files Modified

1. **Created**: `lib/providers/receipt_provider.dart` (400+ lines)
2. **Updated**: `lib/main.dart` (added provider registration)
3. **Updated**: `lib/screens/dashboard_screen.dart` (replaced polling with realtime)
4. **TODO**: `lib/screens/order_history_screen.dart` (same pattern)
5. **TODO**: `lib/screens/admin/manage_orders_screen.dart` (admin view)

## Performance Benefits

- **Cache Hit**: 0 database queries (instant)
- **First Load**: 1 query to check + 1 query for full receipt = 2 queries
- **Realtime**: 0 additional queries (WebSocket push)
- **Polling Fallback**: Max 3 queries over 6 seconds
- **Traditional Approach**: 3+ queries every time, even if cached

## Future Enhancements

1. **Offline Support**: Cache receipts in SharedPreferences
2. **Print Tracking**: Show "Printed" badge when receipt is marked as printed
3. **Email/Share**: Auto-enable when receipt is available
4. **Receipt History Screen**: Dedicated screen with infinite scroll
5. **PDF Generation**: Download receipt as PDF automatically

## Comparison with M-Pesa Provider

| Feature | MpesaProvider | ReceiptProvider |
|---------|---------------|-----------------|
| Realtime Stream | ✅ | ✅ |
| Polling Fallback | ✅ (3 attempts) | ✅ (3 attempts) |
| Caching | ❌ | ✅ (3 levels) |
| Multi-key Lookup | ❌ | ✅ (by order/transaction) |
| Timeout Handling | ✅ (3 minutes) | ✅ (6 seconds) |
| Status Updates | payment → completed | N/A → created |

## Edge Function Flow

```typescript
// supabase/functions/mpesa-query-status/index.ts

// 1. Query M-Pesa API
const status = await checkMpesaStatus(checkoutRequestId);

// 2. Update database
await supabase
  .from('mpesa_transactions')
  .update({ status: 'completed' })
  .eq('checkout_request_id', checkoutRequestId);

// 3. Generate receipt (THIS IS WHERE REALTIME TRIGGERS)
await generateReceipt(transactionId); // ← Inserts into receipts table

// 4. Supabase Realtime broadcasts INSERT event automatically
// 5. ReceiptProvider.stream() receives it
// 6. UI updates!
```

## Key Takeaway

**Before**: "Receipt is being generated. Please try again in a moment." (manual retry)

**After**: Receipt appears automatically as soon as it's generated, even if the user is already looking at the dialog. This matches how M-Pesa payments auto-update from "pending" to "completed" without manual refresh.
