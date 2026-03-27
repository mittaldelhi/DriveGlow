import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import '../../domain/models/booking_model.dart';
import '../../domain/models/booking_slot_model.dart' as slot;
import '../../domain/models/feedback_model.dart';

class BookingRepository {
  final SupabaseClient _client;

  BookingRepository(this._client);

  /// Create a new booking
  Future<String> createBooking(BookingModel booking) async {
    final payload = booking.toJson();
    payload['id'] = (payload['id'] as String?)?.isNotEmpty == true
        ? payload['id']
        : _generateUuidV4();

    final response = await _client
        .from('bookings')
        .insert(payload)
        .select()
        .single()
        .timeout(const Duration(seconds: 15));

    return response['id'];
  }

  /// Get a single booking by ID
  Future<BookingModel> getBooking(String id) async {
    final response = await _client
        .from('bookings')
        .select()
        .eq('id', id)
        .single();

    return BookingModel.fromJson(response);
  }

  /// Get all bookings for a specific user
  Future<List<BookingModel>> getUserBookings(String userId) async {
    final response = await _client
        .from('bookings')
        .select()
        .eq('user_id', userId)
        .order('appointment_date', ascending: false);

    return (response as List)
        .map((json) => BookingModel.fromJson(json))
        .toList();
  }

  Future<void> updateBookingStatus({
    required String bookingId,
    required BookingStatus status,
  }) async {
    final payload = <String, dynamic>{'status': status.name};
    if (status == BookingStatus.inProgress) {
      payload['check_in_time'] = DateTime.now().toIso8601String();
    }
    if (status == BookingStatus.completed) {
      payload['completed_at'] = DateTime.now().toIso8601String();
    }
    if (status == BookingStatus.cancelled) {
      payload['cancelled_at'] = DateTime.now().toIso8601String();
    }

    await _client.from('bookings').update(payload).eq('id', bookingId);
  }

  Future<void> rescheduleBooking({
    required String bookingId,
    required DateTime appointmentDate,
  }) async {
    await _client
        .from('bookings')
        .update({'appointment_date': appointmentDate.toIso8601String()})
        .eq('id', bookingId);
  }

  Future<void> startService(String bookingId) async {
    await _client.from('bookings').update({
      'status': 'inProgress',
      'started_at': DateTime.now().toIso8601String(),
    }).eq('id', bookingId);
  }

  Future<BookingModel?> getBookingByQrCode(String qrCodeData) async {
    final response = await _client
        .from('bookings')
        .select()
        .eq('qr_code_data', qrCodeData)
        .order('created_at', ascending: false)
        .limit(1);

    if ((response as List).isEmpty) return null;
    return BookingModel.fromJson(response.first);
  }

  Future<FeedbackModel?> getFeedbackForBooking(String bookingId) async {
    final response = await _client
        .from('service_feedback')
        .select()
        .eq('booking_id', bookingId)
        .maybeSingle();
    
    if (response == null) return null;
    return FeedbackModel.fromJson(response);
  }

  Future<void> saveFeedback(FeedbackModel feedback) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    final existing = await _client
        .from('service_feedback')
        .select('id')
        .eq('booking_id', feedback.bookingId)
        .maybeSingle();

    if (existing != null) {
      await _client.from('service_feedback').update({
        'rating': feedback.rating,
        'comment': feedback.comment,
        'tags': feedback.tags,
        'is_complaint': feedback.isComplaint,
        'feedback_updated_at': DateTime.now().toIso8601String(),
      }).eq('booking_id', feedback.bookingId);
    } else {
      await _client.from('service_feedback').insert({
        'id': feedback.id.isNotEmpty ? feedback.id : 'fb_${_generateUuidV4()}',
        'booking_id': feedback.bookingId,
        'user_id': user.id,
        'rating': feedback.rating,
        'comment': feedback.comment,
        'tags': feedback.tags,
        'is_complaint': feedback.isComplaint,
      });
    }
  }

  Future<List<BookingModel>> getBookingsByStatuses(
    List<BookingStatus> statuses,
  ) async {
    final names = statuses.map((s) => s.name).toList();
    final response = await _client
        .from('bookings')
        .select()
        .inFilter('status', names)
        .order('appointment_date', ascending: true);

    return (response as List)
        .map((json) => BookingModel.fromJson(json))
        .toList();
  }

  /// Get daily bookings (for Admin) - reusing BookingSlotModel for display
  Future<List<slot.BookingSlotModel>> getDailyBookings(DateTime date) async {
    // Start of day
    final startOfDay = DateTime(date.year, date.month, date.day);
    // End of day
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final response = await _client
        .from('bookings')
        .select()
        .gte('appointment_date', startOfDay.toIso8601String())
        .lt('appointment_date', endOfDay.toIso8601String())
        .order('appointment_date', ascending: true);

    return (response as List).map((json) {
      final booking = BookingModel.fromJson(json);
      // Map to slot model for UI
      return slot.BookingSlotModel(
        id: booking.id,
        customerName: 'Customer', // In real app, join with profiles
        carModel: booking.vehicleName,
        carColor: '', // Not in booking model, would need join
        serviceType: 'Service', // Need to fetch service name
        startTime: booking.appointmentDate,
        durationMinutes: 60, // Default or fetch
        status: slot.BookingStatus.values.firstWhere(
          (e) => e.name == booking.status.name,
          orElse: () => slot.BookingStatus.pending,
        ),
      );
    }).toList();
  }

  String _generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String hex(int i) => i.toRadixString(16).padLeft(2, '0');
    final b = bytes.map(hex).toList();
    return '${b[0]}${b[1]}${b[2]}${b[3]}-'
        '${b[4]}${b[5]}-'
        '${b[6]}${b[7]}-'
        '${b[8]}${b[9]}-'
        '${b[10]}${b[11]}${b[12]}${b[13]}${b[14]}${b[15]}';
  }
}
