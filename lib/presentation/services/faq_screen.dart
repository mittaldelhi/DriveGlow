import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final List<_FaqItem> _faqs = [
    // Subscription Basics
    _FaqItem(
      question: 'How do I purchase a subscription?',
      answer: 'To purchase a subscription, go to the Services tab and select "Subscription Plans". Choose a plan that suits your needs, select your vehicle, and complete the payment. Your subscription will be active immediately after purchase.',
    ),
    _FaqItem(
      question: 'What services are included in my subscription?',
      answer: 'The services included in your subscription depend on the plan you choose. You can view all included services in your subscription details. Each plan has specific limits per month for different service types.',
    ),
    _FaqItem(
      question: 'Can I use my subscription for multiple vehicles?',
      answer: 'No. Each subscription is tied to ONE specific vehicle. The vehicle is locked when you purchase the plan. If you have multiple vehicles, you need to purchase separate subscriptions for each vehicle.',
    ),
    _FaqItem(
      question: 'What happens when my subscription expires?',
      answer: 'When your subscription expires, the vehicle badge disappears and you cannot book free services. You can renew your subscription or purchase a new plan. Existing bookings continue until completed.',
    ),
    // Cancellation Rules
    _FaqItem(
      question: 'Can I cancel my subscription plan?',
      answer: 'No. Only Admin can cancel subscription plans. You cannot cancel it yourself. You must wait until it expires naturally or contact our support team for assistance.',
    ),
    _FaqItem(
      question: 'Can I cancel a subscription service booking?',
      answer: 'Yes, you can cancel your service bookings. However: The service still counts as "used", you cannot book another service that day, and your remaining services do NOT increase.',
    ),
    _FaqItem(
      question: 'I cancelled my booking. Why cannot I book again today?',
      answer: 'Because the daily limit is 1 per day per vehicle. Once you booked (even if you cancelled), that day\'s slot is consumed. Try again tomorrow.',
    ),
    // Daily Limit & Usage
    _FaqItem(
      question: 'What is the Daily Limit?',
      answer: 'You can book only 1 free service per day per vehicle from your subscription. This limit resets at midnight. Cancellation does NOT restore the daily slot.',
    ),
    _FaqItem(
      question: 'Can I book multiple services in one day?',
      answer: 'From your subscription: No, only 1 service per day per vehicle. However, you can still book additional regular services at standard rates.',
    ),
    _FaqItem(
      question: 'Does cancelled or lapsed booking count as used?',
      answer: 'Yes. ALL bookings count toward usage regardless of status - pending, confirmed, completed, cancelled, or lapsed. Cancellation does NOT restore your remaining services.',
    ),
    _FaqItem(
      question: 'How do I track my subscription usage?',
      answer: 'You can view your subscription usage in the My Subscriptions section. It shows the number of services used and remaining. The counter shows all bookings including cancelled and lapsed ones.',
    ),
    _FaqItem(
      question: 'What if I miss my booking appointment (lapsed)?',
      answer: 'If you miss your booking, it will be marked as lapsed (no-show) and will still count as "used" against your plan. You lose that service opportunity.',
    ),
    // Regular vs Subscription Services
    _FaqItem(
      question: 'What is the difference between Subscription Service and Regular Service?',
      answer: 'Subscription Services are FREE and come from your plan (enter via My Booking > My Subscription). Regular Services are PAID and available to everyone (enter via Standard Care > Book Now).',
    ),
    _FaqItem(
      question: 'I have a subscription. Can I get all services for free?',
      answer: 'No. Only services listed in your plan are free. Other services cost full price. Your subscription does not cover services outside the plan.',
    ),
    _FaqItem(
      question: 'Do regular paid services count toward my subscription?',
      answer: 'No. Paid regular services are completely separate. They do not affect your subscription usage, limits, or remaining services.',
    ),
    // Plan Management
    _FaqItem(
      question: 'How do I upgrade my plan?',
      answer: 'To upgrade your plan, go to the subscription section and choose a new plan. You can upgrade from Monthly to Yearly plans, or switch to a higher-tier plan. The new plan will be effective immediately after payment.',
    ),
    _FaqItem(
      question: 'Can I get a refund for unused services?',
      answer: 'Contact our support team. Please note that user cancellations do not restore service counts.',
    ),
    _FaqItem(
      question: 'Can my friend use my subscription?',
      answer: 'No. Subscriptions are per-user, per-vehicle. Only the person who purchased and owns the vehicle can use it.',
    ),
    // General
    _FaqItem(
      question: 'How do I contact customer support?',
      answer: 'You can contact our customer support through the Chat option in the app. Our support team is available to help you with any queries or issues.',
    ),
    _FaqItem(
      question: 'What payment methods are accepted?',
      answer: 'We accept various payment methods including credit/debit cards, UPI, and digital wallets. All payments are processed securely through our payment gateway.',
    ),
  ];

  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredFaqs = _searchQuery.isEmpty
        ? _faqs
        : _faqs.where((faq) =>
            faq.question.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            faq.answer.toLowerCase().contains(_searchQuery.toLowerCase())
          ).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'FAQ',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search FAQs...',
                hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // FAQ List
          Expanded(
            child: filteredFaqs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.help_outline, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'No FAQs found',
                          style: GoogleFonts.inter(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredFaqs.length,
                    itemBuilder: (context, index) {
                      return _FaqCard(faq: filteredFaqs[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FaqItem {
  final String question;
  final String answer;

  _FaqItem({required this.question, required this.answer});
}

class _FaqCard extends StatefulWidget {
  final _FaqItem faq;

  const _FaqCard({required this.faq});

  @override
  State<_FaqCard> createState() => _FaqCardState();
}

class _FaqCardState extends State<_FaqCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: PremiumTheme.orangePrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.help_outline,
                      size: 20,
                      color: PremiumTheme.orangePrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.faq.question,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    widget.faq.answer,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
