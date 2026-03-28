import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'error_helper.dart';

class BookingValidationHelper {
  static final _client = Supabase.instance.client;

  static Future<String?> validateBooking({
    required String userId,
    required String vehicleNumber,
    required String serviceId,
    required String? planId,
    required bool isSubscriptionBooking,
    required BuildContext context,
  }) async {
    // Only validate subscription booking rules (daily limit check)
    // User can book anytime - no pending service restrictions
    if (isSubscriptionBooking && planId != null) {
      try {
        final subscriptionError = await validateSubscriptionBooking(
          userId: userId,
          vehicleNumber: vehicleNumber,
          serviceId: serviceId,
          planId: planId,
          context: context,
        );
        if (subscriptionError != null) {
          return subscriptionError;
        }
      } catch (e) {
        // Allow booking to proceed if validation fails
      }
    }

    // NO pending service check - user can book anytime, any service
    return null;
  }

  static Future<String?> validateSubscriptionBooking({
    required String userId,
    required String vehicleNumber,
    required String serviceId,
    required String planId,
    required BuildContext context,
  }) async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final twelveHoursAgo = now.subtract(const Duration(hours: 12));

      final bookingsResponse = await _client
          .from('bookings')
          .select('id, service_id, vehicle_number, created_at, status')
          .eq('user_id', userId)
          .eq('is_subscription_booking', true)
          .gte('created_at', twelveHoursAgo.toIso8601String())
          .neq('status', 'cancelled')
          .neq('status', 'completed')
          .neq('status', 'lapsed')
          .timeout(const Duration(seconds: 10));

      final bookings = (bookingsResponse as List).cast<Map<String, dynamic>>();

      for (final booking in bookings) {
        final bookingServiceId = (booking['service_id'] ?? '').toString();
        final bookingVehicleNumber = (booking['vehicle_number'] ?? '')
            .toString();
        final bookingStatus = (booking['status'] ?? '')
            .toString()
            .toLowerCase();

        if (bookingVehicleNumber.toUpperCase() == vehicleNumber.toUpperCase()) {
          if (bookingStatus == 'pending' ||
              bookingStatus == 'confirmed' ||
              bookingStatus == 'inprogress') {
            showErrorDialog(
              context,
              message:
                  'You already have a pending service for vehicle $vehicleNumber. Please complete or cancel it before booking again.',
              title: 'Already Pending Service',
            );
            return 'Already pending service for this car';
          }
        }

        final isSameService =
            bookingServiceId.contains(serviceId) ||
            serviceId.contains(bookingServiceId);
        final bookingCreatedAt = DateTime.tryParse(
          booking['created_at']?.toString() ?? '',
        );

        if (isSameService &&
            bookingVehicleNumber.toUpperCase() == vehicleNumber.toUpperCase() &&
            bookingCreatedAt != null) {
          final hoursSinceLastBooking = now
              .difference(bookingCreatedAt)
              .inHours;
          if (hoursSinceLastBooking < 12) {
            showErrorDialog(
              context,
              message:
                  'You have already booked this service for vehicle $vehicleNumber within the last 12 hours. Please try again later.',
              title: 'Cannot Book Again',
            );
            return 'Cannot book service again within 12 hours';
          }
        }
      }

      final todayBookingsResponse = await _client
          .from('bookings')
          .select('id, service_id, vehicle_number, created_at, status')
          .eq('user_id', userId)
          .eq('is_subscription_booking', true)
          .gte('created_at', todayStart.toIso8601String())
          .neq('status', 'completed')
          .neq('status', 'lapsed')
          .timeout(const Duration(seconds: 10));

      final todayBookings = (todayBookingsResponse as List)
          .cast<Map<String, dynamic>>();

      final subscriptionServiceIds = <String>{};
      for (final booking in todayBookings) {
        if ((booking['vehicle_number'] ?? '').toString().toUpperCase() ==
            vehicleNumber.toUpperCase()) {
          subscriptionServiceIds.add((booking['service_id'] ?? '').toString());
        }
      }

      for (final subServiceId in subscriptionServiceIds) {
        if (subServiceId.contains(serviceId) ||
            serviceId.contains(subServiceId)) {
          showErrorDialog(
            context,
            message:
                'Cannot book service again on same day from subscription. Try washing care service to book.',
            title: 'Same Day Booking Not Allowed',
          );
          return 'Cannot book service again on same day from subscription';
        }
      }
    } catch (e) {
      // Allow booking to proceed if validation fails
    }

    return null;
  }

  static Future<String?> checkPendingServiceForVehicle({
    required String userId,
    required String vehicleNumber,
    required BuildContext context,
  }) async {
    try {
      final response = await _client
          .from('bookings')
          .select('id, vehicle_number, status')
          .eq('user_id', userId)
          .eq('vehicle_number', vehicleNumber.toUpperCase())
          .neq('status', 'cancelled')
          .neq('status', 'completed')
          .neq('status', 'lapsed')
          .or(
            'status.eq.pending,status.eq.confirmed,status.eq.inProgress,status.eq.inprogress',
          )
          .limit(1)
          .timeout(const Duration(seconds: 10));

      final bookings = (response as List).cast<Map<String, dynamic>>();

      if (bookings.isNotEmpty) {
        showErrorDialog(
          context,
          message:
              'Already pending service for this car. Please complete or cancel the existing service before booking again.',
          title: 'Pending Service Exists',
        );
        return 'Already pending service for this car';
      }
    } catch (e) {
      // Allow booking to proceed
    }

    return null;
  }

  static Future<bool> hasActiveSubscriptionForVehicle({
    required String userId,
    required String vehicleNumber,
  }) async {
    // Use the unified hasActiveSubscription method
    return hasActiveSubscription(userId: userId, vehicleNumber: vehicleNumber);
  }

  static Future<bool> vehicleHasActiveSubscriptionForPlan({
    required String userId,
    required String vehicleNumber,
    required String planId,
  }) async {
    try {
      final now = DateTime.now();

      // RULEBOOK: Use subscription_period_end instead of hardcoded 365 days
      final response = await _client
          .from('bookings')
          .select(
            'id, vehicle_number, service_id, status, created_at, plan_id, subscription_period_end',
          )
          .eq('user_id', userId)
          .eq('vehicle_number', vehicleNumber.toUpperCase())
          .neq('status', 'cancelled')
          .neq('status', 'completed')
          .neq('status', 'lapsed')
          .order('created_at', ascending: false)
          .limit(10)
          .timeout(const Duration(seconds: 10));

      final bookings = (response as List).cast<Map<String, dynamic>>();

      for (final booking in bookings) {
        final serviceId = (booking['service_id'] ?? '').toString();
        final bookingPlanId = (booking['plan_id'] ?? '').toString();

        // Check if this is a subscription by service_id pattern
        final isSubscription =
            serviceId.startsWith('subscription::') ||
            serviceId.startsWith('subscription_service::') ||
            bookingPlanId == planId;

        if (isSubscription) {
          // Check subscription_period_end if available
          final periodEnd = booking['subscription_period_end'];
          if (periodEnd != null) {
            final periodEndDate = DateTime.tryParse(periodEnd.toString());
            if (periodEndDate != null && periodEndDate.isAfter(now)) {
              return true;
            }
            continue; // Period ended, check next booking
          }

          // Fallback: check created_at with hardcoded period (for legacy data)
          final createdAt = DateTime.tryParse(
            booking['created_at']?.toString() ?? '',
          );
          if (createdAt == null) continue;

          final daysSinceCreation = now.difference(createdAt).inDays;
          if (daysSinceCreation >= 365) continue;

          return true;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getVehiclesWithSubscription({
    required String userId,
    required String planId,
  }) async {
    try {
      final now = DateTime.now();

      // RULEBOOK: Use subscription_period_end instead of hardcoded 365 days
      final response = await _client
          .from('bookings')
          .select(
            'id, vehicle_number, vehicle_id, service_id, status, created_at, plan_id, subscription_period_end',
          )
          .eq('user_id', userId)
          .eq('is_subscription_booking', true)
          .neq('status', 'cancelled')
          .neq('status', 'completed')
          .neq('status', 'lapsed')
          .timeout(const Duration(seconds: 10));

      final bookings = (response as List).cast<Map<String, dynamic>>();

      final Map<String, Map<String, dynamic>> vehiclesMap = {};

      for (final booking in bookings) {
        final serviceId = (booking['service_id'] ?? '').toString();
        final bookingPlanId = (booking['plan_id'] ?? '').toString();

        if (serviceId.contains(planId) || bookingPlanId == planId) {
          // Check subscription_period_end if available
          final periodEnd = booking['subscription_period_end'];
          bool isActive = false;

          if (periodEnd != null) {
            final periodEndDate = DateTime.tryParse(periodEnd.toString());
            isActive = periodEndDate != null && periodEndDate.isAfter(now);
          } else {
            // Fallback: check created_at with hardcoded period (for legacy data)
            final createdAt = DateTime.tryParse(
              booking['created_at']?.toString() ?? '',
            );
            if (createdAt != null) {
              final daysSinceCreation = now.difference(createdAt).inDays;
              isActive = daysSinceCreation < 365;
            }
          }

          if (isActive) {
            final vehicleNumber = (booking['vehicle_number'] ?? '').toString();
            if (vehicleNumber.isNotEmpty &&
                !vehiclesMap.containsKey(vehicleNumber)) {
              vehiclesMap[vehicleNumber] = booking;
            }
          }
        }
      }

      return vehiclesMap.values.toList();
    } catch (e) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>>
  getVehiclesWithoutSubscriptionForPlan({
    required String userId,
    required String planId,
    required List<String> allVehicleNumbers,
  }) async {
    final vehiclesWithSub = await getVehiclesWithSubscription(
      userId: userId,
      planId: planId,
    );
    final subscribedVehicleNumbers = vehiclesWithSub
        .map((v) => (v['vehicle_number'] ?? '').toString().toUpperCase())
        .toSet();

    return allVehicleNumbers
        .where((v) => !subscribedVehicleNumbers.contains(v.toUpperCase()))
        .map((v) => {'vehicle_number': v})
        .toList();
  }

  static Future<Map<String, int>> getSubscriptionUsageForVehicle({
    required String userId,
    required String vehicleNumber,
    required String planId,
    int maxServices = 4,
  }) async {
    try {
      final now = DateTime.now();

      // RULEBOOK: Count ALL bookings including cancelled/lapsed
      // Status does not matter - if a booking exists, it counts
      final response = await _client
          .from('bookings')
          .select('id, service_id, vehicle_number, status, created_at, plan_id')
          .eq('user_id', userId)
          .eq('vehicle_number', vehicleNumber.toUpperCase())
          .timeout(const Duration(seconds: 10));

      final bookings = (response as List).cast<Map<String, dynamic>>();

      DateTime? periodStart;
      int usedCount = 0;

      for (final booking in bookings) {
        final serviceId = (booking['service_id'] ?? '').toString();
        final bookingPlanId = (booking['plan_id'] ?? '').toString();

        // Check if this is a subscription by service_id pattern
        final isSubscription =
            serviceId.startsWith('subscription::') ||
            serviceId.startsWith('subscription_service::') ||
            bookingPlanId == planId;

        if (isSubscription) {
          final createdAt = DateTime.tryParse(
            booking['created_at']?.toString() ?? '',
          );
          if (createdAt == null) continue;

          if (periodStart == null || createdAt.isBefore(periodStart)) {
            periodStart = createdAt;
          }

          // RULEBOOK: ALL bookings count - pending, confirmed, inProgress, completed, cancelled, lapsed
          // If a booking exists, it counts as used
          usedCount++;
        }
      }

      // Calculate remaining based on maxServices from plan
      final remaining = maxServices - usedCount;

      return {'used': usedCount, 'remaining': remaining > 0 ? remaining : 0};
    } catch (e) {
      return {'used': 0, 'remaining': 0};
    }
  }

  static Future<Map<String, int>> getPerServiceUsage({
    required String userId,
    required String vehicleNumber,
    required String planId,
    required List<String> includedServiceIds,
  }) async {
    try {
      // RULEBOOK: Count ALL bookings including cancelled/lapsed
      final response = await _client
          .from('bookings')
          .select('id, service_id, vehicle_number, status, created_at, plan_id')
          .eq('user_id', userId)
          .eq('vehicle_number', vehicleNumber.toUpperCase())
          .timeout(const Duration(seconds: 10));

      final bookings = (response as List).cast<Map<String, dynamic>>();

      final Map<String, int> serviceUsage = {};

      for (final serviceId in includedServiceIds) {
        serviceUsage[serviceId] = 0;
      }

      for (final booking in bookings) {
        final bookingServiceId = (booking['service_id'] ?? '').toString();
        final bookingPlanId = (booking['plan_id'] ?? '').toString();

        final isSubscription =
            bookingServiceId.startsWith('subscription::') ||
            bookingServiceId.startsWith('subscription_service::') ||
            bookingPlanId == planId;

        if (isSubscription) {
          // RULEBOOK: ALL bookings count - pending, confirmed, inProgress, completed, cancelled, lapsed
          for (final serviceId in includedServiceIds) {
            if (bookingServiceId.contains(serviceId) ||
                serviceId.contains(bookingServiceId)) {
              serviceUsage[serviceId] = (serviceUsage[serviceId] ?? 0) + 1;
            }
          }
        }
      }

      return serviceUsage;
    } catch (e) {
      return {};
    }
  }

  static Future<String?> checkCanBuySubscription({
    required String userId,
    required String vehicleNumber,
    required String planId,
    required BuildContext context,
  }) async {
    final hasSubscription = await vehicleHasActiveSubscriptionForPlan(
      userId: userId,
      vehicleNumber: vehicleNumber,
      planId: planId,
    );

    if (hasSubscription) {
      showErrorDialog(
        context,
        message:
            'You already have an active subscription for vehicle $vehicleNumber. You cannot buy another subscription for the same car.',
        title: 'Subscription Exists',
      );
      return 'Already have subscription for this car';
    }

    return null;
  }

  static Future<int> getRemainingDaysInCurrentPlan({
    required String userId,
    required String vehicleNumber,
  }) async {
    try {
      final now = DateTime.now();

      final response = await _client
          .from('bookings')
          .select('id, vehicle_number, service_id, status, created_at, plan_id')
          .eq('user_id', userId)
          .eq('vehicle_number', vehicleNumber.toUpperCase())
          .eq('is_subscription_booking', true)
          .neq('status', 'cancelled')
          .neq('status', 'completed')
          .neq('status', 'lapsed')
          .order('created_at', ascending: false)
          .limit(1)
          .timeout(const Duration(seconds: 10));

      final bookings = (response as List).cast<Map<String, dynamic>>();

      if (bookings.isEmpty) return 0;

      final booking = bookings.first;
      final createdAt = DateTime.tryParse(
        booking['created_at']?.toString() ?? '',
      );
      if (createdAt == null) return 0;

      final serviceId = (booking['service_id'] ?? '').toString();
      final isMonthly = serviceId.toLowerCase().contains('monthly');

      final periodEnd = isMonthly
          ? createdAt.add(const Duration(days: 30))
          : createdAt.add(const Duration(days: 365));

      final remaining = periodEnd.difference(now).inDays;
      return remaining > 0 ? remaining : 0;
    } catch (e) {
      return 0;
    }
  }

  static Future<String?> getVehicleSubscriptionPlanId({
    required String userId,
    required String vehicleNumber,
  }) async {
    try {
      final response = await _client
          .from('bookings')
          .select('id, vehicle_number, service_id, status, created_at')
          .eq('user_id', userId)
          .eq('vehicle_number', vehicleNumber.toUpperCase())
          .eq('is_subscription_booking', true)
          .neq('status', 'cancelled')
          .neq('status', 'completed')
          .neq('status', 'lapsed')
          .order('created_at', ascending: false)
          .limit(1)
          .timeout(const Duration(seconds: 10));

      final bookings = (response as List).cast<Map<String, dynamic>>();

      if (bookings.isEmpty) return null;

      final serviceId = (bookings.first['service_id'] ?? '').toString();
      if (serviceId.contains('subscription::')) {
        final parts = serviceId.split('::');
        if (parts.length >= 2) {
          return parts[1];
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> hasActiveSubscription({
    required String userId,
    required String vehicleNumber,
  }) async {
    try {
      print('[HELPER] Checking subscription for: $vehicleNumber');
      final now = DateTime.now();
      final normalizedPlate = vehicleNumber.toUpperCase().trim();

      // Primary: Check user_subscriptions table (source of truth)
      // Only check: valid_until > now (ignore is_active flag)
      final response = await _client
          .from('user_subscriptions')
          .select('id, vehicle_number, valid_until')
          .eq('user_id', userId)
          .eq('vehicle_number', normalizedPlate)
          .gt('valid_until', now.toIso8601String())
          .limit(1)
          .timeout(const Duration(seconds: 10));

      final subscriptions = (response as List).cast<Map<String, dynamic>>();
      print(
        '[HELPER] user_subscriptions found ${subscriptions.length} for $vehicleNumber',
      );

      if (subscriptions.isNotEmpty) {
        print('[HELPER] Vehicle $vehicleNumber has active subscription: true');
        return true;
      }

      print('[HELPER] Vehicle $vehicleNumber has subscription: false');
      return false;
    } catch (e) {
      print('[HELPER] Error checking subscription for $vehicleNumber: $e');
      return false;
    }
  }

  static bool? _checkBookingForActiveSubscription(
    List<Map<String, dynamic>> bookings,
    DateTime now,
  ) {
    for (final booking in bookings) {
      final serviceId = (booking['service_id'] ?? '').toString();

      // Skip if it's a regular service (service::)
      if (serviceId.startsWith('service::')) {
        continue;
      }

      // Check subscription_period_end if available
      final periodEnd = booking['subscription_period_end'];
      if (periodEnd != null) {
        final periodEndDate = DateTime.tryParse(periodEnd.toString());
        if (periodEndDate != null) {
          final isActive = periodEndDate.isAfter(now);
          return isActive;
        }
      }

      // Fallback: check created_at with hardcoded period (for legacy data)
      final createdAt = DateTime.tryParse(
        booking['created_at']?.toString() ?? '',
      );
      if (createdAt != null) {
        final daysSinceCreation = now.difference(createdAt).inDays;
        if (daysSinceCreation < 365) {
          return true;
        }
      }
    }
    return null; // No active subscription found in these bookings
  }

  static Future<Map<String, bool>> getAllVehiclesSubscriptionStatus({
    required String userId,
    required List<String> vehicleNumbers,
  }) async {
    final Map<String, bool> result = {};
    if (vehicleNumbers.isEmpty) return result;

    try {
      final now = DateTime.now();
      print(
        '[HELPER] getAllVehiclesSubscriptionStatus for ${vehicleNumbers.length} vehicles',
      );

      // Primary: Check user_subscriptions table (source of truth)
      // Only check: valid_until > now (ignore is_active flag)
      final response = await _client
          .from('user_subscriptions')
          .select('id, vehicle_number, valid_until')
          .eq('user_id', userId)
          .gt('valid_until', now.toIso8601String())
          .timeout(const Duration(seconds: 10));

      final subscriptions = (response as List).cast<Map<String, dynamic>>();
      print(
        '[HELPER] user_subscriptions found ${subscriptions.length} active subscriptions',
      );

      // Initialize all vehicles as false
      for (final vehicleNumber in vehicleNumbers) {
        result[vehicleNumber.toUpperCase().trim()] = false;
      }

      // Mark vehicles with active subscriptions as true
      for (final sub in subscriptions) {
        final vehiclePlate = (sub['vehicle_number'] ?? '')
            .toString()
            .toUpperCase()
            .trim();
        if (result.containsKey(vehiclePlate)) {
          result[vehiclePlate] = true;
          print('[HELPER] Vehicle $vehiclePlate has subscription: true');
        }
      }

      // Log vehicles without subscription
      for (final vehicleNumber in vehicleNumbers) {
        final normalizedPlate = vehicleNumber.toUpperCase().trim();
        if (result[normalizedPlate] == false) {
          print('[HELPER] Vehicle $normalizedPlate has subscription: false');
        }
      }
    } catch (e) {
      print('[HELPER] Error in getAllVehiclesSubscriptionStatus: $e');
      for (final vehicleNumber in vehicleNumbers) {
        result[vehicleNumber.toUpperCase()] = false;
      }
    }

    return result;
  }

  static Future<bool> hasBookedTodayForSubscription({
    required String userId,
    required String planId,
    required String vehicleNumber,
  }) async {
    try {
      final todayStart = DateTime.now();
      final todayStartUtc = DateTime(
        todayStart.year,
        todayStart.month,
        todayStart.day,
      );

      final response = await _client
          .from('bookings')
          .select('id')
          .eq('user_id', userId)
          .eq('vehicle_number', vehicleNumber.toUpperCase())
          .eq('plan_id', planId)
          .gte('created_at', todayStartUtc.toIso8601String())
          .neq('status', 'lapsed')
          .neq('status', 'completed')
          .limit(1)
          .timeout(const Duration(seconds: 5));

      return (response as List).isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  static Future<String?> checkDailyLimitForSubscription({
    required String userId,
    required String planId,
    required String vehicleNumber,
    required BuildContext context,
  }) async {
    try {
      final hasBookedToday = await hasBookedTodayForSubscription(
        userId: userId,
        planId: planId,
        vehicleNumber: vehicleNumber,
      );

      if (hasBookedToday) {
        showErrorDialog(
          context,
          message:
              'You have already booked a service from this subscription today. You can book one service per day.',
          title: 'Daily Limit Reached',
        );
        return 'Daily limit reached';
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}
