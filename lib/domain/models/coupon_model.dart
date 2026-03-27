enum CouponType { percentage, fixedAmount }

enum CouponStatus { active, inactive, expired }

class CouponModel {
  final String id;
  final String code;
  final String description;
  final CouponType type; // percentage or fixed amount
  final double value; // e.g., 10 for 10% or 500 for ₹500 off
  final double? minPurchaseAmount; // Minimum purchase to apply coupon
  final double? maxDiscountAmount; // Maximum discount cap
  final int usageLimit; // Total uses allowed (-1 for unlimited)
  final int usageCount; // Current usage count
  final DateTime validFrom;
  final DateTime validUntil;
  final List<String> applicablePlans; // List of plan IDs (empty = all)
  final CouponStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  CouponModel({
    required this.id,
    required this.code,
    required this.description,
    required this.type,
    required this.value,
    this.minPurchaseAmount,
    this.maxDiscountAmount,
    required this.usageLimit,
    required this.usageCount,
    required this.validFrom,
    required this.validUntil,
    required this.applicablePlans,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Check if coupon is valid
  bool get isValid {
    final now = DateTime.now();
    return status == CouponStatus.active &&
        now.isAfter(validFrom) &&
        now.isBefore(validUntil) &&
        (usageLimit == -1 || usageCount < usageLimit);
  }

  /// Check if coupon can be applied to a plan
  bool canApplyToPlan(String planId) {
    return applicablePlans.isEmpty || applicablePlans.contains(planId);
  }

  /// Calculate discount amount
  double calculateDiscount(double amount) {
    if (!isValid) return 0;
    if (minPurchaseAmount != null && amount < minPurchaseAmount!) {
      return 0;
    }

    double discount = 0;
    if (type == CouponType.percentage) {
      discount = (amount * value) / 100;
    } else {
      discount = value;
    }

    // Apply max discount cap if set
    if (maxDiscountAmount != null && discount > maxDiscountAmount!) {
      discount = maxDiscountAmount!;
    }

    return discount;
  }

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    return CouponModel(
      id: json['id'] as String,
      code: json['code'] as String,
      description: json['description'] as String? ?? '',
      type: CouponType.values.firstWhere(
        (e) => e.name == (json['type'] as String).toLowerCase(),
        orElse: () => CouponType.percentage,
      ),
      value: (json['value'] as num).toDouble(),
      minPurchaseAmount: json['min_purchase_amount'] != null
          ? (json['min_purchase_amount'] as num).toDouble()
          : null,
      maxDiscountAmount: json['max_discount_amount'] != null
          ? (json['max_discount_amount'] as num).toDouble()
          : null,
      usageLimit: json['usage_limit'] as int? ?? -1,
      usageCount: json['usage_count'] as int? ?? 0,
      validFrom: DateTime.parse(json['valid_from'] as String),
      validUntil: DateTime.parse(json['valid_until'] as String),
      applicablePlans:
          List<String>.from(json['applicable_plans'] as List? ?? []),
      status: CouponStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String).toLowerCase(),
        orElse: () => CouponStatus.active,
      ),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'description': description,
      'type': type.name,
      'value': value,
      'min_purchase_amount': minPurchaseAmount,
      'max_discount_amount': maxDiscountAmount,
      'usage_limit': usageLimit,
      'usage_count': usageCount,
      'valid_from': validFrom.toIso8601String(),
      'valid_until': validUntil.toIso8601String(),
      'applicable_plans': applicablePlans,
      'status': status.name,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  CouponModel copyWith({
    String? id,
    String? code,
    String? description,
    CouponType? type,
    double? value,
    double? minPurchaseAmount,
    double? maxDiscountAmount,
    int? usageLimit,
    int? usageCount,
    DateTime? validFrom,
    DateTime? validUntil,
    List<String>? applicablePlans,
    CouponStatus? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CouponModel(
      id: id ?? this.id,
      code: code ?? this.code,
      description: description ?? this.description,
      type: type ?? this.type,
      value: value ?? this.value,
      minPurchaseAmount: minPurchaseAmount ?? this.minPurchaseAmount,
      maxDiscountAmount: maxDiscountAmount ?? this.maxDiscountAmount,
      usageLimit: usageLimit ?? this.usageLimit,
      usageCount: usageCount ?? this.usageCount,
      validFrom: validFrom ?? this.validFrom,
      validUntil: validUntil ?? this.validUntil,
      applicablePlans: applicablePlans ?? this.applicablePlans,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
