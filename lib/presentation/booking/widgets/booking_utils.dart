import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../domain/models/booking_model.dart';

class BookingRef {
  final String type;
  final String id;
  final String planId;
  final String name;

  BookingRef({
    required this.type,
    required this.id,
    this.planId = '',
    required this.name,
  });
}

BookingRef parseBookingRef(String raw) {
  final parts = raw.split('::');
  if (parts.length >= 4 && parts[0] == 'subscription_service') {
    return BookingRef(
      type: parts[0],
      id: parts[2],
      planId: parts[1],
      name: parts.sublist(3).join('::'),
    );
  }
  if (parts.length >= 3) {
    return BookingRef(type: parts[0], id: parts[1], name: parts.sublist(2).join('::'));
  }
  if (parts.length == 2 && parts[0] == 'subscription') {
    return BookingRef(type: 'subscription', id: parts[1], name: 'Subscription');
  }
  if (raw.length > 30) {
    return BookingRef(type: 'service', id: raw, name: raw.substring(0, 30));
  }
  return BookingRef(type: 'service', id: raw, name: '');
}

bool isSubscriptionBooking(BookingModel booking) {
  // Check database flag first (most reliable)
  if (booking.isSubscriptionBooking) return true;
  
  // Check serviceId pattern
  final refData = parseBookingRef(booking.serviceId);
  return refData.type == 'subscription' || 
         refData.type == 'subscription_service';
}

bool isLapsedBooking(BookingModel booking) {
  // Only return true if status is explicitly 'lapsed'
  return booking.status == BookingStatus.lapsed;
}

bool isQrAvailable(BookingModel booking) {
  return !isLapsedBooking(booking) &&
      (booking.status == BookingStatus.pending ||
          booking.status == BookingStatus.confirmed ||
          booking.status == BookingStatus.inProgress);
}

String bookingTitle(BookingModel booking) {
  final refData = parseBookingRef(booking.serviceId);
  if (refData.type == 'subscription_service' && refData.name.isNotEmpty) {
    return '${refData.name} (Subscription)';
  }
  if (refData.type == 'subscription') {
    return 'Subscription Service';
  }
  if (refData.name.isNotEmpty) return refData.name;
  if (booking.serviceId.length > 30) {
    return booking.serviceId.substring(0, 30);
  }
  return booking.serviceId;
}

Widget buildEmptyState({
  required BuildContext context,
  required String title,
  required String subtitle,
  required IconData icon,
  String ctaLabel = 'Book Service',
  String ctaRoute = '/select-service',
}) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 80, color: Colors.grey[300]),
        const SizedBox(height: 24),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.grey[500],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => Navigator.pushNamed(context, ctaRoute),
          child: Text(ctaLabel),
        ),
      ],
    ),
  );
}
