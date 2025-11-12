# Orders and Payment Methods - Troubleshooting Guide

## Issue Description
Orders are not loading in the order history screen after payment is completed via M-Pesa.

## Root Cause Analysis

### 1. **Missing Relationship (Minor Issue)**
- The `orders` table doesn't have a `payment_method_id` column
- This isn't critical but makes it hard to audit which payment was used for which order

### 2. **RLS Policies (MAJOR Issue)**
Your `orders` table has Row Level Security (RLS) enabled, which restricts data access based on policies. The current policies may be:
- Too restrictive
- Not allowing the backend service to insert orders after payment
- Not properly configured for your app's authentication flow

### 3. **Order Creation Flow**
Based on your code:
1. User initiates M-Pesa payment (no order created yet)
2. Order details are temporarily stored in `payment_methods.metadata`
3. Backend receives M-Pesa callback
4. Backend creates order in database
5. App polls backend to check if order was created
6. **PROBLEM**: Order might be created but RLS policies prevent user from seeing it

## Solution Steps

### Step 1: Run Diagnostic Script
Execute `diagnose_orders_payment_issue.sql` in your Supabase SQL Editor to identify:
- Are orders being created?
- Do they have valid `user_auth_id` values?
- Are RLS policies blocking access?

### Step 2: Apply Fix
Execute `fix_orders_payment_relationship.sql` to:
- Add `payment_method_id` column (optional but recommended)
- Fix RLS policies to properly allow:
  - Service role (backend) to insert orders
  - Users to view their own orders
  - Admins to view all orders
  - Riders to view assigned orders

### Step 3: Verify Backend Configuration
Check your backend (Node.js server) is using the **Service Role Key** (not anon key) when creating orders after payment. Example:

```javascript
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY // ← Should use service role key
)
```

### Step 4: Check User ID Matching
Ensure the `user_auth_id` being saved in orders matches the authenticated user's ID:

**In your Flutter app:**
```dart
final userId = Supabase.instance.client.auth.currentUser?.id;
```

**In your backend when creating order:**
```javascript
user_auth_id: userId // Must match the auth.uid() from Supabase Auth
```

## Common Issues & Solutions

### Issue 1: Orders Created But Not Visible
**Symptom**: Orders exist in database but don't show in app
**Cause**: RLS policies blocking SELECT
**Solution**: Run `fix_orders_payment_relationship.sql`

### Issue 2: Backend Can't Create Orders
**Symptom**: 403 Forbidden or permission denied errors
**Cause**: Backend not using service role key
**Solution**: Update backend to use `SUPABASE_SERVICE_ROLE_KEY`

### Issue 3: Wrong User ID
**Symptom**: Orders created with different `user_auth_id` than expected
**Cause**: Backend using wrong user ID from payment metadata
**Solution**: Ensure `userId` passed to backend matches Supabase Auth ID

### Issue 4: payment_methods.metadata Not Cleared
**Symptom**: Old order data lingering in payment_methods
**Cause**: Backend not clearing metadata after order creation
**Solution**: Add cleanup logic in backend:
```javascript
// After creating order successfully
await supabase
  .from('payment_methods')
  .update({ metadata: null })
  .eq('id', paymentMethodId);
```

## Testing After Fix

### 1. Test Order Creation
```sql
-- Check latest order
SELECT o.id, o.user_auth_id, o.status, o.total, u.name
FROM orders o
LEFT JOIN users u ON o.user_auth_id = u.auth_id
ORDER BY o.placed_at DESC
LIMIT 1;
```

### 2. Test Order Visibility (as user)
In your Flutter app:
```dart
final orders = await Supabase.instance.client
  .from('orders')
  .select('*, order_items(*), users!fk_orders_user_auth(name)')
  .eq('user_auth_id', userId)
  .order('placed_at', ascending: false);
  
print('Orders count: ${orders.length}');
```

### 3. Check RLS Policies
```sql
SELECT policyname, cmd, roles
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'orders';
```

## Database Schema Changes

### New Column Added
```sql
ALTER TABLE orders ADD COLUMN payment_method_id UUID;
```

### Foreign Key Added
```sql
ALTER TABLE orders
ADD CONSTRAINT fk_orders_payment_method
FOREIGN KEY (payment_method_id)
REFERENCES payment_methods(id)
ON DELETE SET NULL;
```

### RLS Policies Created
- ✅ Service role can insert orders
- ✅ Users can insert/select/update their own orders  
- ✅ Admins can view/update all orders
- ✅ Riders can view/update assigned orders

## Debugging Commands

### Check if order exists for specific user
```sql
SELECT * FROM orders WHERE user_auth_id = 'YOUR_USER_ID';
```

### Check RLS is enabled
```sql
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'orders';
```

### Test as specific user (in SQL Editor)
```sql
SET LOCAL role TO authenticated;
SET LOCAL request.jwt.claim.sub TO 'USER_AUTH_ID';
SELECT * FROM orders;
```

## Next Steps

1. ✅ Run diagnostic script
2. ✅ Apply fix migration
3. ⏳ Test order creation with M-Pesa payment
4. ⏳ Verify orders appear in order history
5. ⏳ Check all user roles (customer, admin, rider) can access appropriate orders

## Support

If issues persist after applying these fixes:
1. Check backend logs for errors
2. Check Flutter app logs for Supabase errors
3. Verify M-Pesa callback is reaching your backend
4. Confirm order is actually being created in database
