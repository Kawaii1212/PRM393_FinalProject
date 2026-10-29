import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_model.dart';
import '../models/shop_model.dart';
import '../models/shop_report_model.dart';
import '../data/mock_data.dart';

class ChatProvider with ChangeNotifier {
  static const String _prefThreadsKey = 'gearsports_chat_threads';
  static const String _prefReportsKey = 'gearsports_shop_reports';

  final List<ChatThread> _threads = List.from(MockData.initialThreads);
  final List<ShopReport> _reports = [];
  StreamSubscription<QuerySnapshot>? _threadsSubscription;
  StreamSubscription<QuerySnapshot>? _reportsSubscription;

  ChatProvider() {
    _loadCacheAndSyncFirebase();
  }

  @override
  void dispose() {
    _threadsSubscription?.cancel();
    _reportsSubscription?.cancel();
    super.dispose();
  }

  bool get _isFirebaseReady {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  List<ChatThread> get threads => List.unmodifiable(_threads);
  List<ShopReport> get reports => List.unmodifiable(_reports);

  int get unreadMessagesCount {
    return _threads.fold(0, (total, t) => total + t.unreadCount);
  }

  int get pendingReportsCount {
    return _reports.where((r) => r.isPending).length;
  }

  /// Kiểm tra xem shop có phải là shop đối tác đã đăng ký trên app và được Admin phê duyệt không
  bool isShopApprovedForChat(Shop? shop) {
    return shop != null && shop.isVerifiedPartner;
  }

  ChatThread? getThread(String threadId) {
    try {
      return _threads.firstWhere((t) => t.id == threadId);
    } catch (_) {
      return null;
    }
  }

  ChatThread? getThreadForShop(String shopId) {
    try {
      return _threads.firstWhere((t) => t.shopId == shopId);
    } catch (_) {
      return null;
    }
  }

  ChatThread getOrCreateThreadForShop(String shopId, String shopName, String shopAvatar) {
    final existing = _threads.indexWhere((t) => t.shopId == shopId);
    if (existing != -1) {
      return _threads[existing];
    }
    final newThread = ChatThread(
      id: 'thread_${DateTime.now().millisecondsSinceEpoch}',
      shopId: shopId,
      shopName: shopName,
      shopAvatar: shopAvatar,
      lastMessage: 'Đã kết nối với thợ đan tại $shopName',
      lastMessageTime: DateTime.now(),
      unreadCount: 0,
      messages: [],
    );
    _threads.insert(0, newThread);
    _persistThreads();

    // Lưu luồng chat lên Cloud Firestore
    if (_isFirebaseReady) {
      try {
        FirebaseFirestore.instance
            .collection('chat_threads')
            .doc(newThread.id)
            .set(newThread.toMap(), SetOptions(merge: true))
            .catchError((e) => debugPrint('Firestore save new thread error: $e'));
      } catch (e) {
        debugPrint('Firestore save thread error: $e');
      }
    }

    notifyListeners();
    return newThread;
  }

  /// Gửi tin nhắn từ người chơi lên RAM, SharedPreferences và Cloud Firestore
  void sendMessage(
    String threadId,
    String text, {
    String? attachedRacketName,
    String? attachedTension,
  }) {
    final index = _threads.indexWhere((t) => t.id == threadId);
    if (index != -1) {
      final thread = _threads[index];
      final newMsg = ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        senderId: 'user',
        text: text,
        timestamp: DateTime.now(),
        isFromUser: true,
        attachedRacketName: attachedRacketName,
        attachedTension: attachedTension,
      );

      final updatedMessages = List<ChatMessage>.from(thread.messages)..add(newMsg);
      final updatedThread = ChatThread(
        id: thread.id,
        shopId: thread.shopId,
        shopName: thread.shopName,
        shopAvatar: thread.shopAvatar,
        lastMessage: text,
        lastMessageTime: DateTime.now(),
        unreadCount: 0,
        messages: updatedMessages,
      );
      _threads[index] = updatedThread;
      _persistThreads();
      notifyListeners();

      // Đồng bộ tin nhắn mới lên Cloud Firestore (Cả thread document & messages subcollection)
      _syncMessageToFirestore(updatedThread, newMsg);
    }
  }

  List<ChatThread> getThreadsForShop(String shopId) {
    return _threads.where((t) => t.shopId == shopId).toList();
  }

  void sendMessageAsShop(String threadId, String text) {
    final index = _threads.indexWhere((t) => t.id == threadId);
    if (index != -1) {
      final thread = _threads[index];
      final newMsg = ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        senderId: thread.shopId,
        text: text,
        timestamp: DateTime.now(),
        isFromUser: false,
      );

      final updatedMessages = List<ChatMessage>.from(thread.messages)..add(newMsg);
      final updatedThread = ChatThread(
        id: thread.id,
        shopId: thread.shopId,
        shopName: thread.shopName,
        shopAvatar: thread.shopAvatar,
        lastMessage: text,
        lastMessageTime: DateTime.now(),
        unreadCount: 0,
        messages: updatedMessages,
      );
      _threads[index] = updatedThread;
      _persistThreads();
      notifyListeners();

      // Đồng bộ tin nhắn phản hồi của Shop lên Cloud Firestore
      _syncMessageToFirestore(updatedThread, newMsg);
    }
  }

  void sendSystemMessage(String threadId, String text) {
    final index = _threads.indexWhere((t) => t.id == threadId);
    if (index != -1) {
      final thread = _threads[index];
      final newMsg = ChatMessage(
        id: 'sys_${DateTime.now().millisecondsSinceEpoch}',
        senderId: 'system',
        text: text,
        timestamp: DateTime.now(),
        isFromUser: false,
        isSystemNotice: true,
      );

      final updatedMessages = List<ChatMessage>.from(thread.messages)..add(newMsg);
      final updatedThread = ChatThread(
        id: thread.id,
        shopId: thread.shopId,
        shopName: thread.shopName,
        shopAvatar: thread.shopAvatar,
        lastMessage: text,
        lastMessageTime: DateTime.now(),
        unreadCount: 0,
        messages: updatedMessages,
      );
      _threads[index] = updatedThread;
      _persistThreads();
      notifyListeners();

      // Đồng bộ tin nhắn cảnh báo hệ thống lên Cloud Firestore
      _syncMessageToFirestore(updatedThread, newMsg);
    }
  }

  Future<void> _syncMessageToFirestore(ChatThread thread, ChatMessage msg) async {
    if (!_isFirebaseReady) return;
    try {
      final threadDoc = FirebaseFirestore.instance.collection('chat_threads').doc(thread.id);
      // 1. Cập nhật thread document (bao gồm lastMessage, lastMessageTime và mảng messages)
      await threadDoc.set(thread.toMap(), SetOptions(merge: true));
      // 2. Lưu tin nhắn chi tiết vào subcollection 'messages' để tra cứu theo thời gian
      await threadDoc.collection('messages').doc(msg.id).set(msg.toMap());
    } catch (e) {
      debugPrint('_syncMessageToFirestore error: $e');
    }
  }

  void markThreadAsRead(String threadId) {
    final index = _threads.indexWhere((t) => t.id == threadId);
    if (index != -1 && _threads[index].unreadCount > 0) {
      final thread = _threads[index];
      final updatedThread = ChatThread(
        id: thread.id,
        shopId: thread.shopId,
        shopName: thread.shopName,
        shopAvatar: thread.shopAvatar,
        lastMessage: thread.lastMessage,
        lastMessageTime: thread.lastMessageTime,
        unreadCount: 0,
        messages: thread.messages,
      );
      _threads[index] = updatedThread;
      _persistThreads();
      notifyListeners();

      if (_isFirebaseReady) {
        FirebaseFirestore.instance
            .collection('chat_threads')
            .doc(threadId)
            .update({'unreadCount': 0})
            .catchError((e) => debugPrint('Firestore markThreadAsRead error: $e'));
      }
    }
  }

  void deleteThread(String threadId) {
    _threads.removeWhere((t) => t.id == threadId);
    _persistThreads();
    notifyListeners();

    if (_isFirebaseReady) {
      try {
        FirebaseFirestore.instance
            .collection('chat_threads')
            .doc(threadId)
            .delete()
            .catchError((e) => debugPrint('Firestore deleteThread error: $e'));
      } catch (e) {
        debugPrint('Firestore deleteThread exception: $e');
      }
    }
  }

  void deleteMessage(String threadId, String messageId) {
    final index = _threads.indexWhere((t) => t.id == threadId);
    if (index != -1) {
      final thread = _threads[index];
      final updatedMessages = thread.messages.where((m) => m.id != messageId).toList();
      final updatedThread = ChatThread(
        id: thread.id,
        shopId: thread.shopId,
        shopName: thread.shopName,
        shopAvatar: thread.shopAvatar,
        lastMessage: updatedMessages.isNotEmpty ? updatedMessages.last.text : 'Đoạn chat trống',
        lastMessageTime: updatedMessages.isNotEmpty ? updatedMessages.last.timestamp : thread.lastMessageTime,
        unreadCount: thread.unreadCount,
        messages: updatedMessages,
      );
      _threads[index] = updatedThread;
      _persistThreads();
      notifyListeners();

      if (_isFirebaseReady) {
        try {
          final threadDoc = FirebaseFirestore.instance.collection('chat_threads').doc(threadId);
          threadDoc.set(updatedThread.toMap(), SetOptions(merge: true));
          threadDoc.collection('messages').doc(messageId).delete();
        } catch (e) {
          debugPrint('Firestore deleteMessage error: $e');
        }
      }
    }
  }

  // ================= REPORT SHOP VIOLATIONS =================

  Future<void> submitReport(ShopReport report) async {
    _reports.insert(0, report);
    notifyListeners();
    await _persistReports();

    if (_isFirebaseReady) {
      try {
        await FirebaseFirestore.instance
            .collection('shop_reports')
            .doc(report.id)
            .set(report.toMap())
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('submitReport Firestore error: $e');
      }
    }
  }

  Future<void> resolveReport(
    String reportId, {
    String? adminNote,
    String status = 'resolved',
  }) async {
    final idx = _reports.indexWhere((r) => r.id == reportId);
    if (idx != -1) {
      _reports[idx] = _reports[idx].copyWith(
        status: status,
        adminNote: adminNote ?? _reports[idx].adminNote,
      );
      notifyListeners();
      await _persistReports();

      if (_isFirebaseReady) {
        try {
          await FirebaseFirestore.instance
              .collection('shop_reports')
              .doc(reportId)
              .update({
            'status': status,
            'adminNote': adminNote ?? _reports[idx].adminNote,
          }).timeout(const Duration(seconds: 5));
        } catch (e) {
          debugPrint('resolveReport Firestore error: $e');
        }
      }
    }
  }

  Future<void> deleteReport(String reportId) async {
    _reports.removeWhere((r) => r.id == reportId);
    notifyListeners();
    await _persistReports();

    if (_isFirebaseReady) {
      try {
        await FirebaseFirestore.instance
            .collection('shop_reports')
            .doc(reportId)
            .delete()
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('deleteReport Firestore error: $e');
      }
    }
  }

  List<ShopReport> getReportsForShop(String shopId) {
    return _reports.where((r) => r.shopId == shopId).toList();
  }

  ShopReport? getReportById(String reportId) {
    try {
      return _reports.firstWhere((r) => r.id == reportId);
    } catch (_) {
      return null;
    }
  }

  // ================= PERSISTENCE & CLOUD FIRESTORE REALTIME SYNC =================

  Future<void> _persistThreads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_threads.map((t) => t.toMap()).toList());
      await prefs.setString(_prefThreadsKey, encoded);
    } catch (e) {
      debugPrint('_persistThreads error: $e');
    }
  }

  Future<void> _persistReports() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_reports.map((r) => r.toMap()).toList());
      await prefs.setString(_prefReportsKey, encoded);
    } catch (e) {
      debugPrint('_persistReports error: $e');
    }
  }

  Future<void> _loadCacheAndSyncFirebase() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Tải bộ nhớ tạm Local SharedPreferences để giao diện hiển thị tức thì
      final rawThreads = prefs.getString(_prefThreadsKey);
      if (rawThreads != null && rawThreads.isNotEmpty) {
        final decoded = jsonDecode(rawThreads) as List<dynamic>;
        final loadedThreads = decoded
            .map((e) => ChatThread.fromMap(Map<String, dynamic>.from(e)))
            .toList();
        if (loadedThreads.isNotEmpty) {
          _threads.clear();
          _threads.addAll(loadedThreads);
        }
      }

      final rawReports = prefs.getString(_prefReportsKey);
      if (rawReports != null && rawReports.isNotEmpty) {
        final decoded = jsonDecode(rawReports) as List<dynamic>;
        final loadedReports = decoded
            .map((e) => ShopReport.fromMap(Map<String, dynamic>.from(e)))
            .toList();
        _reports.clear();
        _reports.addAll(loadedReports);
      }

      notifyListeners();

      // 2. KẾT NỐI VÀ LẮNG NGHE THỜI GIAN THỰC TỪ CLOUD FIRESTORE
      if (_isFirebaseReady) {
        // Lắng nghe luồng tin nhắn 'chat_threads' trên Firebase Firestore
        _threadsSubscription = FirebaseFirestore.instance
            .collection('chat_threads')
            .snapshots()
            .listen(
          (snapshot) {
            final remoteThreads = <ChatThread>[];
            for (final doc in snapshot.docs) {
              try {
                final t = ChatThread.fromMap(doc.data());
                remoteThreads.add(t);
              } catch (e) {
                debugPrint('Lỗi parse chat_thread doc ${doc.id}: $e');
              }
            }

            if (remoteThreads.isNotEmpty) {
              final mapById = <String, ChatThread>{};
              for (final t in _threads) {
                mapById[t.id] = t;
              }
              for (final t in remoteThreads) {
                mapById[t.id] = t;
              }
              final sorted = mapById.values.toList()
                ..sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
              _threads.clear();
              _threads.addAll(sorted);
              _persistThreads();
              notifyListeners();
            }
          },
          onError: (e) {
            debugPrint('Lỗi lắng nghe Firestore chat_threads: $e');
          },
        );

        // Lắng nghe đơn báo cáo 'shop_reports' trên Firebase Firestore
        _reportsSubscription = FirebaseFirestore.instance
            .collection('shop_reports')
            .orderBy('createdAt', descending: true)
            .snapshots()
            .listen(
          (snapshot) {
            final remoteReports = <ShopReport>[];
            for (final doc in snapshot.docs) {
              try {
                final r = ShopReport.fromMap(doc.data(), docId: doc.id);
                remoteReports.add(r);
              } catch (e) {
                debugPrint('Lỗi parse shop_report doc ${doc.id}: $e');
              }
            }

            if (remoteReports.isNotEmpty) {
              final mapById = <String, ShopReport>{};
              for (final r in _reports) {
                mapById[r.id] = r;
              }
              for (final r in remoteReports) {
                mapById[r.id] = r;
              }
              _reports.clear();
              _reports.addAll(mapById.values.toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
              _persistReports();
              notifyListeners();
            }
          },
          onError: (e) {
            debugPrint('Lỗi lắng nghe Firestore shop_reports: $e');
          },
        );
      }
    } catch (e) {
      debugPrint('ChatProvider _loadCacheAndSyncFirebase error: $e');
    }
  }
}
