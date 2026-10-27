enum ProductCategory {
  service, // Dịch vụ đan vợt
  racket, // Vợt cầu lông đăng bán
  string, // Cước cầu lông
  grip, // Quấn cán
  accessory, // Phụ kiện khác (Gen, tạ cân bằng...)
}

class Product {
  final String id;
  final String shopId;
  final String? shopName;
  final String name;
  final ProductCategory category;
  final double price;
  final String description;
  final String imageUrl;
  final bool isService;
  final List<String> availableColors;
  final double? rating;
  final String status; // 'pending' | 'approved' | 'rejected'

  Product({
    required this.id,
    required this.shopId,
    this.shopName,
    required this.name,
    required this.category,
    required this.price,
    required this.description,
    required this.imageUrl,
    this.isService = false,
    this.availableColors = const [],
    this.rating = 4.9,
    this.status = 'approved',
  });

  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';

  String get statusDisplayName {
    switch (status) {
      case 'pending':
        return 'Chờ kiểm duyệt';
      case 'rejected':
        return 'Vi phạm / Tạm ẩn';
      case 'approved':
      default:
        return 'Hợp lệ';
    }
  }

  String get categoryName {
    switch (category) {
      case ProductCategory.service:
        return 'Dịch vụ đan';
      case ProductCategory.racket:
        return 'Vợt đăng bán';
      case ProductCategory.string:
        return 'Cước căng';
      case ProductCategory.grip:
        return 'Quấn cán';
      case ProductCategory.accessory:
        return 'Phụ kiện';
    }
  }

  static ProductCategory categoryFromString(String? val) {
    switch (val) {
      case 'service':
        return ProductCategory.service;
      case 'racket':
        return ProductCategory.racket;
      case 'string':
        return ProductCategory.string;
      case 'grip':
        return ProductCategory.grip;
      case 'accessory':
      default:
        return ProductCategory.accessory;
    }
  }

  Product copyWith({
    String? id,
    String? shopId,
    String? shopName,
    String? name,
    ProductCategory? category,
    double? price,
    String? description,
    String? imageUrl,
    bool? isService,
    List<String>? availableColors,
    double? rating,
    String? status,
  }) {
    return Product(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      shopName: shopName ?? this.shopName,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      isService: isService ?? this.isService,
      availableColors: availableColors ?? this.availableColors,
      rating: rating ?? this.rating,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shopId': shopId,
      'shopName': shopName,
      'name': name,
      'category': category.name,
      'price': price,
      'description': description,
      'imageUrl': imageUrl,
      'isService': isService,
      'availableColors': availableColors,
      'rating': rating,
      'status': status,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map, {String? docId}) {
    final colorsRaw = map['availableColors'] as List<dynamic>? ?? [];
    final cat = categoryFromString(map['category']?.toString());
    return Product(
      id: map['id']?.toString() ?? docId ?? '',
      shopId: map['shopId']?.toString() ?? '',
      shopName: map['shopName']?.toString(),
      name: map['name']?.toString() ?? '',
      category: cat,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      description: map['description']?.toString() ?? '',
      imageUrl: map['imageUrl']?.toString() ?? '',
      isService: map['isService'] == true || cat == ProductCategory.service,
      availableColors: colorsRaw.map((e) => e.toString()).toList(),
      rating: (map['rating'] as num?)?.toDouble() ?? 4.9,
      status: map['status']?.toString() ?? 'approved',
    );
  }
}
