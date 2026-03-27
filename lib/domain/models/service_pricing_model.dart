class ServicePricingModel {
  final String id;
  final String name; // e.g. 'Exterior Wash'
  final String description; // Service details
  final String category; // e.g. 'Washing', 'Detailing', 'Protection'
  final double price;
  final String? imageUrl;
  final bool isActive;
  final int displayOrder;
  final DateTime? createdAt;

  ServicePricingModel({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    this.imageUrl,
    this.isActive = true,
    this.displayOrder = 0,
    this.createdAt,
  });

  factory ServicePricingModel.fromJson(Map<String, dynamic> json) {
    return ServicePricingModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'General',
      price: (json['price'] as num).toDouble(),
      imageUrl: json['image_url'] as String?,
      isActive: (json['is_active'] as bool?) ?? true,
      displayOrder: (json['display_order'] as int?) ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'price': price,
      'image_url': imageUrl,
      'is_active': isActive,
      'display_order': displayOrder,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  // For backwards compatibility in UI code
  String get serviceName => name;
  String get subtitle => description;
}
