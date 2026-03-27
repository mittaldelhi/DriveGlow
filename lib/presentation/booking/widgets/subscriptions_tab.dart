import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../../../application/providers/booking_providers.dart';
import '../../../domain/models/booking_model.dart';
import '../../../theme/app_theme.dart';
import 'booking_utils.dart';

class SubscriptionSummary {
  final String planId;
  final String planName;
  final DateTime startedAt;
  final int? totalAllowed;
  final int usedServices;
  final int? leftServices;
  final List<String> includedServiceIds;
  final bool showUnlimited;
  final String? duration;
  final String? vehicleNumber;
  final Map<String, int>? serviceLimits;
  final int dailyLimit;

  SubscriptionSummary({
    required this.planId,
    required this.planName,
    required this.startedAt,
    required this.totalAllowed,
    required this.usedServices,
    required this.leftServices,
    required this.includedServiceIds,
    required this.showUnlimited,
    this.duration,
    this.vehicleNumber,
    this.serviceLimits,
    required this.dailyLimit,
  });
}

class SubscriptionsTab extends ConsumerWidget {
  final List<BookingModel> bookings;
  final Map<String, Map<String, dynamic>> plansById;
  final VoidCallback? onRefresh;
  
  const SubscriptionsTab({
    super.key, 
    required this.bookings, 
    required this.plansById,
    this.onRefresh,
  });

  List<BookingModel> _getBookedServices(String planId, String? vehicleNumber) {
    if (vehicleNumber == null || vehicleNumber.isEmpty) return [];
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    
    return bookings.where((b) {
      if (b.vehicleNumber?.toLowerCase() != vehicleNumber.toLowerCase()) return false;
      
      // Filter by planId - only services from THIS subscription
      final refData = parseBookingRef(b.serviceId);
      if (refData.planId != planId) return false;
      
      // Exclude cancelled and lapsed
      if (b.status == BookingStatus.cancelled) return false;
      if (b.status == BookingStatus.lapsed) return false;
      
      // Check if it's today
      if (b.appointmentDate.isBefore(today) || b.appointmentDate.isAfter(tomorrow)) return false;
      
      return true;
    }).toList()
      ..sort((a, b) => b.appointmentDate.compareTo(a.appointmentDate));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = _buildSubscriptionSummaries();
    
    if (summaries.isEmpty) {
      return buildEmptyState(
        context: context,
        title: 'No Active Subscriptions',
        subtitle: 'Choose a subscription plan to unlock service bookings.',
        icon: Icons.card_membership,
        ctaLabel: 'Choose Subscription',
        ctaRoute: '/subscription-choice',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        onRefresh?.call();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: summaries.length,
        itemBuilder: (context, index) => _buildSubscriptionCard(context, ref, summaries[index]),
      ),
    );
  }

  List<SubscriptionSummary> _buildSubscriptionSummaries() {
    final subscriptions = bookings.where((b) {
      final refData = parseBookingRef(b.serviceId);
      return refData.type == 'subscription' && b.status != BookingStatus.cancelled;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Group by planId + vehicleNumber to show separate cards for each vehicle
    final latestByKey = <String, BookingModel>{};
    
    for (final subscription in subscriptions) {
      final refData = parseBookingRef(subscription.serviceId);
      if (refData.id.isEmpty) continue;
      
      // Create unique key: planId_vehicleNumber
      final key = '${refData.id}_${subscription.vehicleNumber}';
      latestByKey.putIfAbsent(key, () => subscription);
    }

    return latestByKey.values.map((subscription) {
      final refData = parseBookingRef(subscription.serviceId);
      final plan = plansById[refData.id];
      final planName = refData.name.isNotEmpty ? refData.name : (plan?['name'] as String? ?? 'Subscription Plan');
      
      int? maxAllowed;
      final limitsRaw = plan?['service_usage_limits'] as Map<String, dynamic>?;
      if (limitsRaw != null && limitsRaw.isNotEmpty) {
        maxAllowed = limitsRaw.values.fold<int>(0, (sum, v) => sum + ((v as num?)?.toInt() ?? 0));
      }
      
      final included = (plan?['included_service_ids'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
      
      // RULEBOOK: Count ALL bookings including cancelled/lapsed
      // Status does not matter - if a booking exists, it counts as used
      final used = bookings.where((b) {
        final bRef = parseBookingRef(b.serviceId);
        // Skip the subscription PLAN booking itself
        if (isSubscriptionBooking(b)) return false;
        if (bRef.type != 'subscription_service') return false;
        if (bRef.planId != refData.id) return false;
        if (b.createdAt.isBefore(subscription.createdAt)) return false;
        // RULEBOOK: Cancelled and lapsed ALSO count as used
        return true;
      }).length;

      final left = maxAllowed == null ? null : max(0, maxAllowed - used);
      final showUnlimited = plan?['show_unlimited'] == true;
      final duration = plan?['duration'] as String?;
      
      Map<String, int>? serviceLimits;
      final limitsMap = plan?['service_usage_limits'];
      if (limitsMap != null && limitsMap is Map) {
        serviceLimits = Map<String, int>.from(limitsMap.map((key, value) => MapEntry(key.toString(), (value as num).toInt())));
      }
      
      final dailyLimit = plan?['daily_limit'] as int? ?? 1;
      
      return SubscriptionSummary(
        planId: refData.id,
        planName: planName,
        startedAt: subscription.createdAt,
        totalAllowed: maxAllowed,
        usedServices: used,
        leftServices: left,
        includedServiceIds: included,
        showUnlimited: showUnlimited,
        duration: duration,
        vehicleNumber: subscription.vehicleNumber,
        serviceLimits: serviceLimits,
        dailyLimit: dailyLimit,
      );
    }).toList();
  }

  Widget _buildSubscriptionCard(BuildContext context, WidgetRef ref, SubscriptionSummary summary) {
    // Calculate validity date
    final validityDate = summary.startedAt.add(
      summary.duration?.toLowerCase() == 'yearly' 
        ? const Duration(days: 365) 
        : const Duration(days: 30)
    );
    final validityText = '${validityDate.day} ${_getMonthName(validityDate.month)} ${validityDate.year}';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [PremiumTheme.orangePrimary.withValues(alpha: 0.1), PremiumTheme.orangePrimary.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(summary.planName, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                  child: Text('ACTIVE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('${summary.vehicleNumber ?? ""}', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[700])),
            const SizedBox(height: 4),
            Text('${summary.duration ?? ""}', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Text('Valid till: $validityText', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/subscription-services', arguments: {
                    'planId': summary.planId,
                    'planName': summary.planName,
                    'vehicleNumber': summary.vehicleNumber,
                    'duration': summary.duration,
                    'totalAllowed': summary.totalAllowed,
                    'allowedServiceIds': summary.includedServiceIds,
                    'serviceLimits': summary.serviceLimits,
                    'dailyLimit': summary.dailyLimit,
                  });
                },
                icon: const Icon(Icons.list_alt, size: 20),
                label: Text(
                  'CHOOSE SERVICE',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PremiumTheme.orangePrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            _buildBookedServicesSection(context, ref, summary.planId, summary.vehicleNumber),
          ],
        ),
      ),
    );
  }

  Widget _buildBookedServicesSection(BuildContext context, WidgetRef ref, String planId, String? vehicleNumber) {
    final bookedServices = _getBookedServices(planId, vehicleNumber);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Divider(color: Colors.grey[300]),
        const SizedBox(height: 12),
        Text(
          "TODAY'S SERVICES",
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.grey[600],
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        if (bookedServices.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                'No services booked Today',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ),
          )
        else
          ...bookedServices.map((booking) => _buildBookedServiceCard(context, ref, booking)),
      ],
    );
  }

  Widget _buildBookedServiceCard(BuildContext context, WidgetRef ref, BookingModel booking) {
    final refData = parseBookingRef(booking.serviceId);
    final serviceName = refData.name.isNotEmpty ? refData.name : 'Subscription Service';
    final isSubscriptionService = refData.type == 'subscription_service';
    
    // Card styling based on status
    final isCompleted = booking.status == BookingStatus.completed;
    final isPending = booking.status == BookingStatus.pending;
    final isConfirmed = booking.status == BookingStatus.confirmed;
    final isInProgress = booking.status == BookingStatus.inProgress;
    
    // Border color based on status
    Color borderColor;
    if (isInProgress) {
      borderColor = Colors.green;
    } else if (isConfirmed) {
      borderColor = Colors.blue;
    } else if (isPending) {
      borderColor = Colors.amber;
    } else if (isCompleted) {
      borderColor = Colors.grey[300]!;
    } else {
      borderColor = Colors.grey[200]!;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.grey[100] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: isInProgress ? 2 : 1),
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isSubscriptionService ? 'SUBSCRIPTION' : 'REGULAR',
                        style: GoogleFonts.inter(
                          fontSize: 10, 
                          fontWeight: FontWeight.w700, 
                          color: Colors.green,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      serviceName,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isCompleted ? Colors.grey[600] : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(booking.status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('dd MMM yyyy, hh:mm a').format(booking.appointmentDate),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
              if (!isCompleted)
                Text(
                  '₹${booking.totalPrice.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(
                    fontSize: 16, 
                    fontWeight: FontWeight.w800, 
                    color: const Color(0xFF0F172A),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/check-in', arguments: booking.id),
                icon: const Icon(Icons.qr_code, size: 16),
                label: Text('View QR', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              TextButton(
                onPressed: () => _rescheduleBooking(context, ref, booking),
                child: Text('Reschedule', style: GoogleFonts.inter(fontSize: 12)),
              ),
              TextButton(
                onPressed: () => _cancelBooking(context, ref, booking),
                child: Text('Cancel', style: GoogleFonts.inter(fontSize: 12, color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BookingStatus status) {
    String label;
    Color color;
    
    switch (status) {
      case BookingStatus.pending:
        label = 'PENDING';
        color = Colors.amber;
        break;
      case BookingStatus.confirmed:
        label = 'CONFIRMED';
        color = Colors.blue;
        break;
      case BookingStatus.inProgress:
        label = 'IN PROGRESS';
        color = Colors.green;
        break;
      case BookingStatus.completed:
        label = 'COMPLETED';
        color = Colors.grey;
        break;
      case BookingStatus.cancelled:
        label = 'CANCELLED';
        color = Colors.red;
        break;
      case BookingStatus.lapsed:
        label = 'NO SHOW';
        color = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Future<void> _cancelBooking(BuildContext context, WidgetRef ref, BookingModel booking) async {
    final refData = parseBookingRef(booking.serviceId);
    final isSubscriptionService = refData.type == 'subscription_service';
    
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel booking?'),
        content: Text(
          isSubscriptionService 
              ? 'This service will be cancelled. Note: The service still counts as used and your daily limit has already been consumed.'
              : 'You can re-book or reschedule later.',
        ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isSubscriptionService 
                ? 'Booking cancelled. This service still counts as used.'
                : 'Booking cancelled'
            ),
            backgroundColor: Colors.orange,
          ),
        );
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking rescheduled!')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reschedule failed: $e')));
      }
    }
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}
