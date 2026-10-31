enum NotificationType {
  tensionAlert,
  racketUpdate,
  orderStatus,
  promo,
  systemAlert, // Thông báo bảo trì / nâng cấp / sự cố hệ thống
  shopNotice, // Thông báo dành cho Chủ Shop & Đối tác
}

class AppNotification {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime timestamp;
  bool isRead;
  final String? targetRacketId;
  final String? targetOrderId;
  final String? targetUserId;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.targetRacketId,
    this.targetOrderId,
    this.targetUserId,
  });

  bool get isMaintenanceOrUpgrade {
    if (type == NotificationType.systemAlert) return true;
    final lowerTitle = title.toLowerCase();
    final lowerMsg = message.toLowerCase();
    return lowerTitle.contains('bảo trì') ||
        lowerTitle.contains('nâng cấp') ||
        lowerMsg.contains('bảo trì') ||
        lowerMsg.contains('nâng cấp');
  }

  String get typeDisplayName {
    switch (type) {
      case NotificationType.systemAlert:
        return '🛠️ Hệ thống / Bảo trì';
      case NotificationType.shopNotice:
        return '🏪 Chủ Shop & Đối tác';
      case NotificationType.tensionAlert:
        return '⚠️ Cảnh báo cước';
      case NotificationType.racketUpdate:
        return '🏸 Cập nhật vợt';
      case NotificationType.orderStatus:
        return '📋 Dịch vụ & Đơn hàng';
      case NotificationType.promo:
        return '📢 Tin tức & Sự kiện';
    }
  }

  static NotificationType typeFromString(String? val) {
    switch (val) {
      case 'systemAlert':
        return NotificationType.systemAlert;
      case 'shopNotice':
        return NotificationType.shopNotice;
      case 'tensionAlert':
        return NotificationType.tensionAlert;
      case 'racketUpdate':
        return NotificationType.racketUpdate;
      case 'orderStatus':
        return NotificationType.orderStatus;
      case 'promo':
      default:
        return NotificationType.promo;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'targetRacketId': targetRacketId,
      'targetOrderId': targetOrderId,
      'targetUserId': targetUserId,
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map, {String? docId}) {
    return AppNotification(
      id: map['id']?.toString() ?? docId ?? '',
      title: map['title']?.toString() ?? '',
      message: map['message']?.toString() ?? '',
      type: typeFromString(map['type']?.toString()),
      timestamp: map['timestamp'] != null
          ? (DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now())
          : DateTime.now(),
      isRead: map['isRead'] == true,
      targetRacketId: map['targetRacketId']?.toString(),
      targetOrderId: map['targetOrderId']?.toString(),
      targetUserId: map['targetUserId']?.toString(),
    );
  }
}
