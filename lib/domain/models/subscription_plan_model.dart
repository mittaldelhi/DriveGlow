class SubscriptionPlanModel {
  final String id;
  final String name;
  final String tier;
  final String vehicleCategory;
  final String duration;
  final double price;
  final double? originalPrice;
  final String description;
  final List<String> features;
  final bool isFeatured;
  final bool isActive;
  final int displayOrder;
  final List<String> includedServiceIds;
  final DateTime createdAt;
  final bool showUnlimited;
  final int? monthlyCapOverride;
  final Map<String, int>? serviceUsageLimits;
  final int dailyLimit;
  final String fairUsagePolicy;

  SubscriptionPlanModel({
    required this.id,
    required this.name,
    this.tier = 'Silver',
    this.vehicleCategory = 'Sedan',
    this.duration = 'Monthly',
    required this.price,
    this.originalPrice,
    this.description = '',
    this.features = const [],
    this.isFeatured = false,
    this.isActive = true,
    this.displayOrder = 0,
    this.includedServiceIds = const [],
    required this.createdAt,
    this.showUnlimited = false,
    this.monthlyCapOverride,
    this.serviceUsageLimits,
    this.dailyLimit = 1,
    this.fairUsagePolicy = '',
  });

  int? get effectiveMonthlyCap => monthlyCapOverride;

  String? get savingsText {
    if (originalPrice == null || originalPrice! <= price) return null;
    return 'Save ₹${(originalPrice! - price).toInt()}';
  }

  String? get monthlyEquivalent {
    if (duration != 'Yearly') return null;
    return '~ ₹${(price / 12).toInt()}/mo';
  }

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) {
    List<String> parsedFeatures = [];
    if (json['features'] != null) {
      if (json['features'] is List) {
        parsedFeatures = List<String>.from(json['features']);
      }
    }

    Map<String, int>? parsedUsageLimits;
    if (json['service_usage_limits'] != null) {
      if (json['service_usage_limits'] is Map) {
        parsedUsageLimits = Map<String, int>.from(
          (json['service_usage_limits'] as Map).map(
            (key, value) => MapEntry(key.toString(), (value as num).toInt()),
          ),
        );
      }
    }

    return SubscriptionPlanModel(
      id: json['id'],
      name: json['name'],
      tier: json['tier'] ?? 'Silver',
      vehicleCategory: json['vehicle_category'] ?? 'Sedan',
      duration: json['duration'] ?? 'Monthly',
      price: (json['price'] as num).toDouble(),
      originalPrice: json['original_price'] != null
          ? (json['original_price'] as num).toDouble()
          : null,
      description: json['description'] ?? '',
      features: parsedFeatures,
      isFeatured: json['is_featured'] ?? false,
      isActive: json['is_active'] ?? true,
      displayOrder: json['display_order'] ?? 0,
      includedServiceIds: json['included_service_ids'] != null
          ? List<String>.from(json['included_service_ids'] as List)
          : const [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      showUnlimited: json['show_unlimited'] ?? false,
      monthlyCapOverride: json['monthly_cap_override'],
      serviceUsageLimits: parsedUsageLimits,
      dailyLimit: json['daily_limit'] ?? 1,
      fairUsagePolicy: json['fair_usage_policy'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name,
      'tier': tier,
      'vehicle_category': vehicleCategory,
      'duration': duration,
      'price': price,
      'original_price': originalPrice,
      'description': description,
      'features': features,
      'is_featured': isFeatured,
      'is_active': isActive,
      'display_order': displayOrder,
      'included_service_ids': includedServiceIds,
      'show_unlimited': showUnlimited,
      'monthly_cap_override': monthlyCapOverride,
      'service_usage_limits': serviceUsageLimits,
      'daily_limit': dailyLimit,
      'fair_usage_policy': fairUsagePolicy,
    };
    if (id.isNotEmpty) map['id'] = id;
    return map;
  }
}
