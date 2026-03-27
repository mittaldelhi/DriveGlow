class DashboardMetric {
  final String label;
  final String value;
  final String trend; // e.g. "+12%"
  final List<double> history; // For mini sparklines

  DashboardMetric({
    required this.label,
    required this.value,
    required this.trend,
    required this.history,
  });

  factory DashboardMetric.fromJson(Map<String, dynamic> json) {
    return DashboardMetric(
      label: json['label'],
      value: json['value'],
      trend: json['trend'],
      history: List<double>.from(json['history'] ?? []),
    );
  }
}

class RecentActivityItem {
  final String userName;
  final String avatarUrl;
  final String vehicleModel;
  final String serviceType;
  final double amount;
  final String status;

  RecentActivityItem({
    required this.userName,
    required this.avatarUrl,
    required this.vehicleModel,
    required this.serviceType,
    required this.amount,
    required this.status,
  });

  factory RecentActivityItem.fromJson(Map<String, dynamic> json) {
    return RecentActivityItem(
      userName: json['user_name'],
      avatarUrl: json['avatar_url'],
      vehicleModel: json['vehicle_model'],
      serviceType: json['service_type'],
      amount: (json['amount'] as num).toDouble(),
      status: json['status'],
    );
  }
}

class ServiceBreakdownItem {
  final String label;
  final double percentage;
  final String colorHex;

  ServiceBreakdownItem({
    required this.label,
    required this.percentage,
    required this.colorHex,
  });

  factory ServiceBreakdownItem.fromJson(Map<String, dynamic> json) {
    return ServiceBreakdownItem(
      label: json['label'],
      percentage: (json['percentage'] as num).toDouble(),
      colorHex: json['color_hex'],
    );
  }
}

class AdminDashboardModel {
  final List<DashboardMetric> metrics;
  final List<double> washRevenue;
  final List<double> accRevenue;
  final int carsWaiting;
  final String waitTime;
  final int activeStaff;
  final int totalStaff;
  final String aiOptimizationTitle;
  final String aiOptimizationDesc;
  final Map<String, double> unitScalability; // e.g. {'CAR WASH UNIT': 82.0}

  final List<double> weeklyGrowth; // For the big line chart
  final List<ServiceBreakdownItem> serviceBreakdown; // For the donut chart
  final List<RecentActivityItem> recentActivity;

  AdminDashboardModel({
    required this.metrics,
    required this.washRevenue,
    required this.accRevenue,
    required this.carsWaiting,
    required this.waitTime,
    required this.activeStaff,
    required this.totalStaff,
    required this.aiOptimizationTitle,
    required this.aiOptimizationDesc,
    required this.unitScalability,
    required this.weeklyGrowth,
    required this.serviceBreakdown,
    required this.recentActivity,
  });

  factory AdminDashboardModel.fromJson(Map<String, dynamic> json) {
    return AdminDashboardModel(
      metrics: (json['metrics'] as List? ?? [])
          .map((m) => DashboardMetric.fromJson(m))
          .toList(),
      washRevenue: List<double>.from(json['wash_revenue'] ?? []),
      accRevenue: List<double>.from(json['acc_revenue'] ?? []),
      carsWaiting: json['cars_waiting'] ?? 0,
      waitTime: json['wait_time'] ?? '',
      activeStaff: json['active_staff'] ?? 0,
      totalStaff: json['total_staff'] ?? 0,
      aiOptimizationTitle: json['ai_optimization_title'] ?? '',
      aiOptimizationDesc: json['ai_optimization_desc'] ?? '',
      unitScalability: Map<String, double>.from(json['unit_scalability'] ?? {}),
      weeklyGrowth: List<double>.from(json['weekly_growth'] ?? []),
      serviceBreakdown: (json['service_breakdown'] as List? ?? [])
          .map((s) => ServiceBreakdownItem.fromJson(s))
          .toList(),
      recentActivity: (json['recent_activity'] as List? ?? [])
          .map((a) => RecentActivityItem.fromJson(a))
          .toList(),
    );
  }
}
