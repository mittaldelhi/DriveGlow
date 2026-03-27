class ServiceModel {
  final String id;
  final String title;
  final String description;
  final double basePrice;
  final String iconName;
  final String category; // e.g., 'STANDARD', 'ADVANCED', 'PREMIUM'
  final bool isAvailable;

  ServiceModel({
    required this.id,
    required this.title,
    required this.description,
    required this.basePrice,
    required this.iconName,
    required this.category,
    this.isAvailable = true,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      basePrice: (json['base_price'] as num).toDouble(),
      iconName: json['icon_name'],
      category: json['category'],
      isAvailable: json['is_available'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'base_price': basePrice,
      'icon_name': iconName,
      'category': category,
      'is_available': isAvailable,
    };
  }
}
