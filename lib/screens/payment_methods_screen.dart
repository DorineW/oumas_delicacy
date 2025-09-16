import 'package:flutter/material.dart';
import '../constants/colors.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  String _selectedMethod = 'mpesa'; // Default selected method
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _mpesaPhoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-fill with a placeholder or user's saved number if available
    _phoneController.text = '0712 345 678';
    _mpesaPhoneController.text = '0712 345 678';
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _mpesaPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Payment Methods"),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Select Payment Method",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 16),
            
            // Cash on Delivery Option
            _buildPaymentOption(
              title: "Cash on Delivery",
              subtitle: "Pay with cash when your order is delivered",
              value: 'cash',
              icon: Icons.money,
            ),
            
            // Show phone input if cash is selected
            if (_selectedMethod == 'cash') ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number for Delivery Updates',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: AppColors.cardBackground,
                  prefixText: '+254 ',
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
            
            const SizedBox(height: 16),
            
            // M-Pesa Option
            _buildPaymentOption(
              title: "M-Pesa",
              subtitle: "Pay securely via M-Pesa",
              value: 'mpesa',
              icon: Icons.phone_android,
            ),
            
            // Show M-Pesa details if selected
            if (_selectedMethod == 'mpesa') ...[
              const SizedBox(height: 16),
              const Card(
                color: AppColors.cardBackground,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "M-Pesa Till Number",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.darkText,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "123456",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Please use this till number when making payment",
                        style: TextStyle(
                          color: AppColors.darkText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _mpesaPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Your M-Pesa Phone Number',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: AppColors.cardBackground,
                  prefixText: '+254 ',
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
            
            const Spacer(),
            
            // Save Button
            ElevatedButton(
              onPressed: () {
                // Save the selected payment method
                _savePaymentMethod();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Payment method updated successfully"),
                    backgroundColor: AppColors.success,
                  ),
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Save Payment Method'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
  }) {
    return Card(
      color: AppColors.cardBackground,
      child: RadioListTile<String>(
        title: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkText,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.darkText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        value: value,
        groupValue: _selectedMethod,
        activeColor: AppColors.primary,
        onChanged: (String? value) {
          setState(() {
            _selectedMethod = value!;
          });
        },
      ),
    );
  }

  void _savePaymentMethod() {
    // Here you would typically save the payment method to your backend
    if (_selectedMethod == 'cash') {
      print("Saved cash on delivery with phone: ${_phoneController.text}");
    } else if (_selectedMethod == 'mpesa') {
      print("Saved M-Pesa with phone: ${_mpesaPhoneController.text}");
    }
  }
}