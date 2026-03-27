import 'vehicle_model.dart';

class UserProfileModel {
  final String id;
  final String fullName;
  final String? username;
  final String? avatarUrl;
  final String membershipTier;
  final String? address;
  final String? gender;
  final String? phone;
  final List<VehicleModel> vehicles;
  final DateTime createdAt;
  final double? customerRating;
  final int? totalCustomerFeedbacks;

  UserProfileModel({
    required this.id,
    required this.fullName,
    this.username,
    this.avatarUrl,
    this.membershipTier = 'FREE',
    this.address,
    this.gender,
    this.phone,
    this.vehicles = const [],
    required this.createdAt,
    this.customerRating,
    this.totalCustomerFeedbacks,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['id'],
      fullName: json['full_name'] ?? 'New User',
      username: json['username'],
      avatarUrl: json['avatar_url'],
      membershipTier: json['membership_tier'] ?? 'FREE',
      address: json['address'],
      gender: json['gender'],
      phone: json['phone'],
      vehicles: json['vehicles'] != null
          ? (json['vehicles'] as List)
                .map((v) => VehicleModel.fromJson(v))
                .toList()
          : const [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      customerRating: (json['customer_rating'] as num?)?.toDouble(),
      totalCustomerFeedbacks: json['total_customer_feedbacks'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'username': username,
      'avatar_url': avatarUrl,
      'membership_tier': membershipTier,
      'address': address,
      'gender': gender,
      'phone': phone,
    };
  }

  UserProfileModel copyWith({
    String? fullName,
    String? username,
    String? avatarUrl,
    String? membershipTier,
    String? address,
    String? gender,
    String? phone,
    List<VehicleModel>? vehicles,
    double? customerRating,
    int? totalCustomerFeedbacks,
  }) {
    return UserProfileModel(
      id: id,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      membershipTier: membershipTier ?? this.membershipTier,
      address: address ?? this.address,
      gender: gender ?? this.gender,
      phone: phone ?? this.phone,
      vehicles: vehicles ?? this.vehicles,
      createdAt: createdAt,
      customerRating: customerRating ?? this.customerRating,
      totalCustomerFeedbacks: totalCustomerFeedbacks ?? this.totalCustomerFeedbacks,
    );
  }
}
