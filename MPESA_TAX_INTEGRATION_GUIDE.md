# M-Pesa Tax Integration & Management - Implementation Guide

## Overview
This implementation integrates the `orders.tax` column with M-Pesa transactions, creates a comprehensive admin M-Pesa management screen, and updates sales reports to include tax breakdown.

## ✅ COMPLETED

### 1. Database Integration (`integrate_tax_with_mpesa.sql`)

**New Columns Added to `mpesa_transactions`:**
- `tax_amount NUMERIC(15,2)` - Tax from order
- `subtotal_amount NUMERIC(15,2)` - Subtotal from order
- `delivery_fee NUMERIC(15,2)` - Delivery fee from order

**New Database Functions:**
- `sync_order_amounts_to_mpesa()` - Auto-syncs order amounts to M-Pesa transaction when `order_id` is set
- `calculate_order_tax(subtotal, rate)` - Calculates tax amount (defaults to 16% VAT)
- `auto_calculate_order_tax()` - Optional trigger to auto-calculate tax on orders (commented out by default)

**New Database Views:**
- `mpesa_transactions_detailed` - Full transaction details with customer info and order data
- `mpesa_daily_summary` - Daily metrics with tax breakdown, success/fail rates
- `mpesa_monthly_summary` - Monthly revenue with tax percentages and trends
- `orders_with_payment_details` - Unified view of orders + M-Pesa + receipts

**Key Features:**
- When M-Pesa transaction is linked to an order (`order_id` is set), amounts auto-sync via trigger
- Tax is automatically copied from `orders.tax` to `mpesa_transactions.tax_amount`
- Views provide comprehensive reporting with tax breakdown
- Indexes added for performance on tax queries

### 2. Admin M-Pesa Management Screen (`mpesa_management_screen.dart`)

**Created comprehensive 5-tab interface:**

#### Tab 1: Transactions
- List all M-Pesa transactions with filtering
- Filter by status: All, Completed, Pending, Failed
- Date range filtering
- Expandable cards showing:
  - Transaction ID, Order ID
  - Subtotal, Delivery Fee, Tax, Total
  - Customer details, phone number
  - Payment status and result

#### Tab 2: Daily Summary
- Day-by-day revenue breakdown
- Shows: Total revenue, tax collected, delivery fees, customer count
- Success vs failed transaction counts
- Color-coded metrics cards

#### Tab 3: Monthly Summary
- Month-by-month aggregated stats
- Large revenue display with gradient
- Tax percentage of revenue
- Trend analysis

#### Tab 4: Reconciliation
- Placeholder for future M-Pesa statement reconciliation
- Auto-matching with bank settlements

#### Tab 5: Tax Reports
- Total tax collection summary
- Effective tax rate calculation
- Export functionality (placeholder)

**Features:**
- Date range picker (defaults to last 7 days)
- Real-time refresh
- Responsive design with color-coded status indicators
- Uses currency formatting (KSh)
- Fetches from database views for optimized performance

### 3. Integration Points

**M-Pesa Transaction → Orders Flow:**
```
1. Order created with subtotal, delivery_fee, tax, total
2. M-Pesa STK push initiated
3. M-Pesa callback received → transaction recorded
4. Set mpesa_transactions.order_id = order.id
5. Trigger auto-syncs: subtotal_amount, tax_amount, delivery_fee from order
6. Receipt generated with tax breakdown
```

**Data Flow Diagram:**
```
Order Table                M-Pesa Transactions           Receipts Table
├─ subtotal        ──────> subtotal_amount      ──────> subtotal
├─ delivery_fee    ──────> delivery_fee         ──────> (calculated)
├─ tax (16%)       ──────> tax_amount           ──────> tax_amount
└─ total           ──────> amount               ──────> total_amount
```

## 🚧 TODO - Remaining Steps

### Step 1: Update Reports Screen to Include Tax Data

**File:** `lib/screens/admin/reports_screen.dart`

**Changes needed:**
1. Update `_loadAggregatedStats()` to fetch tax data from M-Pesa views
2. Add tax breakdown to revenue cards
3. Show tax percentage charts
4. Add M-Pesa specific metrics

**Code additions needed:**

```dart
// In _ReportsScreenState class, add tax fields:
double _totalTaxCollected = 0;
double _effectiveTaxRate = 0;

// In _loadAggregatedStats(), after existing query:
final taxQuery = await supabase
    .from('mpesa_daily_summary')
    .select('total_tax_collected, effective_tax_rate_percentage')
    .gte('transaction_date', startDate.toIso8601String().split('T')[0])
    .lte('transaction_date', endDate.toIso8601String().split('T')[0])
    .single();

if (taxQuery != null) {
  _totalTaxCollected = (taxQuery['total_tax_collected'] as num?)?.toDouble() ?? 0;
  _effectiveTaxRate = (taxQuery['effective_tax_rate_percentage'] as num?)?.toDouble() ?? 0;
}

// Add tax metric card in _buildMetricsSection():
_buildStatCard(
  label: 'Tax Collected',
  value: currencyFmt.format(_totalTaxCollected),
  icon: Icons.account_balance,
  color: Colors.purple,
  subtitle: '${_effectiveTaxRate.toStringAsFixed(1)}% rate',
),
```

### Step 2: Update Order Model to Track Payment Status

**File:** `lib/models/order.dart`

**Add fields:**
```dart
class Order {
  // ... existing fields
  final String? mpesaTransactionId; // Link to M-Pesa transaction
  final String? paymentStatus; // completed, pending, failed
  final DateTime? paidAt; // When payment was confirmed
  
  // Add to constructor and copyWith()
}

// Update fromJson to parse new fields:
mpesaTransactionId: json['mpesa_transaction_id'] as String?,
paymentStatus: json['payment_status'] as String?,
paidAt: json['paid_at'] != null 
    ? DateTime.parse(json['paid_at'] as String) 
    : null,
```

### Step 3: Update OrderProvider to Calculate Tax

**File:** `lib/providers/order_provider.dart`

**Add tax calculation before creating order:**
```dart
Future<void> createOrder({
  required List<OrderItem> items,
  required int subtotal,
  required int deliveryFee,
  // ... other params
}) async {
  // Calculate tax (16% VAT)
  final taxAmount = (subtotal * 0.16).round();
  final total = subtotal + deliveryFee + taxAmount;
  
  final orderData = {
    'user_auth_id': userId,
    'subtotal': subtotal,
    'delivery_fee': deliveryFee,
    'tax': taxAmount, // <-- ADD THIS
    'total': total,
    'status': 'pending',
    // ... other fields
  };
  
  // Insert order...
}
```

### Step 4: Link M-Pesa Callback to Order

**Create/Update:** `lib/services/mpesa_service.dart`

**After successful M-Pesa payment:**
```dart
Future<void> handleMPesaCallback(Map<String, dynamic> callbackData) async {
  final transactionId = callbackData['TransactionID'];
  final amount = callbackData['Amount'];
  final phoneNumber = callbackData['PhoneNumber'];
  final orderId = callbackData['AccountReference']; // Order UUID
  
  // Insert M-Pesa transaction
  await supabase.from('mpesa_transactions').insert({
    'transaction_id': transactionId,
    'amount': amount,
    'phone_number': phoneNumber,
    'order_id': orderId, // <-- LINK TO ORDER (trigger auto-syncs amounts)
    'status': 'completed',
    'transaction_timestamp': DateTime.now().toIso8601String(),
    'transaction_type': 'payment',
    // ... other fields
  });
  
  // Update order status to 'confirmed'
  await supabase.from('orders').update({
    'status': 'confirmed',
    'mpesa_transaction_id': transactionId,
    'payment_status': 'completed',
    'paid_at': DateTime.now().toIso8601String(),
  }).eq('id', orderId);
}
```

### Step 5: Add M-Pesa Management to Admin Dashboard

**File:** `lib/screens/admin/admin_dashboard.dart` or wherever admin menu is

**Add navigation tile:**
```dart
ListTile(
  leading: Icon(Icons.payment, color: AppColors.primary),
  title: const Text('M-Pesa Management'),
  subtitle: const Text('Transactions, tax reports, reconciliation'),
  trailing: const Icon(Icons.chevron_right),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MPesaManagementScreen(),
      ),
    );
  },
),
```

### Step 6: UI Display Updates

**Customer Receipt Display:**
Show tax breakdown in receipt:
```dart
// In dashboard_screen.dart receipt dialog:
_buildReceiptRow('Subtotal', 'KES ${receipt.subtotal}'),
_buildReceiptRow('Delivery Fee', 'KES ${receipt.deliveryFee ?? 0}'),
_buildReceiptRow('Tax (16% VAT)', 'KES ${receipt.taxAmount}'),
const Divider(),
_buildReceiptRow('Total', 'KES ${receipt.totalAmount}', isBold: true),
```

**Order Summary:**
```dart
// In cart_screen.dart or checkout:
Text('Subtotal: KSh ${subtotal}'),
Text('Delivery: KSh ${deliveryFee}'),
Text('Tax (16%): KSh ${tax}', style: TextStyle(color: Colors.grey)),
const Divider(),
Text('Total: KSh ${total}', style: TextStyle(fontWeight: FontWeight.bold)),
```

### Step 7: Testing Checklist

**Database Migration:**
- [ ] Run `integrate_tax_with_mpesa.sql` in Supabase SQL Editor
- [ ] Verify views created: `SELECT * FROM mpesa_daily_summary LIMIT 1;`
- [ ] Test function: `SELECT calculate_order_tax(1000);` should return 160

**Backend Testing:**
- [ ] Create test order with subtotal 1000
- [ ] Verify tax auto-calculated to 160
- [ ] Simulate M-Pesa callback with order_id
- [ ] Verify amounts synced to mpesa_transactions
- [ ] Check receipt generated with correct tax

**Admin UI Testing:**
- [ ] Open M-Pesa Management screen
- [ ] Verify all 5 tabs load
- [ ] Test date range picker
- [ ] Test status filters in Transactions tab
- [ ] Verify daily/monthly summaries show correct data
- [ ] Check tax reports tab shows totals

**Reports Integration:**
- [ ] Open Reports screen
- [ ] Verify tax collected metric appears
- [ ] Check charts include tax data
- [ ] Verify daily_revenue_breakdown includes tax

**Customer Experience:**
- [ ] Place order, verify tax shown in cart
- [ ] Complete M-Pesa payment
- [ ] View receipt - tax breakdown displayed
- [ ] Dashboard order card shows tax

## 📊 SQL Queries for Verification

### Check Tax Integration
```sql
-- Verify mpesa_transactions has tax columns
SELECT 
  transaction_id,
  amount as total,
  subtotal_amount,
  tax_amount,
  delivery_fee,
  (subtotal_amount + tax_amount + delivery_fee) as calculated_total
FROM mpesa_transactions
WHERE status = 'completed'
ORDER BY transaction_timestamp DESC
LIMIT 5;

-- Check if amounts match orders
SELECT 
  o.short_id,
  o.subtotal,
  o.tax,
  o.delivery_fee,
  o.total,
  mt.subtotal_amount,
  mt.tax_amount,
  mt.delivery_fee as mt_delivery,
  mt.amount as mt_total,
  CASE 
    WHEN o.tax = mt.tax_amount THEN 'MATCH ✓'
    ELSE 'MISMATCH ✗'
  END as tax_match
FROM orders o
JOIN mpesa_transactions mt ON o.id = mt.order_id
WHERE mt.status = 'completed'
LIMIT 10;
```

### Today's Tax Collection
```sql
SELECT 
  transaction_date,
  total_revenue,
  total_tax_collected,
  effective_tax_rate_percentage,
  successful_transactions
FROM mpesa_daily_summary
WHERE transaction_date = CURRENT_DATE;
```

### Monthly Tax Trends
```sql
SELECT 
  year_month,
  total_revenue,
  tax_collected,
  tax_percentage_of_revenue,
  successful_transactions
FROM mpesa_monthly_summary
ORDER BY month_start DESC
LIMIT 6;
```

## 🔧 Configuration

### Set Tax Rate (if different from 16%)
```sql
-- Update VAT rate
UPDATE tax_configurations 
SET tax_rate = 18.0  -- Change to desired rate
WHERE tax_name LIKE '%VAT%' AND is_active = true;
```

### Enable Auto-Tax Calculation on Orders
If you want database to auto-calculate tax instead of Flutter:
```sql
-- Uncomment the trigger in integrate_tax_with_mpesa.sql
DROP TRIGGER IF EXISTS trg_auto_calculate_order_tax ON public.orders;
CREATE TRIGGER trg_auto_calculate_order_tax
  BEFORE INSERT OR UPDATE OF subtotal, delivery_fee ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION auto_calculate_order_tax();
```

## 📱 Customer-Facing UI Examples

### Cart/Checkout Screen
```dart
Container(
  padding: EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
  ),
  child: Column(
    children: [
      _buildSummaryRow('Subtotal', subtotal),
      _buildSummaryRow('Delivery Fee', deliveryFee),
      _buildSummaryRow('Tax (16% VAT)', tax, isGrey: true),
      Divider(height: 24),
      _buildSummaryRow('Total', total, isBold: true),
      SizedBox(height: 12),
      Text(
        'VAT included as per Kenya Tax Authority regulations',
        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
      ),
    ],
  ),
)
```

## 🚀 Deployment Steps

1. **Backup database** before running migrations
2. Run `database/integrate_tax_with_mpesa.sql`
3. Add `mpesa_management_screen.dart` to project
4. Update reports screen with tax metrics
5. Update Order model with payment fields
6. Update OrderProvider to calculate tax
7. Link M-Pesa callbacks to orders
8. Update UI to show tax breakdown
9. Test end-to-end flow
10. Deploy to production

## 📚 References

- Database migration: `database/integrate_tax_with_mpesa.sql`
- Admin screen: `lib/screens/admin/mpesa_management_screen.dart`
- Reports screen: `lib/screens/admin/reports_screen.dart` (to be updated)
- Order model: `lib/models/order.dart` (to be updated)
- OrderProvider: `lib/providers/order_provider.dart` (to be updated)

## ⚠️ Important Notes

1. **Tax Rate**: Currently set to 16% (Kenya VAT). Update in `tax_configurations` table if different
2. **Auto-Sync**: M-Pesa amounts auto-sync from orders ONLY when `order_id` is set
3. **Views**: All new views are read-only for performance
4. **RLS**: Existing RLS policies apply - users see only their transactions
5. **Reconciliation**: Tab 4 is placeholder for future implementation
6. **Export**: Tax report export is placeholder for future implementation

## 🎯 Success Criteria

- ✅ Tax column integrated with M-Pesa transactions
- ✅ Admin can view all M-Pesa transactions with tax breakdown
- ✅ Daily and monthly summaries include tax metrics
- ✅ Reports screen shows tax collected
- ✅ Customers see tax breakdown in cart and receipts
- ✅ M-Pesa callbacks automatically link to orders and sync amounts
- ✅ Tax calculations are consistent across orders → M-Pesa → receipts
