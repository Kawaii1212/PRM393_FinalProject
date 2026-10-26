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
}
