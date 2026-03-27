class UserModel {
  final String id;
  final String email;
  final String? fullName;
  final String? avatarUrl;
  final String membershipTier; // e.g., 'GUEST', 'BASIC', 'GOLD', 'PLATINUM'
  final DateTime? createdAt;

  UserModel({
    required this.id,
    required this.email,
    this.fullName,
    this.avatarUrl,
    this.membershipTier = 'GUEST',
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'],
      fullName: json['full_name'],
      avatarUrl: json['avatar_url'],
      membershipTier: json['membership_tier'] ?? 'GUEST',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'membership_tier': membershipTier,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? fullName,
    String? avatarUrl,
    String? membershipTier,
  }) {
    return UserModel(
      id: id,
      email: email,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      membershipTier: membershipTier ?? this.membershipTier,
      createdAt: createdAt,
    );
  }
}
