enum OrderStatus {
  pending,
  stringing,
  ready,
  completed,
  cancelled;

  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'Chờ tiếp nhận';
      case OrderStatus.stringing:
        return 'Đang đan vợt';
      case OrderStatus.ready:
        return 'Đã đan xong (Chờ nhận)';
      case OrderStatus.completed:
        return 'Hoàn thành';
      case OrderStatus.cancelled:
        return 'Đã hủy';
    }
  }

  static OrderStatus fromString(String? val) {
    switch (val) {
      case 'stringing':
        return OrderStatus.stringing;
      case 'ready':
        return OrderStatus.ready;
      case 'completed':
        return OrderStatus.completed;
      case 'cancelled':
        return OrderStatus.cancelled;
      case 'pending':
      default:
        return OrderStatus.pending;
    }
  }
}

class OrderItem {
  final String productId;
  final String productName;
  final double price;
  final int quantity;
  final bool isService;
  final String? targetRacketName;
  final double? requestedTensionLbs;
  final String stringingTechnique;
  final String selectedColor;
  final String specialNotes;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.price,
    this.quantity = 1,
    this.isService = false,
    this.targetRacketName,
    this.requestedTensionLbs,
    this.stringingTechnique = '4 nút chuẩn Yonex',
    this.selectedColor = 'Trắng',
    this.specialNotes = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'price': price,
      'quantity': quantity,
      'isService': isService,
      'targetRacketName': targetRacketName,
      'requestedTensionLbs': requestedTensionLbs,
      'stringingTechnique': stringingTechnique,
      'selectedColor': selectedColor,
      'specialNotes': specialNotes,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId']?.toString() ?? '',
      productName: map['productName']?.toString() ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      isService: map['isService'] == true,
      targetRacketName: map['targetRacketName']?.toString(),
      requestedTensionLbs: (map['requestedTensionLbs'] as num?)?.toDouble(),
      stringingTechnique: map['stringingTechnique']?.toString() ?? '4 nút chuẩn Yonex',
      selectedColor: map['selectedColor']?.toString() ?? 'Trắng',
      specialNotes: map['specialNotes']?.toString() ?? '',
    );
  }
}

class OrderModel {
  final String id;
  final String shopId;
  final String shopName;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String deliveryMethod;
  final String paymentMethod;
  final String timeSlot;
  final String deliveryAddress;
  final String note;
  final double totalAmount;
  final OrderStatus status;
  final DateTime createdAt;
  final List<OrderItem> items;

  OrderModel({
    required this.id,
    required this.shopId,
    required this.shopName,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryMethod,
    required this.paymentMethod,
    required this.timeSlot,
    this.deliveryAddress = '',
    this.note = '',
    required this.totalAmount,
    this.status = OrderStatus.pending,
    required this.createdAt,
    required this.items,
  });

  bool get isPending => status == OrderStatus.pending;
  bool get isStringing => status == OrderStatus.stringing;
  bool get isReady => status == OrderStatus.ready;
  bool get isCompleted => status == OrderStatus.completed;
  bool get isCancelled => status == OrderStatus.cancelled;

  OrderModel copyWith({
    String? id,
    String? shopId,
    String? shopName,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? deliveryMethod,
    String? paymentMethod,
    String? timeSlot,
    String? deliveryAddress,
    String? note,
    double? totalAmount,
    OrderStatus? status,
    DateTime? createdAt,
    List<OrderItem>? items,
  }) {
    return OrderModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      shopName: shopName ?? this.shopName,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      deliveryMethod: deliveryMethod ?? this.deliveryMethod,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      timeSlot: timeSlot ?? this.timeSlot,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      note: note ?? this.note,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shopId': shopId,
      'shopName': shopName,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'deliveryMethod': deliveryMethod,
      'paymentMethod': paymentMethod,
      'timeSlot': timeSlot,
      'deliveryAddress': deliveryAddress,
      'note': note,
      'totalAmount': totalAmount,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'items': items.map((e) => e.toMap()).toList(),
    };
  }

  factory OrderModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    final rawItems = map['items'] as List<dynamic>? ?? [];
    return OrderModel(
      id: docId ?? map['id']?.toString() ?? '',
      shopId: map['shopId']?.toString() ?? '',
      shopName: map['shopName']?.toString() ?? '',
      customerId: map['customerId']?.toString() ?? '',
      customerName: map['customerName']?.toString() ?? '',
      customerPhone: map['customerPhone']?.toString() ?? '',
      deliveryMethod: map['deliveryMethod']?.toString() ?? 'Mang đến shop',
      paymentMethod: map['paymentMethod']?.toString() ?? 'Tiền mặt khi lấy vợt',
      timeSlot: map['timeSlot']?.toString() ?? '',
      deliveryAddress: map['deliveryAddress']?.toString() ?? '',
      note: map['note']?.toString() ?? '',
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      status: OrderStatus.fromString(map['status']?.toString()),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      items: rawItems
          .map((e) => OrderItem.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
