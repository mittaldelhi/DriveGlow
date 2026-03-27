import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shinex/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../application/helpers/error_helper.dart';
import '../../application/providers/booking_providers.dart';
import '../../application/providers/staff_providers.dart';
import '../../domain/models/booking_model.dart';

class StaffQrScannerScreen extends ConsumerStatefulWidget {
  const StaffQrScannerScreen({super.key});

  @override
  ConsumerState<StaffQrScannerScreen> createState() => _StaffQrScannerScreenState();
}

class _StaffQrScannerScreenState extends ConsumerState<StaffQrScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  
  bool _isProcessing = false;
  String? _lastScanned;
  BookingModel? _scannedBooking;
  String? _errorMessage;

  @override
  void dispose() {
    _scannerController.stop();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue;
    if (code == null || code.isEmpty || code == _lastScanned) return;

    setState(() {
      _isProcessing = true;
      _lastScanned = code;
      _errorMessage = null;
    });

    try {
      await _validateAndLookup(code);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isProcessing = false;
        _lastScanned = null;
      });
    }
  }

  Future<void> _validateAndLookup(String code) async {
    final bookingRepo = ref.read(bookingRepositoryProvider);
    final staffRepo = ref.read(staffOpsRepositoryProvider);
    BookingModel? booking;

    // Try direct UUID lookup
    if (_looksLikeUuid(code)) {
      try {
        booking = await bookingRepo.getBooking(code);
      } catch (_) {}
    }

    // Try QR validation
    if (booking == null) {
      try {
        final validation = await staffRepo.validateQr(qrCode: code);
        if (validation['valid'] == true) {
          final bookingId = (validation['booking_id'] ?? '').toString();
          if (bookingId.isNotEmpty) {
            booking = await bookingRepo.getBooking(bookingId);
          }
        } else {
          throw Exception(validation['error_message'] ?? 'Invalid QR code');
        }
      } catch (e) {
        rethrow;
      }
    }

    // Try QR code data lookup
    if (booking == null) {
      booking = await bookingRepo.getBookingByQrCode(code);
    }

    if (!mounted) return;

    setState(() {
      _scannedBooking = booking;
      _isProcessing = false;
    });

    if (booking == null) {
      setState(() {
        _errorMessage = 'Booking not found for this QR/token';
        _lastScanned = null;
      });
    }
  }

  bool _looksLikeUuid(String value) => RegExp(r'^[0-9a-fA-F-]{32,36}$').hasMatch(value);

  void _startService() async {
    if (_scannedBooking == null) return;
    
    final isPending = _scannedBooking!.status == BookingStatus.pending ||
        _scannedBooking!.status == BookingStatus.confirmed;
    
    setState(() => _isProcessing = true);
    
    try {
      if (isPending) {
        // Start the service
        try {
          await ref.read(staffOpsRepositoryProvider).startService(_scannedBooking!.id);
        } catch (_) {
          await ref.read(bookingRepositoryProvider).updateBookingStatus(
            bookingId: _scannedBooking!.id,
            status: BookingStatus.inProgress,
          );
        }
        
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Service started for ${_scannedBooking!.vehicleName}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Complete the service
        try {
          await ref.read(staffOpsRepositoryProvider).completeService(_scannedBooking!.id);
        } catch (_) {
          await ref.read(bookingRepositoryProvider).updateBookingStatus(
            bookingId: _scannedBooking!.id,
            status: BookingStatus.completed,
          );
        }
        
        if (!mounted) return;
        
        // Show customer feedback dialog
        final feedbackResult = await _showCustomerFeedbackDialog();
        
        if (!mounted) return;
        
        if (feedbackResult != null) {
          await _saveCustomerFeedback(feedbackResult);
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Service completed for ${_scannedBooking!.vehicleName}'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reset scanner after completion
        _resetScanner();
        return;
      }
      
      Navigator.pop(context, _scannedBooking);
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context, message: e.toString(), title: 'Operation Failed');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _resetScanner() {
    setState(() {
      _scannedBooking = null;
      _lastScanned = null;
      _errorMessage = null;
    });
    _scannerController.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Scan QR Code',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _scannerController,
              builder: (context, state, child) {
                return Icon(
                  state.torchState == TorchState.on
                      ? Icons.flash_on
                      : Icons.flash_off,
                  color: Colors.white,
                );
              },
            ),
            onPressed: () => _scannerController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch, color: Colors.white),
            onPressed: () => _scannerController.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: _onDetect,
                ),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: PremiumTheme.orangePrimary,
                      width: 3,
                    ),
                  ),
                  margin: const EdgeInsets.all(50),
                ),
                if (_isProcessing)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: PremiumTheme.orangePrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              color: PremiumTheme.surfaceBg,
              padding: const EdgeInsets.all(20),
              child: _scannedBooking != null
                  ? _buildBookingDetails()
                  : _buildInstructions(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.qr_code_scanner,
          size: 48,
          color: Colors.grey[400],
        ),
        const SizedBox(height: 16),
        Text(
          'Scan Customer QR Code',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: PremiumTheme.darkBg,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Point the camera at the QR code displayed in the customer app',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: PremiumTheme.greyText,
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _resetScanner,
            child: const Text('Try Again'),
          ),
        ],
      ],
    );
  }

  Widget _buildBookingDetails() {
    final booking = _scannedBooking!;
    final isPending = booking.status == BookingStatus.pending ||
        booking.status == BookingStatus.confirmed;
    final isInProgress = booking.status == BookingStatus.inProgress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'QR Validated',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetScanner,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _serviceName(booking.serviceId),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Vehicle: ${booking.vehicleName} • ${booking.vehicleNumber}',
          style: TextStyle(color: Colors.grey[700]),
        ),
        Text(
          'Price: ₹${booking.totalPrice.toStringAsFixed(2)}',
          style: TextStyle(color: Colors.grey[700]),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getStatusColor(booking.status).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'Status: ${booking.status.name}',
            style: TextStyle(
              color: _getStatusColor(booking.status),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Spacer(),
        if (isPending || isInProgress)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _startService,
              style: ElevatedButton.styleFrom(
                backgroundColor: PremiumTheme.orangePrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isPending ? 'Start Service' : 'Complete Service',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'This booking has already been ${booking.status.name}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
      ],
    );
  }

  String _serviceName(String ref) {
    final parts = ref.split('::');
    if (parts.length >= 3) return parts.sublist(2).join('::');
    return ref;
  }

  Color _getStatusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.completed:
        return Colors.green;
      case BookingStatus.inProgress:
        return Colors.orange;
      case BookingStatus.cancelled:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<Map<String, dynamic>?> _showCustomerFeedbackDialog() async {
    int rating = 5;
    String behaviorType = 'professional';
    final commentController = TextEditingController();

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Rate Customer'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('How was the customer?', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: Colors.amber,
                        size: 32,
                      ),
                      onPressed: () => setState(() => rating = index + 1),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                const Text('Customer Behavior', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildBehaviorChip('professional', 'Professional', behaviorType, (v) => setState(() => behaviorType = v)),
                    _buildBehaviorChip('friendly', 'Friendly', behaviorType, (v) => setState(() => behaviorType = v)),
                    _buildBehaviorChip('neutral', 'Neutral', behaviorType, (v) => setState(() => behaviorType = v)),
                    _buildBehaviorChip('rude', 'Rude', behaviorType, (v) => setState(() => behaviorType = v)),
                    _buildBehaviorChip('very_poor', 'Very Poor', behaviorType, (v) => setState(() => behaviorType = v)),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: commentController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Optional comment about the customer...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Skip'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, {
                'rating': rating,
                'behavior_type': behaviorType,
                'comment': commentController.text,
              }),
              style: ElevatedButton.styleFrom(
                backgroundColor: PremiumTheme.orangePrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBehaviorChip(String value, String label, String selected, Function(String) onSelected) {
    final isSelected = value == selected;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(value),
      selectedColor: PremiumTheme.orangePrimary.withValues(alpha: 0.2),
      checkmarkColor: PremiumTheme.orangePrimary,
      labelStyle: TextStyle(
        color: isSelected ? PremiumTheme.orangePrimary : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Future<void> _saveCustomerFeedback(Map<String, dynamic> feedback) async {
    try {
      final client = Supabase.instance.client;
      final staffId = client.auth.currentUser?.id;
      
      if (staffId == null || _scannedBooking == null) return;

      await client.from('customer_feedback_from_staff').insert({
        'staff_user_id': staffId,
        'customer_id': _scannedBooking!.userId,
        'booking_id': _scannedBooking!.id,
        'rating': feedback['rating'],
        'behavior_type': feedback['behavior_type'],
        'comment': feedback['comment'],
        'is_positive': (feedback['rating'] as int) >= 4,
      });

      // Update customer average rating
      await _updateCustomerRating(_scannedBooking!.userId);
    } catch (e) {
      // Silent fail - don't interrupt the user flow
    }
  }

  Future<void> _updateCustomerRating(String customerId) async {
    try {
      final client = Supabase.instance.client;
      final result = await client.rpc('calculate_customer_rating', params: {'p_customer_id': customerId});
      
      if (result != null && result.isNotEmpty) {
        final avgRating = result.first['avg_rating'];
        final totalCount = result.first['total_count'];
        
        await client.from('user_profiles').update({
          'customer_rating': avgRating,
          'total_customer_feedbacks': totalCount,
        }).eq('id', customerId);
      }
    } catch (e) {
      // Silent fail
    }
  }
}
