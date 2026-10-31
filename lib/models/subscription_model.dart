enum SubscriptionTarget {
  player,
  shop;

  String get displayName {
    switch (this) {
      case SubscriptionTarget.player:
        return 'Người chơi (Player VIP)';
      case SubscriptionTarget.shop:
        return 'Chủ Cửa hàng (Shop Duy trì)';
    }
  }
}

class SubscriptionPlan {
  final String id;
  final String title;
  final String shortTitle;
  final SubscriptionTarget target;
  final int priceVnd;
  final int durationDays;
  final String description;
  final List<String> features;
  final bool isPopular;
  final String? discountBadge;

  const SubscriptionPlan({
    required this.id,
    required this.title,
    required this.shortTitle,
    required this.target,
    required this.priceVnd,
    required this.durationDays,
    required this.description,
    required this.features,
    this.isPopular = false,
    this.discountBadge,
  });

  /// Gói dịch vụ dành cho Player
  static const List<SubscriptionPlan> playerPlans = [
    SubscriptionPlan(
      id: 'player_1m',
      title: 'VIP Hội Viên 1 Tháng',
      shortTitle: '1 Tháng',
      target: SubscriptionTarget.player,
      priceVnd: 29000,
      durationDays: 30,
      description: 'Trải nghiệm trọn vẹn đặc quyền VIP cho người chơi cầu lông chuyên nghiệp.',
      features: [
        'Quản lý không giới hạn số lượng vợt trong Gara (vượt mốc 5 cây)',
        'Mở khóa Bác Sĩ Thể Thao (AI chẩn đoán & cảnh báo căng cước)',
        'Mở khóa Sổ Tay Chấn Thương & Lộ trình phục hồi chức năng',
        'Huy hiệu VIP Hoàng Kim trên trang cá nhân',
      ],
      isPopular: false,
    ),
    SubscriptionPlan(
      id: 'player_3m',
      title: 'VIP Hội Viên 3 Tháng',
      shortTitle: '3 Tháng',
      target: SubscriptionTarget.player,
      priceVnd: 59000,
      durationDays: 90,
      description: 'Gói tối ưu và tiết kiệm nhất cho người chơi đam mê cầu lông thường xuyên.',
      discountBadge: 'Tiết kiệm 32%',
      isPopular: true,
      features: [
        'Toàn bộ đặc quyền của gói VIP 1 Tháng',
        'Tiết kiệm 32% chi phí (Chỉ ~19.000đ/tháng)',
        'Quản lý không giới hạn số lượng vợt & lịch sử đan cước',
        'Đồng hành phòng tránh chấn thương suốt mùa giải',
      ],
    ),
  ];

  /// Gói duy trì dành cho Shop
  static const List<SubscriptionPlan> shopPlans = [
    SubscriptionPlan(
      id: 'shop_1m',
      title: 'Duy Trì Cửa Hàng 1 Tháng',
      shortTitle: '1 Tháng',
      target: SubscriptionTarget.shop,
      priceVnd: 20000,
      durationDays: 30,
      description: 'Duy trì cửa hàng hoạt động sau 1 tháng dùng thử miễn phí.',
      features: [
        'Duy trì hiển thị trên Bản Đồ Cửa Hàng và Danh sách đối tác',
        'Đăng bán sản phẩm & dịch vụ căng vợt không giới hạn',
        'Tiếp nhận đơn hàng và trò chuyện trực tiếp với khách hàng',
        'Báo cáo doanh số và đơn hàng thời gian thực',
      ],
      isPopular: false,
    ),
    SubscriptionPlan(
      id: 'shop_3m',
      title: 'Duy Trì Cửa Hàng 3 Tháng',
      shortTitle: '3 Tháng',
      target: SubscriptionTarget.shop,
      priceVnd: 40000,
      durationDays: 90,
      description: 'Gói gia hạn tiết kiệm nhất giúp cửa hàng kinh doanh ổn định lâu dài.',
      discountBadge: 'Tiết kiệm 33%',
      isPopular: true,
      features: [
        'Toàn bộ đặc quyền gói duy trì cửa hàng',
        'Tiết kiệm 33% chi phí (Chỉ ~13.000đ/tháng)',
        'Huy hiệu Cửa Hàng Đối Tác Uy Tín trên bản đồ',
        'Ưu tiên hiển thị khi khách hàng tìm kiếm gần nhất',
      ],
    ),
  ];
}

class PaymentTransaction {
  final String id;
  final String userId;
  final String userEmail;
  final String userName;
  final String userRole; // 'player', 'stringer', 'admin'
  final String? shopId;
  final String? shopName;
  final String planId;
  final String planTitle;
  final int amount; // VND
  final int durationDays;
  final String paymentMethod; // 'VietQR (Napas 24/7)'
  final String bankTransferCode;
  final String status; // 'completed', 'pending', 'cancelled'
  final DateTime createdAt;
  final DateTime? completedAt;

  const PaymentTransaction({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.userName,
    required this.userRole,
    this.shopId,
    this.shopName,
    required this.planId,
    required this.planTitle,
    required this.amount,
    required this.durationDays,
    this.paymentMethod = 'VietQR (Napas 24/7)',
    required this.bankTransferCode,
    this.status = 'completed',
    required this.createdAt,
    this.completedAt,
  });

  bool get isCompleted => status == 'completed';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userEmail': userEmail,
      'userName': userName,
      'userRole': userRole,
      'shopId': shopId,
      'shopName': shopName,
      'planId': planId,
      'planTitle': planTitle,
      'amount': amount,
      'durationDays': durationDays,
      'paymentMethod': paymentMethod,
      'bankTransferCode': bankTransferCode,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory PaymentTransaction.fromMap(Map<String, dynamic> map, {String? docId}) {
    return PaymentTransaction(
      id: map['id']?.toString() ?? docId ?? '',
      userId: map['userId']?.toString() ?? '',
      userEmail: map['userEmail']?.toString() ?? '',
      userName: map['userName']?.toString() ?? 'Người dùng Gear Sports',
      userRole: map['userRole']?.toString() ?? 'player',
      shopId: map['shopId']?.toString(),
      shopName: map['shopName']?.toString(),
      planId: map['planId']?.toString() ?? '',
      planTitle: map['planTitle']?.toString() ?? '',
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      durationDays: (map['durationDays'] as num?)?.toInt() ?? 30,
      paymentMethod: map['paymentMethod']?.toString() ?? 'VietQR (Napas 24/7)',
      bankTransferCode: map['bankTransferCode']?.toString() ?? '',
      status: map['status']?.toString() ?? 'completed',
      createdAt: map['createdAt'] != null
          ? (DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
      completedAt: map['completedAt'] != null
          ? DateTime.tryParse(map['completedAt'].toString())
          : null,
    );
  }
}
