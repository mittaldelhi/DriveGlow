import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/staff_profile_model.dart';

class StaffContext {
  final String userId;
  final String fullName;
  final String employeeId;
  final String roleKey;
  final bool isActive;

  const StaffContext({
    required this.userId,
    required this.fullName,
    required this.employeeId,
    required this.roleKey,
    required this.isActive,
  });
}

class StaffDashboardStats {
  final int totalJobsToday;
  final int completedJobsToday;
  final int pendingJobsToday;
  final int inProgressJobsToday;
  final double averageRatingToday;
  final double revenueToday;
  final int customersServedToday;

  const StaffDashboardStats({
    required this.totalJobsToday,
    required this.completedJobsToday,
    required this.pendingJobsToday,
    required this.inProgressJobsToday,
    required this.averageRatingToday,
    required this.revenueToday,
    required this.customersServedToday,
  });
}

class StaffAttendanceState {
  final String? logId;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final bool checkedIn;

  const StaffAttendanceState({
    required this.logId,
    required this.checkInAt,
    required this.checkOutAt,
    required this.checkedIn,
  });
}

class StaffOpsRepository {
  final SupabaseClient _client;

  StaffOpsRepository(this._client);

  Future<Map<String, dynamic>> validateQr({
    required String qrCode,
    String? carNumber,
  }) async {
    final response = await _client.rpc(
      'validate_qr_and_prepare_job',
      params: {
        'p_qr_code': qrCode,
        'p_car_number': carNumber,
      },
    );

    if (response is List && response.isNotEmpty) {
      return Map<String, dynamic>.from(response.first as Map);
    }
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    return {
      'valid': false,
      'error_code': 'INVALID_RESPONSE',
      'error_message': 'Unexpected validation response.',
    };
  }

  Future<void> startService(String bookingId) async {
    await _client.rpc('start_staff_service', params: {'p_booking_id': bookingId});
  }

  Future<void> completeService(String bookingId) async {
    await _client
        .rpc('complete_staff_service', params: {'p_booking_id': bookingId});
  }

  Future<void> markNoShow(String bookingId) async {
    await _client.rpc('mark_staff_no_show', params: {'p_booking_id': bookingId});
  }

  Future<void> submitCustomerRating({
    required String bookingId,
    required double rating,
    String? comment,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not logged in');
    
    await _client.from('service_feedback').insert({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'booking_id': bookingId,
      'user_id': user.id,
      'staff_id': user.id,
      'rating': rating,
      'comment': comment ?? '',
    });
  }

  Future<StaffContext?> getStaffContext() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final profile = await _client
        .from('user_profiles')
        .select('full_name, membership_tier, employee_id')
        .eq('id', user.id)
        .maybeSingle();

    final fullName = (profile?['full_name'] ?? 'Staff').toString();
    final membershipTier = (profile?['membership_tier'] ?? 'STAFF').toString().toUpperCase();
    final employeeId = (profile?['employee_id'] ?? 'NA').toString();

    // Staff is active if membership_tier is STAFF or ADMIN
    final isActive = membershipTier == 'STAFF' || membershipTier == 'ADMIN';

    return StaffContext(
      userId: user.id,
      fullName: fullName,
      employeeId: employeeId,
      roleKey: membershipTier,
      isActive: isActive,
    );
  }

  Future<List<Map<String, dynamic>>> getQueue({
    List<String>? statuses,
    bool todayOnly = true,
  }) async {
    // Include all possible status variations
    final queueStatuses = statuses ?? ['pending', 'confirmed', 'inProgress', 'in_progress', 'completed', 'cancelled', 'lapsed'];

    final response = await _client
        .from('bookings')
        .select(
          'id,user_id,service_id,vehicle_name,vehicle_number,appointment_date,status,total_price,created_at,qr_code_data,is_subscription_booking',
        )
        .inFilter('status', queueStatuses)
        .order('appointment_date', ascending: true);

    final rows = (response as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    if (!todayOnly) return rows;

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return rows.where((row) {
      final date = DateTime.tryParse((row['appointment_date'] ?? '').toString());
      if (date == null) return false;
      return !date.isBefore(start) && date.isBefore(end);
    }).toList();
  }

  // Get history with date filter and pagination
  Future<List<Map<String, dynamic>>> getHistory({
    String filter = 'today', // today, yesterday, week
    int limit = 5,
    int offset = 0,
  }) async {
    DateTime startDate;
    DateTime endDate = DateTime.now();
    
    switch (filter) {
      case 'today':
        startDate = DateTime(endDate.year, endDate.month, endDate.day);
        break;
      case 'yesterday':
        startDate = DateTime(endDate.year, endDate.month, endDate.day - 1);
        endDate = DateTime(endDate.year, endDate.month, endDate.day);
        break;
      case 'week':
        startDate = DateTime(endDate.year, endDate.month, endDate.day - 7);
        break;
      default:
        startDate = DateTime(endDate.year, endDate.month, endDate.day);
    }
    
    final response = await _client
        .from('bookings')
        .select(
          'id,user_id,service_id,vehicle_name,vehicle_number,appointment_date,status,total_price,created_at,qr_code_data,is_subscription_booking',
        )
        .gte('appointment_date', startDate.toIso8601String())
        .lte('appointment_date', endDate.add(const Duration(days: 1)).toIso8601String())
        .order('appointment_date', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> startBookingService(String bookingId) async {
    try {
      await _client.rpc('start_booking_service', params: {'p_booking_id': bookingId});
    } catch (e) {
      final booking = await _client.from('bookings').select().eq('id', bookingId).maybeSingle();
      if (booking != null) {
        final status = booking['status'] as String?;
        if (status == 'pending' || status == 'confirmed') {
          await _client.from('bookings').update({
            'status': 'inProgress',
            'started_at': DateTime.now().toIso8601String(),
          }).eq('id', bookingId);
        }
      }
    }
  }

  Future<bool> canStartBooking(String bookingId) async {
    try {
      final result = await _client.rpc('can_start_subscription_booking', params: {'p_booking_id': bookingId});
      return result == true;
    } catch (e) {
      final booking = await _client.from('bookings').select().eq('id', bookingId).maybeSingle();
      if (booking == null) return false;
      final status = booking['status'] as String?;
      final isSubscription = booking['is_subscription_booking'] as bool? ?? false;
      final startedAt = booking['started_at'];
      final createdAt = DateTime.parse(booking['created_at'] as String);
      
      if (status == 'pending' || status == 'confirmed') {
        if (!isSubscription) return true;
        if (startedAt == null && DateTime.now().difference(createdAt).inHours < 24) {
          return true;
        }
      }
      return false;
    }
  }

  Future<StaffDashboardStats> getTodayStats() async {
    final queue = await getQueue(todayOnly: true);
    final total = queue.length;
    
    // Debug: Print all statuses to understand the format
    // ignore: avoid_print
    print('Total bookings: $total');
    for (var q in queue) {
      // ignore: avoid_print
      print('Booking ${q['id']} status: ${q['status']}');
    }
    
    // Check status in both camelCase and snake_case - more flexible matching
    final completed = queue.where((q) {
      final status = (q['status'] as String?)?.toLowerCase().trim() ?? '';
      return status.contains('complete');
    }).length;
    
    final pending = queue.where((q) {
      final status = (q['status'] as String?)?.toLowerCase().trim() ?? '';
      return status == 'pending' || status == 'confirmed';
    }).length;
    
    final inProgress = queue.where((q) {
      final status = (q['status'] as String?)?.toLowerCase().trim() ?? '';
      return status.contains('progress') || status == 'inprogress' || status == 'in_progress';
    }).length;

    // Calculate revenue from completed jobs
    double revenue = 0;
    for (final job in queue.where((q) {
      final status = (q['status'] as String?)?.toLowerCase().trim() ?? '';
      return status.contains('complete');
    })) {
      revenue += (job['total_price'] as num?)?.toDouble() ?? 0;
    }

    double avgRating = 0;
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 1));
      final feedback = await _client
          .from('service_feedback')
          .select('rating,created_at')
          .order('created_at', ascending: false)
          .limit(200);
      final rows = (feedback as List)
          .cast<Map<String, dynamic>>()
          .where((row) {
            final createdAt =
                DateTime.tryParse((row['created_at'] ?? '').toString());
            if (createdAt == null) return false;
            return !createdAt.isBefore(start) && createdAt.isBefore(end);
          })
          .toList();
      if (rows.isNotEmpty) {
        final sum = rows.fold<double>(
          0,
          (acc, row) => acc + ((row['rating'] as num?)?.toDouble() ?? 0),
        );
        avgRating = sum / rows.length;
      }
    } catch (_) {}

    return StaffDashboardStats(
      totalJobsToday: total,
      completedJobsToday: completed,
      pendingJobsToday: pending,
      inProgressJobsToday: inProgress,
      averageRatingToday: avgRating,
      revenueToday: revenue,
      customersServedToday: completed,
    );
  }

  Future<int> getLifetimeCompletedJobs() async {
    try {
      final response = await _client
          .from('bookings')
          .select('id')
          .eq('status', 'completed');
      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  Future<Map<String, dynamic>> getAttendanceData(int month, int year) async {
    try {
      final firstDay = DateTime(year, month, 1);
      final lastDay = DateTime(year, month + 1, 0);
      final firstDayStr = '${firstDay.year}-${firstDay.month.toString().padLeft(2, '0')}-${firstDay.day.toString().padLeft(2, '0')}';
      final lastDayStr = '${lastDay.year}-${lastDay.month.toString().padLeft(2, '0')}-${lastDay.day.toString().padLeft(2, '0')}';
      
      // Get attendance records for the month
      final attendance = await _client
          .from('staff_attendance_calendar')
          .select()
          .gte('date', firstDayStr)
          .lte('date', lastDayStr);
      
      // Get leave requests for the month
      final leaveRequests = await _client
          .from('leave_requests')
          .select()
          .eq('status', 'approved')
          .gte('start_date', firstDayStr)
          .lte('end_date', lastDayStr);
      
      return {
        'attendance': attendance,
        'leaveRequests': leaveRequests,
      };
    } catch (e) {
      return {'attendance': [], 'leaveRequests': []};
    }
  }

  Stream<StaffDashboardStats> streamTodayStats() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    return _client
        .from('bookings')
        .stream(primaryKey: ['id'])
        .map((events) {
      final todayEvents = events.where((row) {
        final date = DateTime.tryParse((row['appointment_date'] ?? '').toString());
        if (date == null) return false;
        return !date.isBefore(start) && date.isBefore(end);
      }).toList();

      final total = todayEvents.length;
      
      // Check status in both camelCase and snake_case
      final completed = todayEvents.where((q) {
        final status = (q['status'] as String?)?.toLowerCase() ?? '';
        return status == 'completed';
      }).length;
      
      final pending = todayEvents.where((q) {
        final status = (q['status'] as String?)?.toLowerCase() ?? '';
        return status == 'pending' || status == 'confirmed';
      }).length;
      
      final inProgress = todayEvents.where((q) {
        final status = (q['status'] as String?)?.toLowerCase() ?? '';
        return status == 'inprogress' || status == 'in_progress';
      }).length;

      double revenue = 0;
      for (final job in todayEvents.where((q) {
        final status = (q['status'] as String?)?.toLowerCase() ?? '';
        return status == 'completed';
      })) {
        revenue += (job['total_price'] as num?)?.toDouble() ?? 0;
      }

      return StaffDashboardStats(
        totalJobsToday: total,
        completedJobsToday: completed,
        pendingJobsToday: pending,
        inProgressJobsToday: inProgress,
        averageRatingToday: 0,
        revenueToday: revenue,
        customersServedToday: completed,
      );
    }).handleError((e) {
      print('streamTodayStats error: $e');
      return StaffDashboardStats(
        totalJobsToday: 0,
        completedJobsToday: 0,
        pendingJobsToday: 0,
        inProgressJobsToday: 0,
        averageRatingToday: 0,
        revenueToday: 0,
        customersServedToday: 0,
      );
    });
  }

  Future<StaffAttendanceState> getTodayAttendance() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return const StaffAttendanceState(
        logId: null,
        checkInAt: null,
        checkOutAt: null,
        checkedIn: false,
      );
    }

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    final rows = await _client
        .from('attendance_logs')
        .select('id,check_in_at,check_out_at')
        .eq('staff_user_id', user.id)
        .order('check_in_at', ascending: false)
        .limit(30);

    final todayRows = (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((row) {
          final checkIn =
              DateTime.tryParse((row['check_in_at'] ?? '').toString());
          if (checkIn == null) return false;
          return !checkIn.isBefore(start) && checkIn.isBefore(end);
        })
        .toList();

    if (todayRows.isEmpty) {
      return const StaffAttendanceState(
        logId: null,
        checkInAt: null,
        checkOutAt: null,
        checkedIn: false,
      );
    }

    final row = todayRows.first;
    final checkIn = DateTime.tryParse((row['check_in_at'] ?? '').toString());
    final checkOut = DateTime.tryParse((row['check_out_at'] ?? '').toString());
    return StaffAttendanceState(
      logId: row['id']?.toString(),
      checkInAt: checkIn,
      checkOutAt: checkOut,
      checkedIn: checkIn != null && checkOut == null,
    );
  }

  Future<void> checkIn() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    await _client.from('attendance_logs').insert({
      'staff_user_id': user.id,
    });
  }

  Future<void> checkOut() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    final state = await getTodayAttendance();
    if (state.logId == null) throw Exception('No active check-in found');
    await _client
        .from('attendance_logs')
        .update({'check_out_at': DateTime.now().toIso8601String()})
        .eq('id', state.logId!);
  }

  Future<List<Map<String, dynamic>>> getRecentFeedbackForStaff() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];

    final completedLogs = await _client
        .from('service_logs')
        .select('booking_id,created_at')
        .eq('staff_user_id', user.id)
        .eq('action', 'complete')
        .order('created_at', ascending: false)
        .limit(50);

    final bookingIds = (completedLogs as List)
        .map((e) => (e as Map)['booking_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (bookingIds.isEmpty) return const [];

    final feedback = await _client
        .from('service_feedback')
        .select('id,booking_id,rating,comment,created_at')
        .inFilter('booking_id', bookingIds)
        .order('created_at', ascending: false)
        .limit(20);

    return (feedback as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<StaffProfileModel?> getStaffProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    // Get profile from user_profiles (no email column)
    final profile = await _client
        .from('user_profiles')
        .select('full_name')
        .eq('id', user.id)
        .maybeSingle();

    // Get staff info from user_profiles
    final staff = await _client
        .from('user_profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (staff == null) return null;

    // Get email from auth.users via RPC
    final email = await _client.rpc('get_user_email', params: {'p_user_id': user.id});

    return StaffProfileModel(
      id: staff['id'] ?? '',
      userId: user.id,
      employeeId: staff['employee_id'] ?? '',
      fullName: profile?['full_name'] ?? 'Staff',
      email: email ?? '',
      phone: staff['phone'] ?? '',
      address: staff['address'] ?? '',
      roleKey: staff['role_key'] ?? 'WASHER',
      profilePhotoUrl: staff['profile_photo_url'],
      salary: staff['salary'] != null ? (staff['salary'] as num).toDouble() : null,
      bankAccountNumber: staff['bank_account_number'],
      ifscCode: staff['ifsc_code'],
      dateOfJoining: staff['date_of_joining'] != null
          ? DateTime.tryParse(staff['date_of_joining'].toString())
          : null,
      isActive: staff['is_active'] ?? true,
      createdAt: staff['created_at'] != null
          ? DateTime.parse(staff['created_at'].toString())
          : DateTime.now(),
      updatedAt: staff['updated_at'] != null
          ? DateTime.parse(staff['updated_at'].toString())
          : DateTime.now(),
    );
  }

  Future<void> updateStaffProfile({
    String? phone,
    String? address,
    String? profilePhotoUrl,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final updates = <String, dynamic>{};
    if (phone != null) updates['phone'] = phone;
    if (address != null) updates['address'] = address;
    if (profilePhotoUrl != null) updates['profile_photo_url'] = profilePhotoUrl;
    updates['updated_at'] = DateTime.now().toIso8601String();

    // Update user_profiles instead of staff_users
    await _client.from('user_profiles').update(updates).eq('id', user.id);
  }

  Future<StaffWorkStats> getStaffWorkStats() async {
    final user = _client.auth.currentUser;
    if (user == null) return StaffWorkStats.empty();

    try {
      final response = await _client.rpc('get_staff_work_stats', params: {
        'p_staff_id': user.id,
      });

      if (response is List && response.isNotEmpty) {
        return StaffWorkStats.fromJson(Map<String, dynamic>.from(response.first));
      }
    } catch (e) {
      // Fallback to manual calculation if function doesn't exist
      return await _calculateWorkStatsManually(user.id);
    }

    return StaffWorkStats.empty();
  }

  Future<StaffWorkStats> _calculateWorkStatsManually(String userId) async {
    try {
      // Get total work days
      final attendanceRows = await _client
          .from('attendance_logs')
          .select('check_in_at')
          .eq('staff_user_id', userId);
      
      final uniqueDays = <String>{};
      for (final row in attendanceRows) {
        final checkIn = row['check_in_at'] as String?;
        if (checkIn != null) {
          uniqueDays.add(checkIn.split('T').first);
        }
      }
      final totalDays = uniqueDays.length;

      // Get service stats - not relying on duration_minutes as it may not exist
      final serviceRows = await _client
          .from('service_logs')
          .select('action, created_at')
          .eq('staff_user_id', userId);

      int completed = 0;
      double totalHours = 0;
      int currentMonth = 0;
      double monthHours = 0;
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);

      for (final row in serviceRows) {
        if (row['action'] == 'complete') {
          completed++;
          // Estimate 30 minutes per service if duration not tracked
          totalHours += 0.5;
          monthHours += 0.5;

          final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '');
          if (createdAt != null && createdAt.isAfter(monthStart)) {
            currentMonth++;
          }
        }
      }

      // Get pending
      final pendingRows = await _client
          .from('bookings')
          .select()
          .inFilter('status', ['pending', 'confirmed']);
      final pending = pendingRows.length;

      return StaffWorkStats(
        totalWorkDays: totalDays,
        totalWorkHours: totalHours,
        totalServicesCompleted: completed,
        currentMonthServices: currentMonth,
        pendingServices: pending,
        currentMonthHours: monthHours,
      );
    } catch (e) {
      return StaffWorkStats.empty();
    }
  }

  Future<int> getUnreadNotificationCount() async {
    final user = _client.auth.currentUser;
    if (user == null) return 0;

    try {
      final response = await _client
          .from('user_notifications')
          .select('id')
          .eq('user_id', user.id)
          .eq('is_read', false);
      
      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getNotifications({int limit = 20}) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await _client
          .from('user_notifications')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _client
        .from('user_notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  Future<void> markAllNotificationsRead() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client
        .from('user_notifications')
        .update({'is_read': true})
        .eq('user_id', user.id)
        .eq('is_read', false);
  }

  // Staff Requests (unified)
  Future<List<Map<String, dynamic>>> getAllStaffRequests({String? status}) async {
    try {
      // Query without join (FK may not exist)
      var query = _client
          .from('staff_requests')
          .select();
      
      if (status != null && status != 'all') {
        query = query.eq('status', status);
      }
      
      final response = await query.order('created_at', ascending: false);
      return (response as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> createStaffRequest({
    required String requestType,
    required String description,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    await _client.from('staff_requests').insert({
      'staff_user_id': user.id,
      'request_type': requestType,
      'description': description,
      'status': 'pending',
    });
  }

  Future<List<Map<String, dynamic>>> getMyRequests() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await _client
          .from('staff_requests')
          .select()
          .eq('staff_user_id', user.id)
          .order('created_at', ascending: false);
      return (response as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      return [];
    }
  }

  // Legacy methods - kept for compatibility
  Future<List<Map<String, dynamic>>> getPendingPasswordRequests() async {
    return getAllStaffRequests(status: 'pending');
  }

  Future<void> approvePasswordRequest(String requestId, String staffUserId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    // Get staff email from auth.users via RPC
    final email = await _client
        .rpc('get_user_email', params: {'p_user_id': staffUserId});

    if (email == null || email.isEmpty) throw Exception('Staff email not found');

    // Send password reset email
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'https://driveglow.app/auth/update-password',
    );

    // Update request status
    await _client
        .from('staff_requests')
        .update({
          'status': 'approved',
          'approved_by': user.id,
          'resolved_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', requestId);
  }

  Future<void> denyPasswordRequest(String requestId, String staffUserId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not logged in');

    await _client
        .from('staff_requests')
        .update({
          'status': 'denied',
          'approved_by': user.id,
          'resolved_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', requestId);
  }
}
