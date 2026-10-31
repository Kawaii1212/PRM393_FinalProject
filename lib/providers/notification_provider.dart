import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_model.dart';
import '../models/racket_model.dart';

class NotificationProvider with ChangeNotifier {
  static const String _prefSystemNotifsKey = 'gearsports_system_notifications';

  String? _currentUserId;
  final List<AppNotification> _notifications = [];
  bool _isLoading = false;

  NotificationProvider() {
    syncSystemNotifications();
  }

  bool get isLoading => _isLoading;
  String? get currentUserId => _currentUserId;

  bool get _isFirebaseReady {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  String get _userCacheKey =>
      'gearsports_user_notifications_${_currentUserId ?? "guest"}';

  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  int get unreadCount {
    return _notifications.where((n) => !n.isRead).length;
  }

  /// Đồng bộ thông báo cho người dùng hiện tại (Player/Shop/Admin)
  Future<void> syncForUser(String? uid) async {
    final isNewUser = _currentUserId != uid;
    _currentUserId = uid;

    if (isNewUser) {
      _notifications.clear();
      notifyListeners();
    }

    _isLoading = true;

    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Tải trước từ Local Cache (user cache + system cache)
      final userCachedRaw = prefs.getString(_userCacheKey);
      if (userCachedRaw != null && userCachedRaw.isNotEmpty) {
        final decoded = jsonDecode(userCachedRaw) as List<dynamic>;
        final loaded = decoded
            .map((e) => AppNotification.fromMap(Map<String, dynamic>.from(e)))
            .toList();
        _mergeNotifications(loaded);
      }

      final sysCachedRaw = prefs.getString(_prefSystemNotifsKey);
      if (sysCachedRaw != null && sysCachedRaw.isNotEmpty) {
        final decodedSys = jsonDecode(sysCachedRaw) as List<dynamic>;
        final loadedSys = decodedSys
            .map((e) => AppNotification.fromMap(Map<String, dynamic>.from(e)))
            .toList();
        _mergeNotifications(loadedSys);
      }
      notifyListeners();

      // 2. Đồng bộ Firestore nếu khả dụng
      if (_isFirebaseReady) {
        // Thông báo hệ thống
        try {
          final sysSnap = await FirebaseFirestore.instance
              .collection('system_notifications')
              .orderBy('timestamp', descending: true)
              .limit(25)
              .get()
              .timeout(const Duration(seconds: 5));

          final remoteSysNotifs = sysSnap.docs
              .map((doc) => AppNotification.fromMap(doc.data(), docId: doc.id))
              .toList();
          _mergeNotifications(remoteSysNotifs);
          final encodedSys = jsonEncode(remoteSysNotifs.map((n) => n.toMap()).toList());
          await prefs.setString(_prefSystemNotifsKey, encodedSys);
        } catch (e) {
          debugPrint('syncForUser system_notifications warning: $e');
        }

        // Thông báo cá nhân người dùng (users/{uid}/notifications)
        if (uid != null && uid.isNotEmpty && uid != 'guest_user') {
          try {
            final userSnap = await FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('notifications')
                .orderBy('timestamp', descending: true)
                .limit(50)
                .get()
                .timeout(const Duration(seconds: 5));

            final remoteUserNotifs = userSnap.docs
                .map((doc) => AppNotification.fromMap(doc.data(), docId: doc.id))
                .toList();
            _mergeNotifications(remoteUserNotifs);
          } catch (e) {
            debugPrint('syncForUser user notifications warning: $e');
          }
        }

        await _saveUserCache(prefs);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('syncForUser error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
            .limit(25)
            .get()
            .timeout(const Duration(seconds: 5));

        final remoteNotifs = snap.docs
            .map((doc) => AppNotification.fromMap(doc.data(), docId: doc.id))
            .toList();
        _mergeNotifications(remoteNotifs);
        final encoded = jsonEncode(remoteNotifs.map((n) => n.toMap()).toList());
        await prefs.setString(_prefSystemNotifsKey, encoded);
        await _saveUserCache(prefs);
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

  Future<void> _saveUserCache(SharedPreferences prefs) async {
    final encoded = jsonEncode(_notifications.map((n) => n.toMap()).toList());
    await prefs.setString(_userCacheKey, encoded);
  }

  Future<void> _saveCacheDirect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _saveUserCache(prefs);
    } catch (e) {
      debugPrint('_saveCacheDirect error: $e');
    }
  }

  /// Danh sách các thông báo bảo trì / nâng cấp hệ thống từ Admin
  List<AppNotification> get systemAlerts =>
      _notifications.where((n) => n.isMaintenanceOrUpgrade).toList();

  /// Danh sách thông báo dành riêng cho đối tác / Chủ shop
  List<AppNotification> get shopNotifs =>
      _notifications.where((n) => n.type == NotificationType.shopNotice).toList();

  /// Thông báo bảo trì / nâng cấp mới nhất nếu có
  AppNotification? get latestMaintenanceAlert {
    try {
      return _notifications.firstWhere((n) => n.isMaintenanceOrUpgrade);
    } catch (_) {
      return null;
    }
  }

  /// Thêm thông báo mới cho người dùng (làm tăng số chấm đỏ ngay lập tức)
  Future<void> addNotification({
    required String title,
    required String message,
    required NotificationType type,
    String? targetRacketId,
    String? targetOrderId,
    String? targetUserId,
  }) async {
    final notif = AppNotification(
      id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      message: message,
      type: type,
      timestamp: DateTime.now(),
      targetRacketId: targetRacketId,
      targetOrderId: targetOrderId,
      targetUserId: targetUserId ?? _currentUserId,
      isRead: false,
    );
    
    // Nếu thông báo gửi cho chính user hiện tại thì nạp vào RAM
    if (targetUserId == null || targetUserId == _currentUserId) {
      _notifications.insert(0, notif);
      notifyListeners();
      await _saveCacheDirect();
    }

    // Đồng bộ Firestore người dùng
    final recipient = targetUserId ?? _currentUserId;
    if (_isFirebaseReady &&
        recipient != null &&
        recipient.isNotEmpty &&
        recipient != 'guest_user') {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(recipient)
            .collection('notifications')
            .doc(notif.id)
            .set(notif.toMap())
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('addNotification Firestore error: $e');
      }
    }
  }

  /// Đánh dấu một thông báo là đã đọc (giảm số chấm đỏ)
  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index].isRead = true;
      notifyListeners();

      await _saveCacheDirect();

      if (_isFirebaseReady &&
          _currentUserId != null &&
          _currentUserId!.isNotEmpty &&
          _currentUserId != 'guest_user') {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_currentUserId)
              .collection('notifications')
              .doc(id)
              .update({'isRead': true})
              .timeout(const Duration(seconds: 4));
        } catch (e) {
          debugPrint('markAsRead Firestore error: $e');
        }
      }
    }
  }

  /// Đánh dấu tất cả thông báo là đã đọc (xóa hết chấm đỏ)
  Future<void> markAllAsRead() async {
    bool hasUnread = false;
    for (var n in _notifications) {
      if (!n.isRead) {
        n.isRead = true;
        hasUnread = true;
      }
    }
    if (!hasUnread) return;
    notifyListeners();

    await _saveCacheDirect();

    if (_isFirebaseReady &&
        _currentUserId != null &&
        _currentUserId!.isNotEmpty &&
        _currentUserId != 'guest_user') {
      try {
        final colRef = FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUserId)
            .collection('notifications');
        final snap = await colRef.where('isRead', isEqualTo: false).limit(50).get();
        if (snap.docs.isNotEmpty) {
          final batch = FirebaseFirestore.instance.batch();
          for (final doc in snap.docs) {
            batch.update(doc.reference, {'isRead': true});
          }
          await batch.commit().timeout(const Duration(seconds: 5));
        }
      } catch (e) {
        debugPrint('markAllAsRead Firestore error: $e');
      }
    }
  }

  /// Tự động kiểm tra và sinh cảnh báo cho những cây vợt cần thay cước
  Future<void> syncRacketTensionAlerts(List<Racket> rackets) async {
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

          // Lưu lên Firestore người dùng nếu có thể
          if (_isFirebaseReady &&
              _currentUserId != null &&
              _currentUserId!.isNotEmpty &&
              _currentUserId != 'guest_user') {
            try {
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(_currentUserId)
                  .collection('notifications')
                  .doc(notif.id)
                  .set(notif.toMap())
                  .timeout(const Duration(seconds: 5));
            } catch (_) {}
          }
        }
      }
    }
    if (hasChange) {
      notifyListeners();
      await _saveCacheDirect();
    }
  }

  /// Dành cho Admin: Phát thông báo toàn hệ thống và lưu lên Cloud Firestore (`system_notifications`)
  Future<void> broadcastSystemNotification({
    required String title,
    required String message,
    NotificationType type = NotificationType.systemAlert,
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
      await _saveUserCache(prefs);

      // Lưu vào kho thông báo hệ thống để mọi đối tượng người dùng (Chủ Shop & Người chơi) đều tải được
      final rawSys = prefs.getString(_prefSystemNotifsKey);
      List<dynamic> sysList = [];
      if (rawSys != null && rawSys.isNotEmpty) {
        try {
          sysList = jsonDecode(rawSys) as List<dynamic>;
        } catch (_) {}
      }
      sysList.insert(0, notif.toMap());
      await prefs.setString(_prefSystemNotifsKey, jsonEncode(sysList));

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
      await _saveUserCache(prefs);

      final rawSys = prefs.getString(_prefSystemNotifsKey);
      if (rawSys != null && rawSys.isNotEmpty) {
        try {
          final list = (jsonDecode(rawSys) as List<dynamic>)
              .where((item) => item['id'] != id)
              .toList();
          await prefs.setString(_prefSystemNotifsKey, jsonEncode(list));
        } catch (_) {}
      }

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

  /// Xóa một thông báo cụ thể
  Future<void> removeNotification(String id) async {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();

    await _saveCacheDirect();

    if (_isFirebaseReady &&
        _currentUserId != null &&
        _currentUserId!.isNotEmpty &&
        _currentUserId != 'guest_user') {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUserId)
            .collection('notifications')
            .doc(id)
            .delete()
            .timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('removeNotification error: $e');
      }
    }
  }

  /// Xóa tất cả thông báo của người chơi
  Future<void> clearAllNotifications() async {
    _notifications.clear();
    notifyListeners();

    await _saveCacheDirect();

    if (_isFirebaseReady &&
        _currentUserId != null &&
        _currentUserId!.isNotEmpty &&
        _currentUserId != 'guest_user') {
      try {
        final colRef = FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUserId)
            .collection('notifications');
        final snap = await colRef.limit(100).get();
        if (snap.docs.isNotEmpty) {
          final batch = FirebaseFirestore.instance.batch();
          for (final doc in snap.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit().timeout(const Duration(seconds: 5));
        }
      } catch (e) {
        debugPrint('clearAllNotifications error: $e');
      }
    }
  }
}
