import 'package:flutter/material.dart';
import '../constants/colors.dart';

class TermsConditionsDialog extends StatelessWidget {
  const TermsConditionsDialog({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const TermsConditionsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.lightGray,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.description,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Terms & Conditions',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkText,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      color: AppColors.darkText,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLastUpdated(),
                      const SizedBox(height: 24),
                      _buildSection(
                        '1. Introduction & Acceptance of Terms',
                        [
                          'Welcome to Ouma\'s Delicacy ("App," "Service," "we," "us," or "our"). By accessing, downloading, or using this mobile application, you ("User," "you," or "your") agree to be legally bound by these Terms and Conditions ("Terms," "Agreement").',
                          'If you do not agree to these Terms, you must immediately discontinue use of the App.',
                          'These Terms constitute a binding legal agreement between you and Ouma\'s Delicacy.',
                        ],
                      ),
                      _buildSection(
                        '2. Definitions',
                        [
                          '"App" refers to the Ouma\'s Delicacy mobile application and all associated services.',
                          '"User" means any person who accesses or uses the App.',
                          '"Order" means a request placed by a User for food products through the App.',
                          '"Restaurant Partner" means third-party food establishments offering products via the App.',
                          '"Delivery Rider" means independent contractors who fulfill delivery services.',
                          '"Content" includes all text, images, graphics, and data displayed in the App.',
                        ],
                      ),
                      _buildSection(
                        '3. Account Registration & Security',
                        [
                          '3.1 Eligibility: You must be at least 18 years of age to create an account and use this Service.',
                          '3.2 Accurate Information: You agree to provide true, accurate, current, and complete information during registration and to update such information to maintain its accuracy.',
                          '3.3 Account Security: You are solely responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account.',
                          '3.4 One Account Per Person: Each User may maintain only one account. Multiple accounts are prohibited.',
                          '3.5 Account Termination: We reserve the right to suspend or terminate your account at our sole discretion if you violate these Terms.',
                        ],
                      ),
                      _buildSection(
                        '4. Description of Services',
                        [
                          '4.1 Platform Role: Ouma\'s Delicacy operates as a technology platform that connects Users with Restaurant Partners and Delivery Riders.',
                          '4.2 Not a Food Provider: We are NOT a restaurant, food preparer, food handler, or food transporter. We do not prepare, cook, package, or directly deliver any food products.',
                          '4.3 Third-Party Services: All food preparation is performed by independent Restaurant Partners. All delivery services are performed by independent Delivery Riders.',
                          '4.4 No Warranty of Service: We do not guarantee the availability, quality, safety, or timeliness of services provided by Restaurant Partners or Delivery Riders.',
                        ],
                      ),
                      _buildSection(
                        '5. Placing Orders & Pricing',
                        [
                          '5.1 Order Placement: Orders are placed through the App and are subject to acceptance by the Restaurant Partner.',
                          '5.2 Order Confirmation: An Order is confirmed only upon successful payment processing and acceptance by the Restaurant Partner.',
                          '5.3 Pricing: All prices are listed in Kenya Shillings (KSh) and include applicable Value Added Tax (VAT) of 16%.',
                          '5.4 Additional Fees: Orders may be subject to delivery fees, service fees, and small order fees as displayed during checkout.',
                          '5.5 Price Changes: Prices are subject to change without notice. The price applicable to your Order is the price displayed at the time of Order placement.',
                        ],
                      ),
                      _buildSection(
                        '6. Payment & Billing',
                        [
                          '6.1 Payment Methods: We accept payment via M-Pesa and other methods as indicated in the App.',
                          '6.2 Authorization: By placing an Order, you authorize us to charge your selected payment method for the total Order amount, including all fees and taxes.',
                          '6.3 Payment Timeout: You must complete payment within 2 minutes of Order confirmation. Failure to do so will result in automatic Order cancellation.',
                          '6.4 Payment Confirmation: You will receive payment confirmation via SMS or in-app notification.',
                          '6.5 Promotions & Credits: Promotional codes, discounts, and credits are subject to specific terms and conditions and may expire without notice.',
                        ],
                      ),
                      _buildSection(
                        '7. Cancellations & Refunds',
                        [
                          '7.1 User Cancellation: You may cancel an Order before the Restaurant Partner confirms it (typically within 5 minutes of Order placement).',
                          '7.2 Refund Policy: Approved refunds will be processed within 5-7 business days to your original M-Pesa number or payment method.',
                          '7.3 Partial Refunds: We reserve the right to issue partial refunds for partial Order issues at our sole discretion.',
                          '7.4 No Refund After Delivery: Perishable food items cannot be returned or refunded after 24 hours of delivery.',
                          '7.5 Issue Reporting: You must report any Order issues within 2 hours of delivery to be eligible for a refund or credit.',
                        ],
                      ),
                      _buildSection(
                        '8. User Conduct & Prohibited Activities',
                        [
                          '8.1 You agree NOT to: (a) Place fraudulent Orders or initiate chargebacks for completed Orders; (b) Harass, abuse, or threaten Delivery Riders, Restaurant Partners, or our staff; (c) Misuse promotional codes or discounts; (d) Share or transfer your account to another person; (e) Use the App for any illegal or unauthorized purpose.',
                          '8.2 Violation Consequences: Violation of these prohibitions may result in immediate account suspension or termination, forfeiture of credits, and potential legal action.',
                          '8.3 We reserve the right to refuse service to anyone for any reason at any time.',
                        ],
                      ),
                      _buildSection(
                        '9. Food Safety & Allergies',
                        [
                          '9.1 Restaurant Responsibility: All food safety standards and compliance are the sole responsibility of the Restaurant Partner.',
                          '9.2 Inspection Requirement: You agree to inspect all food items immediately upon delivery.',
                          '9.3 Allergen Disclosure: We are NOT liable for allergic reactions if you did not disclose your allergies to the Restaurant Partner when placing your Order.',
                          '9.4 Dietary Restrictions: It is your responsibility to communicate any dietary restrictions, allergies, or preferences to the Restaurant Partner.',
                        ],
                      ),
                      _buildSection(
                        '10. Intellectual Property',
                        [
                          '10.1 Ownership: All intellectual property rights in the App, including but not limited to trademarks, logos, design, text, graphics, software, and source code, are owned by or licensed to Ouma\'s Delicacy.',
                          '10.2 License to Use: We grant you a limited, non-exclusive, non-transferable, revocable license to use the App for personal, non-commercial purposes.',
                          '10.3 Restrictions: You may not copy, modify, distribute, sell, or create derivative works from any part of the App without our prior written consent.',
                        ],
                      ),
                      _buildSection(
                        '11. User-Generated Content',
                        [
                          '11.1 License Grant: By submitting reviews, ratings, photos, or comments ("User Content"), you grant us a worldwide, perpetual, royalty-free license to use, display, reproduce, and distribute such Content.',
                          '11.2 Content Ownership: You represent and warrant that you own or have the necessary rights to submit User Content and that it does not violate any third-party rights.',
                          '11.3 Content Removal: We reserve the right to remove any User Content that violates these Terms or is otherwise objectionable at our sole discretion.',
                        ],
                      ),
                      _buildSection(
                        '12. Limitation of Liability',
                        [
                          '12.1 DISCLAIMER: TO THE MAXIMUM EXTENT PERMITTED BY LAW, OUMA\'S DELICACY SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES ARISING FROM YOUR USE OF THE APP.',
                          '12.2 Service Limitations: We are not responsible for: (a) Late or failed deliveries due to traffic, weather, or circumstances beyond our control; (b) Incorrect Orders, food quality, or preparation issues caused by Restaurant Partners; (c) Actions or omissions of Delivery Riders.',
                          '12.3 Maximum Liability: Our total liability for any claim arising from your use of the App shall not exceed the amount you paid for the specific Order giving rise to the claim.',
                        ],
                      ),
                      _buildSection(
                        '13. Disclaimer of Warranties',
                        [
                          '13.1 AS-IS BASIS: THE APP AND ALL SERVICES ARE PROVIDED ON AN "AS IS" AND "AS AVAILABLE" BASIS WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED.',
                          '13.2 No Guarantee: We do not warrant that the App will be uninterrupted, error-free, secure, or free from viruses or other harmful components.',
                          '13.3 Third-Party Services: We disclaim all liability for the acts or omissions of Restaurant Partners and Delivery Riders.',
                        ],
                      ),
                      _buildSection(
                        '14. Indemnification',
                        [
                          'You agree to indemnify, defend, and hold harmless Ouma\'s Delicacy, its officers, directors, employees, and agents from any claims, losses, damages, liabilities, costs, or expenses (including reasonable attorney fees) arising from: (a) Your violation of these Terms; (b) Your use or misuse of the App; (c) Your violation of any third-party rights.',
                        ],
                      ),
                      _buildSection(
                        '15. Delivery Riders',
                        [
                          '15.1 Independent Contractors: All Delivery Riders are independent contractors and are not employees or agents of Ouma\'s Delicacy.',
                          '15.2 Rider Relationship: You agree to treat Delivery Riders with respect and professionalism.',
                          '15.3 Tips: Tipping is optional and at your discretion. Tips are provided directly to the Delivery Rider.',
                        ],
                      ),
                      _buildSection(
                        '16. Changes to Terms',
                        [
                          '16.1 Modification Rights: We reserve the right to modify, amend, or update these Terms at any time at our sole discretion.',
                          '16.2 Notification: We will notify you of material changes via email, in-app notification, or by posting a notice in the App.',
                          '16.3 Continued Use: Your continued use of the App after changes are posted constitutes your acceptance of the modified Terms.',
                          '16.4 Review Obligation: It is your responsibility to review these Terms periodically for updates.',
                        ],
                      ),
                      _buildSection(
                        '17. Dispute Resolution',
                        [
                          '17.1 Informal Resolution: In the event of a dispute, you agree to first attempt to resolve the matter informally by contacting us via the App or email.',
                          '17.2 Negotiation Period: Both parties agree to negotiate in good faith for a period of 30 days before pursuing formal legal action.',
                          '17.3 Binding Arbitration: If informal resolution fails, disputes shall be resolved through binding arbitration in accordance with the Arbitration Act of Kenya.',
                        ],
                      ),
                      _buildSection(
                        '18. Governing Law & Jurisdiction',
                        [
                          '18.1 Governing Law: These Terms shall be governed by and construed in accordance with the Laws of the Republic of Kenya.',
                          '18.2 Jurisdiction: Any legal action or proceeding arising from these Terms shall be brought exclusively in the courts located in Nairobi, Kenya.',
                          '18.3 You hereby consent to the exclusive jurisdiction and venue of such courts.',
                        ],
                      ),
                      _buildSection(
                        '19. Termination',
                        [
                          '19.1 Termination by User: You may terminate this Agreement at any time by deleting your account and ceasing use of the App.',
                          '19.2 Termination by Company: We may suspend or terminate your account and access to the App immediately, without prior notice, for any reason, including but not limited to breach of these Terms.',
                          '19.3 Effect of Termination: Upon termination, your right to use the App will immediately cease. All provisions that by their nature should survive termination shall survive.',
                        ],
                      ),
                      _buildSection(
                        '20. Privacy & Data Protection',
                        [
                          '20.1 Data Collection: We collect personal information including name, phone number, email address, delivery address, and Order history.',
                          '20.2 Data Use: Your information is used to process Orders, improve our Service, and communicate with you.',
                          '20.3 Data Sharing: We share your information with Restaurant Partners and Delivery Riders only as necessary to fulfill your Orders.',
                          '20.4 Data Rights: You have the right to request access to, correction of, or deletion of your personal data by contacting us.',
                          '20.5 Full Privacy Policy: For complete details, please review our Privacy Policy.',
                        ],
                      ),
                      _buildSection(
                        '21. Miscellaneous',
                        [
                          '21.1 Entire Agreement: These Terms constitute the entire agreement between you and Ouma\'s Delicacy regarding use of the App.',
                          '21.2 Severability: If any provision of these Terms is found to be unenforceable, the remaining provisions shall remain in full force and effect.',
                          '21.3 Waiver: No waiver of any provision of these Terms shall be deemed a further or continuing waiver.',
                          '21.4 Assignment: You may not assign these Terms without our prior written consent. We may assign these Terms at any time.',
                        ],
                      ),
                      _buildSection(
                        '22. Contact Information',
                        [
                          'For questions, concerns, or notices regarding these Terms and Conditions, please contact us:',
                          'Email: legal@oumasdelicacy.co.ke',
                          'Support: Via in-app customer service',
                          'Response Time: We respond to all inquiries within 24-48 hours.',
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildAcceptNote(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLastUpdated() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Last updated: ${DateTime.now().year}',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.darkText.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<String> points) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
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
          const SizedBox(height: 8),
          ...points.map((point) => Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 8, right: 8),
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        point,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: AppColors.darkText.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildAcceptNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'By using Ouma\'s Delicacy, you agree to these Terms & Conditions.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.darkText.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
