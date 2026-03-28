enum BookingStatus {
  pending,
  confirmed,
  inProgress,
  completed,
  cancelled,
  lapsed,
}

class BookingModel {
  final String id;
  final String userId;
  final String serviceId;
  final String vehicleName;
  final String vehicleNumber;
  final String? vehicleId;
  final String? subscriptionVehicleId;
  final DateTime appointmentDate;
  final BookingStatus status;
  final double totalPrice;
  final String qrCodeData;
  final DateTime? checkInTime;
  final DateTime? completedAt;
  final DateTime createdAt;
  final bool isSubscriptionBooking;
  final DateTime? startedAt;
  final String? planId;
  final DateTime? originalPurchaseDate;
  final DateTime? subscriptionPeriodStart;
  final DateTime? subscriptionPeriodEnd;
  final DateTime? cancelledAt;
  final DateTime? lapsedAt;
  final String? scheduledTime; // Time slot: "09:00 AM", "09:30 AM", etc.

  BookingModel({
    required this.id,
    required this.userId,
    required this.serviceId,
    required this.vehicleName,
    required this.vehicleNumber,
    this.vehicleId,
    this.subscriptionVehicleId,
    required this.appointmentDate,
    required this.status,
    required this.totalPrice,
    required this.qrCodeData,
    this.checkInTime,
    this.completedAt,
    required this.createdAt,
    this.isSubscriptionBooking = false,
    this.startedAt,
    this.planId,
    this.originalPurchaseDate,
    this.subscriptionPeriodStart,
    this.subscriptionPeriodEnd,
    this.cancelledAt,
    this.lapsedAt,
    this.scheduledTime,
  });

  bool get isLapsed => status == BookingStatus.lapsed;
  bool get isPending => status == BookingStatus.pending;
  bool get isConfirmed => status == BookingStatus.confirmed;
  bool get isInProgress => status == BookingStatus.inProgress;
  bool get isCompleted => status == BookingStatus.completed;
  bool get isCancelled => status == BookingStatus.cancelled;

  // Is this a subscription (plan purchase)?
  bool get isSubscription =>
      isSubscriptionBooking && serviceId.startsWith('subscription::');

  // Is this a service from subscription?
  bool get isSubscriptionService =>
      serviceId.startsWith('subscription_service::');

  // Is this a standard care service?
  bool get isStandardCare => !isSubscriptionBooking;

  // Simple 6-digit token for staff to enter
  String get displayToken {
    // Generate 6-digit token from booking ID hash
    final hash = id.hashCode.abs();
    final token = (hash % 900000 + 100000).toString();
    return token;
  }

  bool get canStartService {
    if (isLapsed) return false;
    if (!isSubscriptionBooking) return isPending || isConfirmed;
    return (isPending || isConfirmed) &&
        startedAt == null &&
        DateTime.now().difference(createdAt).inHours < 24;
  }

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'],
      userId: json['user_id'],
      serviceId: json['service_id'],
      vehicleName: json['vehicle_name'],
      vehicleNumber: json['vehicle_number'],
      vehicleId: json['vehicle_id'],
      subscriptionVehicleId: json['subscription_vehicle_id'],
      appointmentDate: DateTime.parse(json['appointment_date']),
      status: BookingStatus.values.firstWhere(
        (e) =>
            e.toString().split('.').last.toLowerCase() ==
            (json['status'] as String).toLowerCase(),
        orElse: () => BookingStatus.pending,
      ),
      totalPrice: (json['total_price'] as num).toDouble(),
      qrCodeData: json['qr_code_data'] ?? '',
      checkInTime: json['check_in_time'] != null
          ? DateTime.parse(json['check_in_time'])
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      isSubscriptionBooking: json['is_subscription_booking'] ?? false,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'])
          : null,
      planId: json['plan_id'],
      originalPurchaseDate: json['original_purchase_date'] != null
          ? DateTime.parse(json['original_purchase_date'])
          : null,
      subscriptionPeriodStart: json['subscription_period_start'] != null
          ? DateTime.parse(json['subscription_period_start'])
          : null,
      subscriptionPeriodEnd: json['subscription_period_end'] != null
          ? DateTime.parse(json['subscription_period_end'])
          : null,
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'])
          : null,
      lapsedAt: json['lapsed_at'] != null
          ? DateTime.parse(json['lapsed_at'])
          : null,
      scheduledTime: json['scheduled_time'],
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'user_id': userId,
      'service_id': serviceId,
      'vehicle_name': vehicleName,
      'vehicle_number': vehicleNumber,
      'vehicle_id': vehicleId,
      'subscription_vehicle_id': subscriptionVehicleId,
      'appointment_date': appointmentDate.toIso8601String(),
      'status': status.toString().split('.').last,
      'total_price': totalPrice,
      'qr_code_data': qrCodeData,
      'is_subscription_booking': isSubscriptionBooking,
      'plan_id': planId,
      'original_purchase_date': originalPurchaseDate?.toIso8601String(),
      'subscription_period_start': subscriptionPeriodStart?.toIso8601String(),
      'subscription_period_end': subscriptionPeriodEnd?.toIso8601String(),
    };
    if (cancelledAt != null) {
      map['cancelled_at'] = cancelledAt!.toIso8601String();
    }
    if (lapsedAt != null) {
      map['lapsed_at'] = lapsedAt!.toIso8601String();
    }
    if (scheduledTime != null) {
      map['scheduled_time'] = scheduledTime;
    }
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }
}
