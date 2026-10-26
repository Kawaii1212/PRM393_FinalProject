enum ProductCategory {
  service, // Dịch vụ đan vợt
  string, // Cước cầu lông
  grip, // Quấn cán
  accessory, // Phụ kiện khác (Gen, tạ cân bằng...)
}

class Product {
  final String id;
  final String shopId;
  final String name;
  final ProductCategory category;
  final double price;
  final String description;
  final String imageUrl;
  final bool isService;
  final List<String> availableColors;
  final double? rating;

  Product({
    required this.id,
    required this.shopId,
    required this.name,
    required this.category,
    required this.price,
    required this.description,
    required this.imageUrl,
    this.isService = false,
    this.availableColors = const [],
    this.rating = 4.9,
  });

  String get categoryName {
    switch (category) {
      case ProductCategory.service:
        return 'Dịch vụ đan';
      case ProductCategory.string:
        return 'Cước căng';
      case ProductCategory.grip:
        return 'Quấn cán';
      case ProductCategory.accessory:
        return 'Phụ kiện';
    }
  }
}
