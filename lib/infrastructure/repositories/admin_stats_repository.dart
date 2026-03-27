import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/admin_stats_model.dart';

class AdminStatsRepository {
  final _client = Supabase.instance.client;

  Future<AdminDashboardModel> getDashboardStats() async {
    try {
      final bookingsResponse = await _client
          .from('bookings')
          .select(
            'id,user_id,service_id,vehicle_name,total_price,status,created_at,appointment_date',
          )
          .order('created_at', ascending: false);

      final feedbackResponse = await _safeFeedbackRead();
      final staffCounts = await _safeStaffCounts();
      final bookings = (bookingsResponse as List).cast<Map<String, dynamic>>();
      final feedback = feedbackResponse.cast<Map<String, dynamic>>();

      final totalBookings = bookings.length;
      final completed = bookings
          .where((b) => (b['status'] as String?) == 'completed')
          .toList();
      final waiting = bookings
          .where(
            (b) =>
                (b['status'] as String?) == 'pending' ||
                (b['status'] as String?) == 'confirmed',
          )
          .length;
      final active = bookings
          .where((b) => (b['status'] as String?) == 'inProgress')
          .length;
      final todayBookings = _todayBookingsCount(bookings);

      final revenue = completed.fold<double>(
        0,
        (sum, b) => sum + ((b['total_price'] as num?)?.toDouble() ?? 0),
      );

      final avgRating = feedback.isEmpty
          ? 0.0
          : feedback.fold<double>(
                  0,
                  (sum, f) => sum + ((f['rating'] as num?)?.toDouble() ?? 0),
                ) /
                feedback.length;
      final satisfaction = (avgRating * 20).clamp(0, 100);

      final weeklyGrowth = _weeklyRevenue(completed);
      final serviceBreakdown = _serviceBreakdown(bookings);
      final recent = _recentActivity(bookings);
      final staffActive = staffCounts.$1;
      final staffTotal = staffCounts.$2;

      final metrics = [
        DashboardMetric(
          label: 'Net Revenue',
          value: 'Rs ${revenue.toStringAsFixed(0)}',
          trend: _revenueTrend(completed),
          history: _lastNDaysCounts(bookings, days: 5),
        ),
        DashboardMetric(
          label: 'Total Bookings',
          value: '$totalBookings',
          trend: _countTrend(bookings),
          history: _lastNDaysCounts(bookings, days: 5),
        ),
        DashboardMetric(
          label: 'Today Bookings',
          value: '$todayBookings',
          trend: _todayVsYesterdayTrend(bookings),
          history: _lastNDaysCounts(bookings, days: 5),
        ),
        DashboardMetric(
          label: 'Customer Satisfaction',
          value: '${satisfaction.toStringAsFixed(0)}%',
          trend: feedback.isEmpty
              ? '0.0%'
              : '+${(avgRating / 5 * 2).toStringAsFixed(1)}%',
          history: _ratingHistory(feedback),
        ),
      ];

      return AdminDashboardModel(
        metrics: metrics,
        washRevenue: weeklyGrowth,
        accRevenue: weeklyGrowth.map((e) => e * 0.25).toList(),
        carsWaiting: waiting,
        waitTime: '${math.max(5, waiting * 4)}m wait',
        activeStaff: staffActive,
        totalStaff: staffTotal,
        aiOptimizationTitle: 'Live Ops Insight',
        aiOptimizationDesc:
            'Active: $active • Waiting: $waiting • Completed: ${completed.length}',
        unitScalability: {
          'CAR WASH UNIT': _ratio(active + completed.length, totalBookings),
          'MECHANIC BAY': _ratio(active, totalBookings),
          'RETAIL/ACCESSORIES': _ratio(waiting, totalBookings),
        },
        weeklyGrowth: weeklyGrowth,
        serviceBreakdown: serviceBreakdown,
        recentActivity: recent,
      );
    } catch (_) {
      return _fallbackDashboard();
    }
  }

  Future<List<Map<String, dynamic>>> _safeFeedbackRead() async {
    try {
      final response = await _client
          .from('service_feedback')
          .select('rating,created_at');
      return (response as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<(int, int)> _safeStaffCounts() async {
    try {
      // Use user_profiles instead of staff_users
      final response = await _client.from('user_profiles').select('membership_tier');
      final rows = (response as List).cast<Map<String, dynamic>>();
      final staffCount = rows.where((r) => 
        (r['membership_tier'] as String?)?.toUpperCase() == 'STAFF' ||
        (r['membership_tier'] as String?)?.toUpperCase() == 'ADMIN'
      ).length;
      return (staffCount, staffCount);
    } catch (_) {
      return (0, 0);
    }
  }

  List<double> _weeklyRevenue(List<Map<String, dynamic>> completed) {
    final now = DateTime.now();
    final result = List<double>.filled(7, 0);
    for (final b in completed) {
      final created = DateTime.tryParse((b['created_at'] ?? '').toString());
      if (created == null) continue;
      final diff = now
          .difference(DateTime(created.year, created.month, created.day))
          .inDays;
      if (diff < 0 || diff > 6) continue;
      final idx = 6 - diff;
      result[idx] += ((b['total_price'] as num?)?.toDouble() ?? 0);
    }
    return result;
  }

  List<ServiceBreakdownItem> _serviceBreakdown(
    List<Map<String, dynamic>> bookings,
  ) {
    if (bookings.isEmpty) {
      return [
        ServiceBreakdownItem(
          label: 'No Data',
          percentage: 1,
          colorHex: '0xFF94A3B8',
        ),
      ];
    }

    int services = 0;
    int subscriptions = 0;
    int subscriptionServices = 0;

    for (final b in bookings) {
      final serviceId = (b['service_id'] ?? '').toString();
      if (serviceId.startsWith('subscription_service::')) {
        subscriptionServices++;
      } else if (serviceId.startsWith('subscription::')) {
        subscriptions++;
      } else {
        services++;
      }
    }

    final total = math
        .max(1, services + subscriptions + subscriptionServices)
        .toDouble();
    return [
      ServiceBreakdownItem(
        label: 'Standard Services',
        percentage: services / total,
        colorHex: '0xFFF0541E',
      ),
      ServiceBreakdownItem(
        label: 'Subscriptions',
        percentage: subscriptions / total,
        colorHex: '0xFF0EA5E9',
      ),
      ServiceBreakdownItem(
        label: 'Sub Service Usage',
        percentage: subscriptionServices / total,
        colorHex: '0xFF22C55E',
      ),
    ];
  }

  List<RecentActivityItem> _recentActivity(
    List<Map<String, dynamic>> bookings,
  ) {
    return bookings.take(6).map((b) {
      final serviceRef = (b['service_id'] ?? '').toString();
      final serviceName = _nameFromServiceRef(serviceRef);
      return RecentActivityItem(
        userName: 'User ${_short((b['user_id'] ?? '').toString())}',
        avatarUrl: 'https://ui-avatars.com/api/?name=User&background=random',
        vehicleModel: (b['vehicle_name'] ?? 'Vehicle').toString(),
        serviceType: serviceName,
        amount: (b['total_price'] as num?)?.toDouble() ?? 0,
        status: (b['status'] ?? '').toString(),
      );
    }).toList();
  }

  List<double> _lastNDaysCounts(
    List<Map<String, dynamic>> bookings, {
    int days = 5,
  }) {
    final now = DateTime.now();
    final list = List<double>.filled(days, 0);
    for (final b in bookings) {
      final created = DateTime.tryParse((b['created_at'] ?? '').toString());
      if (created == null) continue;
      final diff = now
          .difference(DateTime(created.year, created.month, created.day))
          .inDays;
      if (diff < 0 || diff >= days) continue;
      list[days - 1 - diff] += 1;
    }
    return list;
  }

  List<double> _ratingHistory(List<Map<String, dynamic>> feedback) {
    if (feedback.isEmpty) return [0, 0, 0, 0, 0];
    final data = feedback
        .take(5)
        .map((f) => ((f['rating'] as num?)?.toDouble() ?? 0))
        .toList()
        .reversed
        .toList();
    while (data.length < 5) {
      data.insert(0, 0);
    }
    return data;
  }

  String _revenueTrend(List<Map<String, dynamic>> completed) {
    final weekly = _weeklyRevenue(completed);
    if (weekly.length < 2) return '0.0%';
    final prev = weekly.sublist(0, 3).fold<double>(0, (a, b) => a + b);
    final curr = weekly.sublist(4).fold<double>(0, (a, b) => a + b);
    if (prev == 0) return curr > 0 ? '+100.0%' : '0.0%';
    final pct = ((curr - prev) / prev) * 100;
    final sign = pct >= 0 ? '+' : '';
    return '$sign${pct.toStringAsFixed(1)}%';
  }

  String _countTrend(List<Map<String, dynamic>> bookings) {
    final history = _lastNDaysCounts(bookings, days: 6);
    final prev = history.sublist(0, 3).fold<double>(0, (a, b) => a + b);
    final curr = history.sublist(3).fold<double>(0, (a, b) => a + b);
    if (prev == 0) return curr > 0 ? '+100.0%' : '0.0%';
    final pct = ((curr - prev) / prev) * 100;
    final sign = pct >= 0 ? '+' : '';
    return '$sign${pct.toStringAsFixed(1)}%';
  }

  int _todayBookingsCount(List<Map<String, dynamic>> bookings) {
    final today = DateTime.now();
    return bookings.where((b) {
      final created = DateTime.tryParse((b['created_at'] ?? '').toString());
      if (created == null) return false;
      return created.year == today.year &&
          created.month == today.month &&
          created.day == today.day;
    }).length;
  }

  String _todayVsYesterdayTrend(List<Map<String, dynamic>> bookings) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    int todayCount = 0;
    int yesterdayCount = 0;

    for (final b in bookings) {
      final created = DateTime.tryParse((b['created_at'] ?? '').toString());
      if (created == null) continue;
      final date = DateTime(created.year, created.month, created.day);
      if (date == today) {
        todayCount++;
      } else if (date == yesterday) {
        yesterdayCount++;
      }
    }

    if (yesterdayCount == 0) return todayCount > 0 ? '+100.0%' : '0.0%';
    final pct = ((todayCount - yesterdayCount) / yesterdayCount) * 100;
    final sign = pct >= 0 ? '+' : '';
    return '$sign${pct.toStringAsFixed(1)}%';
  }

  double _ratio(int value, int total) {
    if (total <= 0) return 0;
    return (value / total).clamp(0, 1);
  }

  String _short(String value) {
    if (value.length < 6) return value;
    return value.substring(0, 6).toUpperCase();
  }

  String _nameFromServiceRef(String ref) {
    final parts = ref.split('::');
    if (parts.length >= 3) return parts.sublist(2).join('::');
    return ref;
  }

  AdminDashboardModel _fallbackDashboard() {
    return AdminDashboardModel(
      metrics: [
        DashboardMetric(
          label: 'Net Revenue',
          value: 'Rs 0',
          trend: '0.0%',
          history: [0, 0, 0, 0, 0],
        ),
        DashboardMetric(
          label: 'Total Bookings',
          value: '0',
          trend: '0.0%',
          history: [0, 0, 0, 0, 0],
        ),
        DashboardMetric(
          label: 'Customer Satisfaction',
          value: '0%',
          trend: '0.0%',
          history: [0, 0, 0, 0, 0],
        ),
      ],
      washRevenue: const [0, 0, 0, 0, 0, 0, 0],
      accRevenue: const [0, 0, 0, 0, 0, 0, 0],
      carsWaiting: 0,
      waitTime: '0m wait',
      activeStaff: 0,
      totalStaff: 0,
      aiOptimizationTitle: 'Live Ops Insight',
      aiOptimizationDesc: 'No live data available',
      unitScalability: const {
        'CAR WASH UNIT': 0,
        'MECHANIC BAY': 0,
        'RETAIL/ACCESSORIES': 0,
      },
      weeklyGrowth: const [0, 0, 0, 0, 0, 0, 0],
      serviceBreakdown: [
        ServiceBreakdownItem(
          label: 'No Data',
          percentage: 1,
          colorHex: '0xFF94A3B8',
        ),
      ],
      recentActivity: const [],
    );
  }
}
