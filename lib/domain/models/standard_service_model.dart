class StandardServiceModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final String? imageUrl;
  final String category;
  final bool isActive;
  final int displayOrder;
  final DateTime createdAt;

  StandardServiceModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.imageUrl,
    this.category = 'General',
    this.isActive = true,
    this.displayOrder = 0,
    required this.createdAt,
  });

  factory StandardServiceModel.fromJson(Map<String, dynamic> json) {
    return StandardServiceModel(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      price: (json['price'] as num).toDouble(),
      imageUrl: json['image_url'],
      category: json['category'] ?? 'General',
      isActive: json['is_active'] ?? true,
      displayOrder: json['display_order'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name,
      'description': description,
      'price': price,
      'image_url': imageUrl,
      'category': category,
      'is_active': isActive,
      'display_order': displayOrder,
    };
    if (id.isNotEmpty) map['id'] = id;
    return map;
  }
}
