import 'package:flutter/material.dart';
import '../constants/colors.dart';

class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Payment Methods'),
          backgroundColor: AppColors.primary,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.white),
          titleTextStyle: const TextStyle(
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _PaymentMethodCard(
              icon: Icons.credit_card,
              title: 'Credit Card',
              subtitle: '**** **** **** 1234',
              isDefault: true,
            ),
            const SizedBox(height: 12),
            const _PaymentMethodCard(
              icon: Icons.account_balance,
              title: 'Bank Account',
              subtitle: 'ABC Bank - ****5678',
              isDefault: false,
            ),
            const SizedBox(height: 12),
            const _PaymentMethodCard(
              icon: Icons.phone_android,
              title: 'M-Pesa',
              subtitle: '+254 712 345 678',
              isDefault: false,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                // Add payment method
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Payment Method'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDefault;

  const _PaymentMethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDefault,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: isDefault
            ? Border.all(color: AppColors.primary, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.darkText.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          if (isDefault)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Default',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}