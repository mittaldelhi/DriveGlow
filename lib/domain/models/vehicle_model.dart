class VehicleModel {
  final String id;
  final String userId;
  final String model;
  final String licensePlate;
  final String color;
  final bool isPrimary;
  final DateTime? createdAt;

  VehicleModel({
    required this.id,
    required this.userId,
    required this.model,
    required this.licensePlate,
    required this.color,
    this.isPrimary = false,
    this.createdAt,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'],
      userId: json['user_id'],
      model: json['model'],
      licensePlate: json['license_plate'],
      color: json['color'],
      isPrimary: json['is_primary'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'user_id': userId,
      'model': model,
      'license_plate': licensePlate,
      'color': color,
      'is_primary': isPrimary,
    };
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }

  VehicleModel copyWith({
    String? model,
    String? licensePlate,
    String? color,
    bool? isPrimary,
  }) {
    return VehicleModel(
      id: id,
      userId: userId,
      model: model ?? this.model,
      licensePlate: licensePlate ?? this.licensePlate,
      color: color ?? this.color,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt,
    );
  }
}
