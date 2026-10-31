enum UserRole {
  player,
  stringer,
  admin;

  String get displayName {
    switch (this) {
      case UserRole.player:
        return 'Người chơi (Player)';
      case UserRole.stringer:
        return 'Chủ Shop / Thợ đan (Stringer)';
      case UserRole.admin:
        return 'Quản trị viên (Admin)';
    }
  }

  String get shortLabel {
    switch (this) {
      case UserRole.player:
        return 'Người chơi';
      case UserRole.stringer:
        return 'Chủ Shop';
      case UserRole.admin:
        return 'Admin';
    }
  }

  static UserRole fromString(String? value) {
    switch (value) {
      case 'stringer':
        return UserRole.stringer;
      case 'admin':
        return UserRole.admin;
      case 'player':
      default:
        return UserRole.player;
    }
  }
}

class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final String phone;
  final UserRole role;
  final String playStyle;
  final String? shopName;
  final bool isBlocked;
  final DateTime createdAt;
  final bool isVip;
  final DateTime? vipExpiresAt;

  const UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.phone,
    this.role = UserRole.player,
    this.playStyle = 'Thiên công 4U • Sẵn sàng ra sân 🏸',
    this.shopName,
    this.isBlocked = false,
    required this.createdAt,
    this.isVip = false,
    this.vipExpiresAt,
  });

  /// Kiểm tra gói VIP có đang còn hiệu lực hay không
  bool get isVipActive {
    if (role == UserRole.admin) return true; // Admin có toàn quyền truy cập
    if (!isVip) return false;
    if (vipExpiresAt == null) return true; // VIP vĩnh viễn (nếu không set hạn)
    return vipExpiresAt!.isAfter(DateTime.now());
  }

  /// Số ngày VIP còn lại
  int get vipDaysRemaining {
    if (!isVipActive) return 0;
    if (vipExpiresAt == null) return 999;
    final diff = vipExpiresAt!.difference(DateTime.now()).inDays + 1;
    return diff > 0 ? diff : 0;
  }

  /// Kiểm tra quyền thêm vợt vào Gara (Miễn phí: tối đa 5 cây; VIP: không giới hạn)
  bool canAddRacket(int currentRacketCount) {
    if (isVipActive || role == UserRole.admin) return true;
    return currentRacketCount < 5;
  }

  /// Kiểm tra quyền sử dụng Bác sĩ thể thao & Sổ tay chấn thương
  bool get canAccessHealthFeatures {
    return isVipActive || role == UserRole.admin;
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? fullName,
    String? phone,
    UserRole? role,
    String? playStyle,
    String? shopName,
    bool? isBlocked,
    DateTime? createdAt,
    bool? isVip,
    DateTime? vipExpiresAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      playStyle: playStyle ?? this.playStyle,
      shopName: shopName ?? this.shopName,
      isBlocked: isBlocked ?? this.isBlocked,
      createdAt: createdAt ?? this.createdAt,
      isVip: isVip ?? this.isVip,
      vipExpiresAt: vipExpiresAt ?? this.vipExpiresAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'phone': phone,
      'role': role.name,
      'playStyle': playStyle,
      'shopName': shopName,
      'isBlocked': isBlocked,
      'createdAt': createdAt.toIso8601String(),
      'isVip': isVip,
      'vipExpiresAt': vipExpiresAt?.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    return UserModel(
      uid: map['uid']?.toString() ?? docId ?? '',
      email: map['email']?.toString() ?? '',
      fullName: map['fullName']?.toString() ?? 'Người chơi Gear Sports',
      phone: map['phone']?.toString() ?? '',
      role: UserRole.fromString(map['role']?.toString()),
      playStyle: map['playStyle']?.toString() ??
          'Thiên công 4U • Sẵn sàng ra sân 🏸',
      shopName: map['shopName']?.toString(),
      isBlocked: map['isBlocked'] == true,
      createdAt: map['createdAt'] != null
          ? (DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
      isVip: map['isVip'] == true,
      vipExpiresAt: map['vipExpiresAt'] != null
          ? DateTime.tryParse(map['vipExpiresAt'].toString())
          : null,
    );
  }
}
