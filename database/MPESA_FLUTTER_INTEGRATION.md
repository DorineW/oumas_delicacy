# M-Pesa Flutter Integration Guide

Complete guide for integrating M-Pesa STK Push into your Flutter app.

## 📦 Required Packages

Add to your `pubspec.yaml`:
```yaml
dependencies:
  supabase_flutter: ^2.0.0
  http: ^1.1.0
```

## 🏗️ Implementation

### 1. Create M-Pesa Service

Create `lib/services/mpesa_service.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class MpesaService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Initiate M-Pesa STK Push
  Future<Map<String, dynamic>> initiatePayment({
    required String phoneNumber,
    required int amount,
    String? orderId,
    required String accountReference,
    String? transactionDesc,
  }) async {
    try {
      print('🔄 Initiating M-Pesa payment...');
      print('Phone: $phoneNumber, Amount: $amount');

      final response = await _supabase.functions.invoke(
        'mpesa-stk-push',
        body: {
          'phoneNumber': phoneNumber,
          'amount': amount,
          'orderId': orderId,
          'accountReference': accountReference,
          'transactionDesc': transactionDesc ?? 'Payment for order $accountReference',
        },
      );

      if (response.status != 200) {
        throw Exception('Failed to initiate payment: ${response.data}');
      }

      final data = response.data as Map<String, dynamic>;
      
      if (data['success'] == true) {
        print('✅ STK Push sent successfully');
        return {
          'success': true,
          'message': data['message'],
          'checkoutRequestId': data['checkoutRequestId'],
          'merchantRequestId': data['merchantRequestId'],
          'transactionId': data['transactionId'],
        };
      } else {
        throw Exception(data['error'] ?? 'Payment initiation failed');
      }
    } catch (e) {
      print('❌ Payment error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Check payment status by polling the database
  Future<String?> checkPaymentStatus(String checkoutRequestId) async {
    try {
      final response = await _supabase
          .from('mpesa_transactions')
          .select('status, result_desc')
          .eq('checkout_request_id', checkoutRequestId)
          .single();

      return response['status'] as String?;
    } catch (e) {
      print('Error checking payment status: $e');
      return null;
    }
  }

  /// Listen to payment status changes in real-time
  Stream<String> listenToPaymentStatus(String checkoutRequestId) {
    return _supabase
        .from('mpesa_transactions')
        .stream(primaryKey: ['id'])
        .eq('checkout_request_id', checkoutRequestId)
        .map((data) {
          if (data.isEmpty) return 'pending';
          return data.first['status'] as String;
        });
  }

  /// Get user's transaction history
  Future<List<Map<String, dynamic>>> getUserTransactions() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('mpesa_transactions')
          .select()
          .eq('user_auth_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching transactions: $e');
      return [];
    }
  }

  /// Get receipt for a transaction
  Future<Map<String, dynamic>?> getReceipt(String transactionId) async {
    try {
      final response = await _supabase
          .from('receipts')
          .select('''
            *,
            receipt_items(*)
          ''')
          .eq('transaction_id', transactionId)
          .single();

      return response;
    } catch (e) {
      print('Error fetching receipt: $e');
      return null;
    }
  }
}
```

### 2. Create Payment Provider

Create `lib/providers/mpesa_provider.dart`:

```dart
import 'package:flutter/foundation.dart';
import '../services/mpesa_service.dart';

class MpesaProvider with ChangeNotifier {
  final MpesaService _mpesaService = MpesaService();

  bool _isProcessing = false;
  String? _checkoutRequestId;
  String _paymentStatus = 'idle'; // idle, pending, completed, failed
  String? _errorMessage;

  bool get isProcessing => _isProcessing;
  String get paymentStatus => _paymentStatus;
  String? get errorMessage => _errorMessage;

  /// Initiate M-Pesa payment
  Future<bool> initiatePayment({
    required String phoneNumber,
    required int amount,
    String? orderId,
    required String accountReference,
  }) async {
    _isProcessing = true;
    _errorMessage = null;
    _paymentStatus = 'pending';
    notifyListeners();

    try {
      final result = await _mpesaService.initiatePayment(
        phoneNumber: phoneNumber,
        amount: amount,
        orderId: orderId,
        accountReference: accountReference,
      );

      if (result['success'] == true) {
        _checkoutRequestId = result['checkoutRequestId'];
        
        // Start listening to payment status
        _listenToPaymentStatus();
        
        return true;
      } else {
        _errorMessage = result['error'] ?? 'Payment initiation failed';
        _paymentStatus = 'failed';
        _isProcessing = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _paymentStatus = 'failed';
      _isProcessing = false;
      notifyListeners();
      return false;
    }
  }

  /// Listen to payment status changes
  void _listenToPaymentStatus() {
    if (_checkoutRequestId == null) return;

    _mpesaService.listenToPaymentStatus(_checkoutRequestId!).listen(
      (status) {
        _paymentStatus = status;
        
        if (status == 'completed' || status == 'failed') {
          _isProcessing = false;
        }
        
        notifyListeners();
      },
      onError: (error) {
        _errorMessage = error.toString();
        _paymentStatus = 'failed';
        _isProcessing = false;
        notifyListeners();
      },
    );
  }

  /// Reset payment state
  void reset() {
    _isProcessing = false;
    _checkoutRequestId = null;
    _paymentStatus = 'idle';
    _errorMessage = null;
    notifyListeners();
  }
}
```

### 3. Update Checkout Screen

Add M-Pesa payment button to your checkout screen:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/mpesa_provider.dart';

class MpesaPaymentButton extends StatefulWidget {
  final String phoneNumber;
  final int amount;
  final String orderId;
  final String orderReference;
  final VoidCallback onSuccess;

  const MpesaPaymentButton({
    Key? key,
    required this.phoneNumber,
    required this.amount,
    required this.orderId,
    required this.orderReference,
    required this.onSuccess,
  }) : super(key: key);

  @override
  State<MpesaPaymentButton> createState() => _MpesaPaymentButtonState();
}

class _MpesaPaymentButtonState extends State<MpesaPaymentButton> {
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.phoneNumber;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _showPaymentDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PaymentDialog(
        phoneNumber: _phoneController.text,
        amount: widget.amount,
        orderId: widget.orderId,
        orderReference: widget.orderReference,
        onSuccess: widget.onSuccess,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _showPaymentDialog(context),
      icon: const Icon(Icons.phone_android),
      label: const Text('Pay with M-Pesa'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _PaymentDialog extends StatefulWidget {
  final String phoneNumber;
  final int amount;
  final String orderId;
  final String orderReference;
  final VoidCallback onSuccess;

  const _PaymentDialog({
    required this.phoneNumber,
    required this.amount,
    required this.orderId,
    required this.orderReference,
    required this.onSuccess,
  });

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  @override
  void initState() {
    super.initState();
    _initiatePayment();
  }

  Future<void> _initiatePayment() async {
    final mpesaProvider = context.read<MpesaProvider>();
    
    final success = await mpesaProvider.initiatePayment(
      phoneNumber: widget.phoneNumber,
      amount: widget.amount,
      orderId: widget.orderId,
      accountReference: widget.orderReference,
    );

    if (!success) {
      // Show error and close dialog
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mpesaProvider.errorMessage ?? 'Payment failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MpesaProvider>(
      builder: (context, mpesaProvider, child) {
        final status = mpesaProvider.paymentStatus;

        // Handle payment completion
        if (status == 'completed') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pop();
            widget.onSuccess();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Payment successful!'),
                backgroundColor: Colors.green,
              ),
            );
          });
        }

        // Handle payment failure
        if (status == 'failed') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(mpesaProvider.errorMessage ?? '❌ Payment failed'),
                backgroundColor: Colors.red,
              ),
            );
            mpesaProvider.reset();
          });
        }

        return AlertDialog(
          title: const Text('M-Pesa Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (status == 'pending') ...[
                const CircularProgressIndicator(color: Colors.green),
                const SizedBox(height: 20),
                const Text(
                  'Check your phone for M-Pesa prompt',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 10),
                Text(
                  'KSh ${widget.amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Enter your M-Pesa PIN to complete payment',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                mpesaProvider.reset();
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
}
```

### 4. Register Provider

Add to your `main.dart`:

```dart
MultiProvider(
  providers: [
    // ... your existing providers
    ChangeNotifierProvider(create: (_) => MpesaProvider()),
  ],
  child: MyApp(),
)
```

### 5. Usage in Checkout

```dart
MpesaPaymentButton(
  phoneNumber: userPhone,
  amount: totalAmount.toInt(),
  orderId: orderId,
  orderReference: orderShortId,
  onSuccess: () {
    // Navigate to success page
    Navigator.pushReplacementNamed(context, '/order-success');
  },
)
```

## 🔍 Testing Flow

1. **User clicks "Pay with M-Pesa"**
2. **STK Push sent to phone** - Shows loading dialog
3. **User enters PIN on phone** - Dialog shows "waiting for confirmation"
4. **Payment confirmed** - Dialog closes, success message shown
5. **Order updated** - Status changes to 'paid'
6. **Receipt generated** - Automatically created in database
7. **Email sent** - Receipt emailed to customer

## 📊 Transaction Monitoring

View transactions in your admin panel:

```dart
// Get user transactions
final mpesaService = MpesaService();
final transactions = await mpesaService.getUserTransactions();

// Display in list
ListView.builder(
  itemCount: transactions.length,
  itemBuilder: (context, index) {
    final tx = transactions[index];
    return ListTile(
      leading: Icon(
        tx['status'] == 'completed' ? Icons.check_circle : Icons.pending,
        color: tx['status'] == 'completed' ? Colors.green : Colors.orange,
      ),
      title: Text('KSh ${tx['amount']}'),
      subtitle: Text(tx['transaction_id'] ?? 'Pending'),
      trailing: Text(tx['status']),
    );
  },
)
```

## 🔒 Security Notes

- ✅ Phone numbers auto-formatted (0712... → 254712...)
- ✅ JWT authentication required
- ✅ RLS policies prevent unauthorized access
- ✅ Service role used for database updates
- ✅ All amounts validated server-side

## 🐛 Troubleshooting

**"Check your phone" message but no prompt**
- Verify phone number format
- Check M-Pesa credentials in Supabase secrets
- Ensure sufficient M-Pesa balance for testing

**Payment succeeds but order not updated**
- Check callback URL is registered with Safaricom
- View function logs: `supabase functions logs mpesa-callback`
- Verify RLS policies allow updates

**Timeout waiting for payment**
- Default timeout: 30 seconds
- User may have cancelled on phone
- Check transaction status in database

## 📱 Sandbox Testing

Use Safaricom test credentials:
- **Phone**: 254708374149 (or your registered test number)
- **PIN**: Any 4 digits (sandbox doesn't validate)

## 🚀 Production Checklist

- [ ] Switch to production M-Pesa credentials
- [ ] Update API URLs in Edge Functions
- [ ] Register production callback URL
- [ ] Test with real small amounts
- [ ] Set up payment reconciliation
- [ ] Monitor transaction fees
- [ ] Set up alerts for failed payments

## 📚 Additional Features

- **Retry failed payments**: Store checkout request ID, retry later
- **Payment history**: Show user's past transactions
- **Receipt download**: Generate PDF from receipt data
- **Refunds**: Implement M-Pesa reversal API
- **Analytics**: Track payment success rates
