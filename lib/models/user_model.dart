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
  });

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
    );
  }
}
