import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../data/mock_data.dart';

class NotificationProvider with ChangeNotifier {
  final List<AppNotification> _notifications = List.from(MockData.initialNotifications);

  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  int get unreadCount {
    return _notifications.where((n) => !n.isRead).length;
  }

  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index].isRead = true;
      notifyListeners();
    }
  }

  void markAllAsRead() {
    for (var n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();
  }

  void addNotification({
    required String title,
    required String message,
    required NotificationType type,
    String? targetRacketId,
    String? targetOrderId,
  }) {
    final notif = AppNotification(
      id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      message: message,
      type: type,
      timestamp: DateTime.now(),
      targetRacketId: targetRacketId,
      targetOrderId: targetOrderId,
    );
    _notifications.insert(0, notif);
    notifyListeners();
  }

  void removeNotification(String id) {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }
}
