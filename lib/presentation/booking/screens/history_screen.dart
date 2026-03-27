import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../application/providers/booking_providers.dart';
import '../../../application/providers/feature_providers.dart';
import '../../../domain/models/booking_model.dart';
import '../../../domain/models/feedback_model.dart';
import '../../../theme/app_theme.dart';
import '../widgets/booking_utils.dart';
import 'feedback_screen.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  final List<BookingModel>? bookings;
  
  const HistoryScreen({super.key, this.bookings});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  bool _isLoading = true;
  String? _error;
  List<BookingModel> _allBookings = [];
  Map<String, List<BookingModel>> _groupedByVehicle = {};
  final Map<String, FeedbackModel?> _feedbackCache = {};
  
  String _filterType = 'today';
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  @override
  void initState() {
    super.initState();
    // If bookings are passed from parent, use them; otherwise load separately
    if (widget.bookings != null && widget.bookings!.isNotEmpty) {
      _allBookings = widget.bookings!;
      _isLoading = false;
      _processBookings();
    } else {
      _loadData();
    }
  }

  @override
  void didUpdateWidget(HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update when parent passes new bookings
    if (widget.bookings != null && widget.bookings != oldWidget.bookings) {
      _allBookings = widget.bookings!;
      _processBookings();
    }
  }

  void _processBookings() {
    final now = DateTime.now();
    DateTime filterStart;
    DateTime filterEnd;

    switch (_filterType) {
      case 'today':
        filterStart = DateTime(now.year, now.month, now.day);
        filterEnd = filterStart.add(const Duration(days: 1));
        break;
      case 'yesterday':
        filterStart = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
        filterEnd = DateTime(now.year, now.month, now.day);
        break;
      case 'weekly':
        filterStart = now.subtract(const Duration(days: 7));
        filterEnd = now.add(const Duration(days: 1));
        break;
      case 'monthly':
        filterStart = DateTime(now.year, now.month, 1);
        filterEnd = now.add(const Duration(days: 1));
        break;
      case 'custom':
        filterStart = _customStartDate ?? DateTime(now.year, now.month, 1);
        filterEnd = (_customEndDate ?? now).add(const Duration(days: 1));
        break;
      default: // 'all'
        filterStart = DateTime(2020, 1, 1);
        filterEnd = now.add(const Duration(days: 1));
    }

    final historyBookings = _allBookings.where((b) {
      // Show all completed, cancelled, or lapsed bookings
      if (b.status != BookingStatus.completed &&
          b.status != BookingStatus.cancelled &&
          b.status != BookingStatus.lapsed) return false;
      
      // Apply date filter
      if (b.appointmentDate.isBefore(filterStart) || b.appointmentDate.isAfter(filterEnd)) return false;
      
      return true;
    }).toList()
      ..sort((a, b) => b.appointmentDate.compareTo(a.appointmentDate));

    // Group by vehicle
    final grouped = <String, List<BookingModel>>{};
    for (final booking in historyBookings) {
      final vehicleKey = booking.vehicleNumber ?? 'Unknown Vehicle';
      grouped.putIfAbsent(vehicleKey, () => []).add(booking);
    }

    if (mounted) {
      setState(() {
        _groupedByVehicle = grouped;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('Please login to view history.');
      }

      final bookingRepo = ref.read(bookingRepositoryProvider);
      final bookings = await bookingRepo.getUserBookings(user.id);
      
      _allBookings = bookings;
      _processBookings();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<FeedbackModel?> _getFeedbackForBooking(String bookingId) async {
    if (_feedbackCache.containsKey(bookingId)) {
      return _feedbackCache[bookingId];
    }
    try {
      final feedbackRepo = ref.read(feedbackRepositoryProvider);
      final feedback = await feedbackRepo.getFeedbackByBookingId(bookingId);
      _feedbackCache[bookingId] = feedback;
      return feedback;
    } catch (e) {
      _feedbackCache[bookingId] = null;
      return null;
    }
  }

  void _setFilter(String filter) {
    if (filter == 'custom') {
      _showCustomDatePicker();
    } else {
      setState(() {
        _filterType = filter;
      });
      // If bookings from parent, re-process; otherwise reload
      if (widget.bookings != null) {
        _processBookings();
      } else {
        _loadData();
      }
    }
  }

  Future<void> _showCustomDatePicker() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: PremiumTheme.orangePrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _filterType = 'custom';
        _customStartDate = picked.start;
        _customEndDate = picked.end;
      });
      _loadData();
    }
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterType == value;
    return GestureDetector(
      onTap: () => _setFilter(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? PremiumTheme.orangePrimary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? PremiumTheme.orangePrimary : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  String _getEmptyMessage() {
    switch (_filterType) {
      case 'today':
        return 'No booking today found';
      case 'weekly':
        return 'No bookings found this week';
      case 'monthly':
        return 'No bookings found this month';
      case 'custom':
        return 'No bookings found for selected dates';
      default:
        return 'No vehicle history created';
    }
  }

  String _getEmptySubtitle() {
    switch (_filterType) {
      case 'today':
        return 'Your bookings for today will appear here';
      case 'weekly':
        return 'Your bookings for this week will appear here';
      case 'monthly':
        return 'Your bookings for this month will appear here';
      case 'custom':
        return 'Your bookings for selected dates will appear here';
      default:
        return 'Your completed services will appear here';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F6),
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'History',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Today', 'today'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Yesterday', 'yesterday'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Weekly', 'weekly'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Monthly', 'monthly'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Custom', 'custom'),
                ],
              ),
            ),
          ),
          if (_filterType == 'custom' && _customStartDate != null && _customEndDate != null)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '${DateFormat('dd MMM').format(_customStartDate!)} - ${DateFormat('dd MMM yyyy').format(_customEndDate!)}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: PremiumTheme.orangePrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorState()
                    : _groupedByVehicle.isEmpty
                        ? _buildEmptyState()
                        : _buildHistoryList(),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red[300], size: 42),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Failed to load history.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              _getEmptyMessage(),
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getEmptySubtitle(),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    final vehicles = _groupedByVehicle.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: vehicles.length,
        itemBuilder: (context, index) {
          final vehicleNumber = vehicles[index];
          final bookings = _groupedByVehicle[vehicleNumber]!;
          return _buildVehicleSection(vehicleNumber, bookings);
        },
      ),
    );
  }

  Widget _buildVehicleSection(String vehicleNumber, List<BookingModel> bookings) {
    final vehicleModel = bookings.first.vehicleName.isNotEmpty 
        ? bookings.first.vehicleName 
        : 'Vehicle';
    final headerTitle = '$vehicleNumber - $vehicleModel';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          initiallyExpanded: false,
          shape: Border.all(color: Colors.transparent),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  headerTitle,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: PremiumTheme.orangePrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${bookings.length}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: PremiumTheme.orangePrimary,
                  ),
                ),
              ),
            ],
          ),
          leading: Icon(Icons.directions_car, color: Colors.grey[600]),
          children: bookings.map((booking) => _buildHistoryCard(booking)).toList(),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(BookingModel booking) {
    final serviceName = _getServiceName(booking);
    final status = booking.status;
    final isCompleted = status == BookingStatus.completed;
    final isCancelled = status == BookingStatus.cancelled;
    final isLapsed = status == BookingStatus.lapsed;
    
    final refData = parseBookingRef(booking.serviceId);
    final isSubscriptionService = refData.type == 'subscription_service';

    String statusText;
    Color statusColor;
    if (isCancelled) {
      statusText = 'CANCELLED';
      statusColor = Colors.red;
    } else if (isLapsed) {
      statusText = 'NO SHOW';
      statusColor = Colors.red;
    } else {
      statusText = 'COMPLETED';
      statusColor = Colors.green;
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.grey[50] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
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
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusText.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                DateFormat('dd MMM yyyy, hh:mm a').format(booking.appointmentDate),
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
              ),
              const Spacer(),
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
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (isCompleted)
                _buildFeedbackButton(booking)
              else
                const SizedBox.shrink(),
              TextButton(
                onPressed: () => _showDetailsSheet(booking),
                child: Text(
                  'Details',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackButton(BookingModel booking) {
    return FutureBuilder<FeedbackModel?>(
      future: _getFeedbackForBooking(booking.id),
      builder: (context, snapshot) {
        final feedback = snapshot.data;
        final hasFeedback = feedback != null && feedback.id.isNotEmpty;

        if (hasFeedback) {
          return TextButton.icon(
            onPressed: () => _openFeedbackScreen(booking.id),
            icon: Icon(Icons.star, size: 16, color: Colors.amber[700]),
            label: Text(
              '${feedback.rating.round()} Stars',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.amber[700]),
            ),
          );
        }

        return ElevatedButton(
          onPressed: () => _openFeedbackScreen(booking.id),
          style: ElevatedButton.styleFrom(
            backgroundColor: PremiumTheme.orangePrimary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(
            'Give Feedback',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        );
      },
    );
  }

  void _openFeedbackScreen(String bookingId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FeedbackScreen(bookingId: bookingId),
      ),
    ).then((_) => _loadData());
  }

  void _showDetailsSheet(BookingModel booking) {
    final isCompleted = booking.status == BookingStatus.completed;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FutureBuilder<FeedbackModel?>(
        future: _getFeedbackForBooking(booking.id),
        builder: (context, snapshot) {
          final feedback = snapshot.data;
          return _buildDetailsContent(booking, feedback, isCompleted);
        },
      ),
    );
  }

  Widget _buildDetailsContent(BookingModel booking, FeedbackModel? feedback, bool isCompleted) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Booking Details',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDetailRow('Vehicle', booking.vehicleName),
            _buildDetailRow('Vehicle Number', booking.vehicleNumber),
            const Divider(height: 24),
            _buildDetailRow(
              'Booking Date',
              DateFormat('dd MMM yyyy, hh:mm a').format(booking.appointmentDate),
            ),
            if (isCompleted && booking.completedAt != null)
              _buildDetailRow(
                'Completion Date',
                DateFormat('dd MMM yyyy, hh:mm a').format(booking.completedAt!),
              ),
            _buildDetailRow('Booking ID', booking.id),
            _buildDetailRow('Status', booking.status.name.toUpperCase()),
            _buildDetailRow('Price', '₹${booking.totalPrice.toStringAsFixed(0)}'),
            if (booking.isSubscriptionBooking) ...[
              const Divider(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: PremiumTheme.orangePrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'SUBSCRIPTION',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: PremiumTheme.orangePrimary,
                  ),
                ),
              ),
            ],
            if (isCompleted) ...[
              const Divider(height: 24),
              Text(
                'Feedback',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              if (feedback != null && feedback.id.isNotEmpty) ...[
                Row(
                  children: [
                    ...List.generate(5, (index) {
                      return Icon(
                        index < feedback.rating.round()
                            ? Icons.star
                            : Icons.star_border,
                        color: Colors.amber[700],
                        size: 24,
                      );
                    }),
                    const SizedBox(width: 8),
                    Text(
                      '${feedback.rating}/5',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (feedback.comment != null && feedback.comment!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    feedback.comment!,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
                if (feedback.canEdit) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _openFeedbackScreen(booking.id);
                    },
                    child: const Text('Edit Feedback'),
                  ),
                ],
              ] else ...[
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _openFeedbackScreen(booking.id);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PremiumTheme.orangePrimary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Give Feedback'),
                ),
              ],
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  String _getServiceName(BookingModel booking) {
    final serviceId = booking.serviceId;
    if (serviceId.startsWith('subscription::')) {
      final parts = serviceId.split('::');
      if (parts.length >= 3) return parts[2];
      return 'Subscription Plan';
    }
    if (serviceId.startsWith('subscription_service::')) {
      final parts = serviceId.split('::');
      if (parts.length >= 4) return parts[3];
      return 'Subscription Service';
    }
    if (serviceId.length == 36 || serviceId.contains('-')) {
      return 'Standard Service';
    }
    return serviceId;
  }
}
