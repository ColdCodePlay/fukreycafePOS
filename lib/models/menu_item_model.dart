
class MenuItem {
  final String id;
  final String name;
  final String? description;
  final double price;
  final String? categoryId;
  final String? outletId;
  final String? imageUrl;
  final bool isAvailable;

  MenuItem({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.categoryId,
    this.outletId,
    this.imageUrl,
    this.isAvailable = true,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      price: (json['price'] as num).toDouble(),
      categoryId: json['category_id'],
      outletId: json['outlet_id'],
      imageUrl: json['image_url'],
      isAvailable: json['is_available'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'category_id': categoryId,
      'outlet_id': outletId,
      'image_url': imageUrl,
      'is_available': isAvailable,
    };
  }
}
