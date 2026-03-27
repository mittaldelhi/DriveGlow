import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class BookingSuccessScreen extends StatelessWidget {
  final String? bookingId;
  final List<String> bookingIds;
  final bool isService;
  final bool isSubscription;
  final String itemName;
  final double total;
  final int vehicleCount;
  final DateTime? appointmentDate;
  final String validityLabel;

  const BookingSuccessScreen({
    super.key,
    this.bookingId,
    this.bookingIds = const [],
    this.isService = true,
    this.isSubscription = false,
    this.itemName = 'Booking',
    this.total = 0,
    this.vehicleCount = 1,
    this.appointmentDate,
    this.validityLabel = '',
  });

  @override
  Widget build(BuildContext context) {
    final firstBookingId =
        bookingId ?? (bookingIds.isNotEmpty ? bookingIds.first : null);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          isSubscription ? 'Subscription Activated' : (isService ? 'Booking Confirmed' : 'Payment Successful'),
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
              child: Column(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF10B981),
                  size: 76,
                ),
                const SizedBox(height: 10),
                Text(
                  isSubscription ? 'Subscription Activated' : (isService ? 'Service Booking Confirmed' : 'Booking Confirmed'),
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  itemName,
                  style: GoogleFonts.inter(color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Receipt',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 10),
                _receiptRow('Item', itemName),
                _receiptRow('Vehicles', '$vehicleCount'),
                _receiptRow('Bookings', '${bookingIds.length}'),
                if (appointmentDate != null)
                  _receiptRow(
                    'Scheduled',
                    DateFormat('dd MMM yyyy, hh:mm a').format(appointmentDate!),
                  ),
                _receiptRow('Validity', validityLabel),
                _receiptRow('Amount', 'Rs ${total.toStringAsFixed(2)}'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Only show QR button for services, NOT for subscriptions
          if (firstBookingId != null && firstBookingId.isNotEmpty && !isSubscription)
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/check-in',
                  arguments: firstBookingId,
                ),
                icon: const Icon(Icons.qr_code_2_rounded),
                label: const Text('Start Service (Show QR)'),
              ),
            ),
          const SizedBox(height: 10),
          SizedBox(
            height: 50,
            child: OutlinedButton(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context,
                '/booking',
                (route) => false,
                arguments: {'openTab': 'active'},
              ),
              child: const Text('Go to My Booking'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _receiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B))),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

