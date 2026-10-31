class Shop {
  final String id;
  final String name;
  final String address;
  final String district;
  final String city;
  final double latitude;
  final double longitude;
  final double rating;
  final int reviewCount;
  final String machineModel; // e.g. "Máy điện tử Yonex Precision 9.0"
  final String stringerCert; // e.g. "Thợ đạt chuẩn Yonex Master Stringer"
  final String phone;
  final String openHours;
  final String imageUrl;
  final double distanceKm;
  final String? ownerUid;
  final String? ownerName;
  final String? ownerEmail;
  final String status; // 'pending' | 'approved' | 'disabled'
  final DateTime? createdAt;
  final DateTime? trialExpiresAt;
  final DateTime? subscriptionExpiresAt;

  Shop({
    required this.id,
    required this.name,
    required this.address,
    required this.district,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.rating,
    required this.reviewCount,
    required this.machineModel,
    required this.stringerCert,
    required this.phone,
    required this.openHours,
    required this.imageUrl,
    this.distanceKm = 1.2,
    this.ownerUid,
    this.ownerName,
    this.ownerEmail,
    this.status = 'approved',
    this.createdAt,
    this.trialExpiresAt,
    this.subscriptionExpiresAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isDisabled => status == 'disabled';

  /// Shop đã đăng ký tài khoản trên app bởi Chủ Shop (có tài khoản xác thực)
  bool get isRegisteredOnApp => ownerUid != null && ownerUid!.isNotEmpty;

  /// Hạn dùng thử miễn phí 1 tháng (30 ngày kể từ lúc tạo shop).
  /// Nếu shop thiếu cả trialExpiresAt và createdAt, trả về mốc thời gian quá khứ (1970)
  /// để tránh lỗi rolling 30-day window khiến shop được dùng thử vĩnh viễn không cần đóng phí.
  DateTime get effectiveTrialExpiry {
    if (trialExpiresAt != null) return trialExpiresAt!;
    if (createdAt != null) return createdAt!.add(const Duration(days: 30));
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Gói dùng thử 1 tháng có còn hiệu lực không
  bool get isTrialActive {
    if (!isRegisteredOnApp) return false;
    if (trialExpiresAt == null && createdAt == null) return false;
    return DateTime.now().isBefore(effectiveTrialExpiry);
  }

  /// Gói trả phí duy trì có còn hiệu lực không
  bool get isPaidActive {
    return subscriptionExpiresAt != null &&
        DateTime.now().isBefore(subscriptionExpiresAt!);
  }

  /// Tình trạng hiệu lực hoạt động dịch vụ của Shop:
  /// - Nếu là điểm Google Maps công cộng: luôn active
  /// - Nếu là Shop đăng ký tài khoản: Phải còn hạn dùng thử HOẶC còn hạn trả phí
  bool get isSubscriptionActive {
    if (!isRegisteredOnApp) return true;
    return isTrialActive || isPaidActive;
  }

  /// Số ngày hiệu lực còn lại (tính theo gói trả phí hoặc gói dùng thử)
  int get daysRemaining {
    if (isPaidActive) {
      final diff = subscriptionExpiresAt!.difference(DateTime.now()).inDays + 1;
      return diff > 0 ? diff : 0;
    }
    if (isTrialActive) {
      final diff = effectiveTrialExpiry.difference(DateTime.now()).inDays + 1;
      return diff > 0 ? diff : 0;
    }
    return 0;
  }

  /// Nhãn hiển thị trạng thái gói dịch vụ
  String get subscriptionStatusLabel {
    if (!isRegisteredOnApp) return 'Điểm công cộng';
    if (isPaidActive) {
      return 'Gói dịch vụ (Còn $daysRemaining ngày)';
    }
    if (isTrialActive) {
      return 'Dùng thử miễn phí (Còn $daysRemaining ngày)';
    }
    return 'Hết hạn dịch vụ (Cần đóng phí)';
  }

  /// Shop đối tác chính thức đã đăng ký trên app và được Admin phê duyệt hoạt động
  bool get isVerifiedPartner => isRegisteredOnApp && isApproved;

  String get statusDisplayName {
    if (isVerifiedPartner) {
      return 'Được phê duyệt';
    }
    switch (status) {
      case 'pending':
        return 'Chờ phê duyệt';
      case 'disabled':
        return 'Đã vô hiệu hóa';
      case 'approved':
      default:
        return isRegisteredOnApp ? 'Đang hoạt động' : 'Đang hoạt động (Google Maps)';
    }
  }

  Shop copyWith({
    String? id,
    String? name,
    String? address,
    String? district,
    String? city,
    double? latitude,
    double? longitude,
    double? rating,
    int? reviewCount,
    String? machineModel,
    String? stringerCert,
    String? phone,
    String? openHours,
    String? imageUrl,
    double? distanceKm,
    String? ownerUid,
    String? ownerName,
    String? ownerEmail,
    String? status,
    DateTime? createdAt,
    DateTime? trialExpiresAt,
    DateTime? subscriptionExpiresAt,
  }) {
    return Shop(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      district: district ?? this.district,
      city: city ?? this.city,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      machineModel: machineModel ?? this.machineModel,
      stringerCert: stringerCert ?? this.stringerCert,
      phone: phone ?? this.phone,
      openHours: openHours ?? this.openHours,
      imageUrl: imageUrl ?? this.imageUrl,
      distanceKm: distanceKm ?? this.distanceKm,
      ownerUid: ownerUid ?? this.ownerUid,
      ownerName: ownerName ?? this.ownerName,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      trialExpiresAt: trialExpiresAt ?? this.trialExpiresAt,
      subscriptionExpiresAt:
          subscriptionExpiresAt ?? this.subscriptionExpiresAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'district': district,
      'city': city,
      'latitude': latitude,
      'longitude': longitude,
      'rating': rating,
      'reviewCount': reviewCount,
      'machineModel': machineModel,
      'stringerCert': stringerCert,
      'phone': phone,
      'openHours': openHours,
      'imageUrl': imageUrl,
      'distanceKm': distanceKm,
      'ownerUid': ownerUid,
      'ownerName': ownerName,
      'ownerEmail': ownerEmail,
      'status': status,
      'createdAt': createdAt?.toIso8601String(),
      'trialExpiresAt': trialExpiresAt?.toIso8601String(),
      'subscriptionExpiresAt': subscriptionExpiresAt?.toIso8601String(),
    };
  }

  factory Shop.fromMap(Map<String, dynamic> map, {String? docId}) {
    return Shop(
      id: map['id']?.toString() ?? docId ?? '',
      name: map['name']?.toString() ?? 'Cửa hàng cầu lông',
      address: map['address']?.toString() ?? '',
      district: map['district']?.toString() ?? 'Khu vực lân cận',
      city: map['city']?.toString() ?? 'Việt Nam',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 21.0285,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 105.8542,
      rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
      machineModel:
          map['machineModel']?.toString() ?? 'Máy đan cước điện tử',
      stringerCert:
          map['stringerCert']?.toString() ?? 'Kỹ thuật viên đan vợt',
      phone: map['phone']?.toString() ?? '',
      openHours: map['openHours']?.toString() ?? '08:00 - 21:30',
      imageUrl: map['imageUrl']?.toString() ?? '',
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 1.0,
      ownerUid: map['ownerUid']?.toString(),
      ownerName: map['ownerName']?.toString(),
      ownerEmail: map['ownerEmail']?.toString(),
      status: map['status']?.toString() ?? 'approved',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
      trialExpiresAt: map['trialExpiresAt'] != null
          ? DateTime.tryParse(map['trialExpiresAt'].toString())
          : null,
      subscriptionExpiresAt: map['subscriptionExpiresAt'] != null
          ? DateTime.tryParse(map['subscriptionExpiresAt'].toString())
          : null,
    );
  }
}
