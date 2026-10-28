enum NotificationType {
  tensionAlert,
  orderStatus,
  promo,
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

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.targetRacketId,
    this.targetOrderId,
  });

  static NotificationType typeFromString(String? val) {
    switch (val) {
      case 'tensionAlert':
        return NotificationType.tensionAlert;
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
    );
  }
}
