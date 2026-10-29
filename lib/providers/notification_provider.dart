import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_model.dart';
import '../models/racket_model.dart';

class NotificationProvider with ChangeNotifier {
  static const String _prefSystemNotifsKey = 'gearsports_system_notifications';

  final List<AppNotification> _notifications = [];

  NotificationProvider() {
    syncSystemNotifications();
  }

  bool get _isFirebaseReady {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  int get unreadCount {
    return _notifications.where((n) => !n.isRead).length;
  }

  /// Đồng bộ thông báo hệ thống từ Cloud Firestore (`system_notifications`)
  Future<void> syncSystemNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedRaw = prefs.getString(_prefSystemNotifsKey);
      if (cachedRaw != null && cachedRaw.isNotEmpty) {
        final decoded = jsonDecode(cachedRaw) as List<dynamic>;
        final loaded = decoded
            .map((e) => AppNotification.fromMap(Map<String, dynamic>.from(e)))
            .toList();
        _mergeNotifications(loaded);
        notifyListeners();
      }

      if (_isFirebaseReady) {
        final snap = await FirebaseFirestore.instance
            .collection('system_notifications')
            .orderBy('timestamp', descending: true)
            .get()
            .timeout(const Duration(seconds: 6));

        final remoteNotifs = snap.docs
            .map((doc) => AppNotification.fromMap(doc.data(), docId: doc.id))
            .toList();
        _mergeNotifications(remoteNotifs);
        await _saveCache(prefs);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('syncSystemNotifications warning: $e');
    }
  }

  void _mergeNotifications(List<AppNotification> incoming) {
    final mapById = <String, AppNotification>{};
    for (final n in _notifications) {
      mapById[n.id] = n;
    }
    for (final n in incoming) {
      final existing = mapById[n.id];
      if (existing != null) {
        n.isRead = existing.isRead;
      }
      mapById[n.id] = n;
    }
    final list = mapById.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    _notifications
      ..clear()
      ..addAll(list);
  }

  Future<void> _saveCache(SharedPreferences prefs) async {
    final encoded = jsonEncode(_notifications.map((n) => n.toMap()).toList());
    await prefs.setString(_prefSystemNotifsKey, encoded);
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

  /// Tự động kiểm tra và sinh cảnh báo cho những cây vợt cần thay cước
  void syncRacketTensionAlerts(List<Racket> rackets) {
    bool hasChange = false;
    for (final racket in rackets) {
      if (racket.needsRestring) {
        final alreadyExists = _notifications.any(
          (n) => n.type == NotificationType.tensionAlert && n.targetRacketId == racket.id,
        );
        if (!alreadyExists) {
          final notif = AppNotification(
            id: 'alert_${racket.id}_${DateTime.now().millisecondsSinceEpoch}',
            title: '🏸 Cảnh báo: Vợt ${racket.brand} ${racket.modelName} cần đan lại!',
            message: 'Cước đã chùng -${racket.tensionLossPercent}% sau ${racket.daysSinceStrung} ngày (${racket.sessionsPlayed} buổi). Hãy đan lại để phòng tránh chấn thương cổ tay!',
            type: NotificationType.tensionAlert,
            timestamp: DateTime.now(),
            targetRacketId: racket.id,
            isRead: false,
          );
          _notifications.insert(0, notif);
          hasChange = true;
        }
      }
    }
    if (hasChange) {
      notifyListeners();
    }
  }

  /// Dành cho Admin: Phát thông báo toàn hệ thống và lưu lên Cloud Firestore (`system_notifications`)
  Future<void> broadcastSystemNotification({
    required String title,
    required String message,
    NotificationType type = NotificationType.promo,
  }) async {
    final notif = AppNotification(
      id: 'sys_notif_${DateTime.now().millisecondsSinceEpoch}',
      title: title.trim(),
      message: message.trim(),
      type: type,
      timestamp: DateTime.now(),
      isRead: false,
    );
    _notifications.insert(0, notif);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await _saveCache(prefs);
      if (_isFirebaseReady) {
        await FirebaseFirestore.instance
            .collection('system_notifications')
            .doc(notif.id)
            .set(notif.toMap())
            .timeout(const Duration(seconds: 5));
      }
    } catch (e) {
      debugPrint('broadcastSystemNotification error: $e');
    }
  }

  /// Dành cho Admin: Xóa thông báo hệ thống khỏi Cloud Firestore
  Future<void> deleteSystemNotification(String id) async {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await _saveCache(prefs);
      if (_isFirebaseReady) {
        await FirebaseFirestore.instance
            .collection('system_notifications')
            .doc(id)
            .delete()
            .timeout(const Duration(seconds: 5));
      }
    } catch (e) {
      debugPrint('deleteSystemNotification error: $e');
    }
  }

  void removeNotification(String id) {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }
}
