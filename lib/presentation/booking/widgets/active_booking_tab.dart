import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../application/providers/booking_providers.dart';
import '../../../domain/models/booking_model.dart';
import '../../../theme/app_theme.dart';
import 'booking_utils.dart';

class ActiveBookingTab extends ConsumerWidget {
  final List<BookingModel> bookings;
  final VoidCallback? onRefresh;
  
  const ActiveBookingTab({
    super.key, 
    required this.bookings,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Show: Standard Care Services + Services from Subscription (active statuses)
    // Hide: Subscription Purchases (plans), completed, cancelled, lapsed
    final active = bookings.where((b) {
      // Hide subscription PURCHASES (plan subscriptions) - they go to My Subscription tab
      if (b.serviceId.startsWith('subscription::')) return false;
      
      // Hide completed/cancelled/lapsed
      if (b.status == BookingStatus.completed) return false;
      if (b.status == BookingStatus.cancelled) return false;
      if (b.status == BookingStatus.lapsed) return false;
      
      // Show only active statuses (pending, confirmed, inProgress)
      return b.status == BookingStatus.pending ||
             b.status == BookingStatus.confirmed ||
             b.status == BookingStatus.inProgress;
    }).toList();

    if (active.isEmpty) {
      return buildEmptyState(
        context: context,
        title: 'No Active Bookings',
        subtitle: 'Book a service and track it live here.',
        icon: Icons.calendar_today,
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        onRefresh?.call();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: active.length,
        itemBuilder: (context, index) => _buildActiveBookingCard(context, ref, active[index]),
      ),
    );
  }

  Widget _buildActiveBookingCard(BuildContext context, WidgetRef ref, BookingModel booking) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bookingTitle(booking),
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${booking.vehicleName} • ${booking.vehicleNumber}',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd MMM yyyy, hh:mm a').format(booking.appointmentDate),
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${booking.totalPrice.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 4),
                  _statusChipForBooking(booking),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isQrAvailable(booking))
                TextButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/check-in', arguments: booking.id),
                  icon: const Icon(Icons.qr_code, size: 16),
                  label: Text('View QR', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              if (!booking.isCompleted && !booking.isCancelled)
                TextButton(
                  onPressed: () => _rescheduleBooking(context, ref, booking),
                  child: const Text('Reschedule'),
                ),
              if (!booking.isCompleted && !booking.isCancelled)
                TextButton(
                  onPressed: () => _cancelBooking(context, ref, booking),
                  child: const Text('Cancel', style: TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChipForBooking(BookingModel booking) {
    if (isLapsedBooking(booking)) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'LAPSED',
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.red[700]),
        ),
      );
    }
    return _buildStatusChip(booking.status);
  }

  Widget _buildStatusChip(BookingStatus status) {
    final isPositive = status == BookingStatus.confirmed || status == BookingStatus.completed || status == BookingStatus.inProgress;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isPositive ? Colors.green[50] : Colors.amber[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: isPositive ? Colors.green[700] : Colors.amber[700]),
      ),
    );
  }

  Future<void> _cancelBooking(BuildContext context, WidgetRef ref, BookingModel booking) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel booking?'),
        content: const Text('You can re-book or reschedule later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel Booking', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldCancel != true) return;

    try {
      await ref.read(bookingRepositoryProvider).updateBookingStatus(bookingId: booking.id, status: BookingStatus.cancelled);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking cancelled')));
      }
      // Trigger refresh to update the list
      onRefresh?.call();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cancel failed: $e')));
      }
    }
  }

  Future<void> _rescheduleBooking(BuildContext context, WidgetRef ref, BookingModel booking) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: booking.appointmentDate.isAfter(DateTime.now()) ? booking.appointmentDate : DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(booking.appointmentDate),
    );
    if (pickedTime == null) return;

    final newDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);

    try {
      await ref.read(bookingRepositoryProvider).rescheduleBooking(bookingId: booking.id, appointmentDate: newDate);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking rescheduled!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reschedule failed: $e')));
    }
  }
}
