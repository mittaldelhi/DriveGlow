class StaffProfileModel {
  final String id;
  final String userId;
  final String employeeId;
  final String fullName;
  final String email;
  final String phone;
  final String address;
  final String roleKey;
  final String? profilePhotoUrl;
  final double? salary;
  final String? bankAccountNumber;
  final String? ifscCode;
  final DateTime? dateOfJoining;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  StaffProfileModel({
    required this.id,
    required this.userId,
    required this.employeeId,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.address,
    required this.roleKey,
    this.profilePhotoUrl,
    this.salary,
    this.bankAccountNumber,
    this.ifscCode,
    this.dateOfJoining,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StaffProfileModel.fromJson(Map<String, dynamic> json) {
    return StaffProfileModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? json['id'] ?? '',
      employeeId: json['employee_id'] ?? '',
      fullName: json['full_name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      roleKey: json['role_key'] ?? 'WASHER',
      profilePhotoUrl: json['profile_photo_url'],
      salary: json['salary'] != null ? (json['salary'] as num).toDouble() : null,
      bankAccountNumber: json['bank_account_number'],
      ifscCode: json['ifsc_code'],
      dateOfJoining: json['date_of_joining'] != null 
          ? DateTime.tryParse(json['date_of_joining'].toString())
          : null,
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'employee_id': employeeId,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'address': address,
      'role_key': roleKey,
      'profile_photo_url': profilePhotoUrl,
      'salary': salary,
      'bank_account_number': bankAccountNumber,
      'ifsc_code': ifscCode,
      'date_of_joining': dateOfJoining?.toIso8601String().split('T').first,
      'is_active': isActive,
    };
  }

  StaffProfileModel copyWith({
    String? id,
    String? userId,
    String? employeeId,
    String? fullName,
    String? email,
    String? phone,
    String? address,
    String? roleKey,
    String? profilePhotoUrl,
    double? salary,
    String? bankAccountNumber,
    String? ifscCode,
    DateTime? dateOfJoining,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StaffProfileModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      employeeId: employeeId ?? this.employeeId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      roleKey: roleKey ?? this.roleKey,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      salary: salary ?? this.salary,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      ifscCode: ifscCode ?? this.ifscCode,
      dateOfJoining: dateOfJoining ?? this.dateOfJoining,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class StaffWorkStats {
  final int totalWorkDays;
  final double totalWorkHours;
  final int totalServicesCompleted;
  final int currentMonthServices;
  final int pendingServices;
  final double currentMonthHours;

  StaffWorkStats({
    required this.totalWorkDays,
    required this.totalWorkHours,
    required this.totalServicesCompleted,
    required this.currentMonthServices,
    required this.pendingServices,
    required this.currentMonthHours,
  });

  factory StaffWorkStats.fromJson(Map<String, dynamic> json) {
    return StaffWorkStats(
      totalWorkDays: (json['total_work_days'] as num?)?.toInt() ?? 0,
      totalWorkHours: (json['total_work_hours'] as num?)?.toDouble() ?? 0.0,
      totalServicesCompleted: (json['total_services_completed'] as num?)?.toInt() ?? 0,
      currentMonthServices: (json['current_month_services'] as num?)?.toInt() ?? 0,
      pendingServices: (json['pending_services'] as num?)?.toInt() ?? 0,
      currentMonthHours: (json['current_month_hours'] as num?)?.toDouble() ?? 0.0,
    );
  }

  factory StaffWorkStats.empty() {
    return StaffWorkStats(
      totalWorkDays: 0,
      totalWorkHours: 0.0,
      totalServicesCompleted: 0,
      currentMonthServices: 0,
      pendingServices: 0,
      currentMonthHours: 0.0,
    );
  }
}
