import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_model.dart';
import '../models/shop_model.dart';
import '../models/shop_report_model.dart';
import '../models/user_model.dart';

class ChatProvider with ChangeNotifier {
  static const String _prefReportsKey = 'gearsports_shop_reports';

  String? _currentUserId;
  UserRole? _currentUserRole;
  String? _currentShopId;

  final List<ChatThread> _threads = [];
  final List<ShopReport> _reports = [];
  StreamSubscription<QuerySnapshot>? _threadsSubscription;
  StreamSubscription<QuerySnapshot>? _reportsSubscription;

  String get _prefThreadsKey =>
      'gearsports_chat_threads_${_currentUserId ?? "default"}';

  ChatProvider() {
    _loadReportsAndSyncFirebase();
  }

  String? get currentUserId => _currentUserId;

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

  /// Đồng bộ tin nhắn thời gian thực: Firestore collection 'chat_threads'
  /// - Admin: Xem toàn bộ tin nhắn trên hệ thống
  /// - Chủ Shop: Xem toàn bộ tin nhắn gửi đến shop của mình (shopId hoặc shopOwnerUid)
  /// - Người chơi: Xem các tin nhắn mình gửi đến các shop
  Future<void> syncForUser(
    String? userId, {
    UserRole? role,
    String? shopId,
  }) async {
    if (_currentUserId == userId &&
        _currentUserRole == role &&
        _currentShopId == shopId &&
        _threads.isNotEmpty) {
      return;
    }
    _currentUserId = userId;
    _currentUserRole = role;
    _currentShopId = shopId;
    _threadsSubscription?.cancel();

    if (userId == null || userId.isEmpty || userId == 'guest_user') {
      _threads.clear();
      notifyListeners();
      return;
    }

    try {
      // 1. Đọc từ local cache trước
      final prefs = await SharedPreferences.getInstance();
      final rawThreads = prefs.getString(_prefThreadsKey);
      if (rawThreads != null && rawThreads.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawThreads) as List<dynamic>;
          final loadedThreads = decoded
              .map((e) => ChatThread.fromMap(Map<String, dynamic>.from(e)))
              .toList();
          _threads.clear();
          _threads.addAll(loadedThreads);
          notifyListeners();
        } catch (_) {}
      }

      // 2. Lắng nghe thời gian thực trên Firestore collection 'chat_threads'
      if (_isFirebaseReady) {
        _threadsSubscription = FirebaseFirestore.instance
            .collection('chat_threads')
            .snapshots()
            .listen(
          (snapshot) {
            final allRemoteThreads = <ChatThread>[];
            for (final doc in snapshot.docs) {
              try {
                final data = doc.data();
                var t = ChatThread.fromMap(data, docId: doc.id);

                // Xác định xem tin nhắn cuối có phải do chính người dùng hiện tại gửi không:
                final lastSenderId = data['lastSenderId']?.toString() ??
                    (t.messages.isNotEmpty ? t.messages.last.senderId : null);
                final lastSenderIsUser = (data['lastSenderIsUser'] as bool?) ??
                    (t.messages.isNotEmpty ? t.messages.last.isFromUser : null);

                bool isSentByMe = false;
                if (role == UserRole.stringer) {
                  // Chủ shop: đã gửi nếu lastSenderIsUser == false hoặc sender khớp với shop
                  if (lastSenderIsUser == false ||
                      (lastSenderId != null &&
                          (lastSenderId == shopId || lastSenderId == userId))) {
                    isSentByMe = true;
                  }
                } else if (role == UserRole.player || role == null) {
                  // Người chơi: đã gửi nếu lastSenderIsUser == true hoặc sender là 'user'/userId
                  if (lastSenderIsUser == true ||
                      (lastSenderId != null &&
                          (lastSenderId == 'user' || lastSenderId == userId))) {
                    isSentByMe = true;
                  }
                }

                if (isSentByMe) {
                  t = ChatThread(
                    id: t.id,
                    userId: t.userId,
                    userName: t.userName,
                    userEmail: t.userEmail,
                    shopId: t.shopId,
                    shopOwnerUid: t.shopOwnerUid,
                    shopName: t.shopName,
                    shopAvatar: t.shopAvatar,
                    lastMessage: t.lastMessage,
                    lastMessageTime: t.lastMessageTime,
                    unreadCount: 0,
                    messages: t.messages,
                  );
                }

                allRemoteThreads.add(t);
              } catch (e) {
                debugPrint('Lỗi parse chat_thread doc ${doc.id}: $e');
              }
            }

            // Lọc theo Role & Quyền hạn:
            List<ChatThread> relevantThreads;
            if (role == UserRole.admin) {
              // Admin xem TOÀN BỘ tin nhắn của mọi shop và player
              relevantThreads = allRemoteThreads;
            } else if (role == UserRole.stringer) {
              // Chủ shop xem các cuộc hội thoại gửi đến Shop của mình hoặc do mình sở hữu
              relevantThreads = allRemoteThreads.where((t) {
                if (shopId != null && shopId.isNotEmpty && t.shopId == shopId) return true;
                if (t.shopOwnerUid != null && t.shopOwnerUid == userId) return true;
                if (t.userId == userId) return true;
                return false;
              }).toList();
            } else {
              // Người chơi chỉ xem các cuộc hội thoại của chính mình
              relevantThreads = allRemoteThreads.where((t) => t.userId == userId).toList();
            }

            relevantThreads.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
            _threads.clear();
            _threads.addAll(relevantThreads);
            _persistThreads();
            notifyListeners();
          },
          onError: (e) {
            debugPrint('Lỗi lắng nghe Firestore chat_threads: $e');
          },
        );
      }
    } catch (e) {
      debugPrint('ChatProvider syncForUser error: $e');
    }
  }

  ChatThread getOrCreateThreadForShop(
    String shopId,
    String shopName,
    String shopAvatar, {
    String? shopOwnerUid,
    String? userName,
    String? userEmail,
  }) {
    // 1. Kiểm tra trong danh sách hiện tại
    final existingIdx = _threads.indexWhere(
      (t) => t.shopId == shopId && (_currentUserId == null || t.userId == _currentUserId),
    );
    if (existingIdx != -1) {
      return _threads[existingIdx];
    }

    // 2. Tạo thread mới với ID chuẩn: 'thread_${userId}_${shopId}'
    final threadId = 'thread_${_currentUserId ?? "user"}_$shopId';
    final newThread = ChatThread(
      id: threadId,
      userId: _currentUserId ?? 'user',
      userName: userName,
      userEmail: userEmail,
      shopId: shopId,
      shopOwnerUid: shopOwnerUid,
      shopName: shopName,
      shopAvatar: shopAvatar,
      lastMessage: 'Đã kết nối với thợ đan tại $shopName',
      lastMessageTime: DateTime.now(),
      unreadCount: 0,
      messages: [],
    );
    _threads.insert(0, newThread);
    _persistThreads();

    // 3. Lưu vào Cloud Firestore collection 'chat_threads'
    if (_isFirebaseReady && _currentUserId != null && _currentUserId != 'guest_user') {
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
        userId: thread.userId,
        userName: thread.userName,
        userEmail: thread.userEmail,
        shopId: thread.shopId,
        shopOwnerUid: thread.shopOwnerUid,
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

      // Đồng bộ tin nhắn mới lên Cloud Firestore (chung cho cả Player, Shop, Admin)
      _syncMessageToFirestore(updatedThread, newMsg);
    }
  }

  List<ChatThread> getThreadsForShop(String shopId) {
    return _threads.where((t) => t.shopId == shopId || t.shopOwnerUid == _currentUserId).toList();
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
        userId: thread.userId,
        userName: thread.userName,
        userEmail: thread.userEmail,
        shopId: thread.shopId,
        shopOwnerUid: thread.shopOwnerUid,
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
        userId: thread.userId,
        userName: thread.userName,
        userEmail: thread.userEmail,
        shopId: thread.shopId,
        shopOwnerUid: thread.shopOwnerUid,
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

      _syncMessageToFirestore(updatedThread, newMsg);
    }
  }

  Future<void> _syncMessageToFirestore(ChatThread thread, ChatMessage msg) async {
    if (!_isFirebaseReady) return;
    try {
      final threadDoc = FirebaseFirestore.instance
          .collection('chat_threads')
          .doc(thread.id);

      final threadData = thread.toMap();
      // Sử dụng FieldValue.increment(1) thay vì đặt cứng unreadCount: 0,
      // giúp đối phương (người chơi hoặc cửa hàng) nhận được huy hiệu tin nhắn chưa đọc
      threadData['unreadCount'] = FieldValue.increment(1);
      threadData['lastSenderId'] = msg.senderId;
      threadData['lastSenderIsUser'] = msg.isFromUser;

      // 1. Cập nhật thread document (lastMessage, lastMessageTime, mảng messages, và tăng unreadCount đối phương)
      await threadDoc.set(threadData, SetOptions(merge: true));
      // 2. Lưu tin nhắn chi tiết vào subcollection 'messages'
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
        userId: thread.userId,
        userName: thread.userName,
        userEmail: thread.userEmail,
        shopId: thread.shopId,
        shopOwnerUid: thread.shopOwnerUid,
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

  Future<void> _persistThreads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(_threads.map((t) => t.toMap()).toList());
      await prefs.setString(_prefThreadsKey, data);
    } catch (e) {
      debugPrint('Persist threads error: $e');
    }
  }

  // --- QUẢN LÝ BÁO CÁO / KHIẾU NẠI CỬA HÀNG (SHOP REPORTS) ---

  Future<void> _loadReportsAndSyncFirebase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefReportsKey);
      if (raw != null && raw.isNotEmpty) {
        try {
          final list = jsonDecode(raw) as List<dynamic>;
          _reports.clear();
          _reports.addAll(
            list.map((e) => ShopReport.fromMap(Map<String, dynamic>.from(e))),
          );
          notifyListeners();
        } catch (_) {}
      }

      if (_isFirebaseReady) {
        _reportsSubscription = FirebaseFirestore.instance
            .collection('shop_reports')
            .snapshots()
            .listen(
          (snapshot) {
            final remoteReports = snapshot.docs
                .map((d) => ShopReport.fromMap(d.data(), docId: d.id))
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            _reports.clear();
            _reports.addAll(remoteReports);
            _persistReports();
            notifyListeners();
          },
          onError: (e) {
            debugPrint('Lỗi lắng nghe Firestore shop_reports: $e');
          },
        );
      }
    } catch (e) {
      debugPrint('loadReports error: $e');
    }
  }

  Future<bool> submitReport(ShopReport report) async {
    try {
      _reports.insert(0, report);
      _persistReports();
      notifyListeners();

      if (_isFirebaseReady) {
        await FirebaseFirestore.instance
            .collection('shop_reports')
            .doc(report.id)
            .set(report.toMap(), SetOptions(merge: true))
            .timeout(const Duration(seconds: 5));
      }
      return true;
    } catch (e) {
      debugPrint('submitReport error: $e');
      return false;
    }
  }

  Future<void> resolveReport(String reportId, {String status = 'resolved', String? adminNote}) async {
    final idx = _reports.indexWhere((r) => r.id == reportId);
    if (idx != -1) {
      final updated = _reports[idx].copyWith(
        status: status,
        adminNote: adminNote,
      );
      _reports[idx] = updated;
      _persistReports();
      notifyListeners();

      if (_isFirebaseReady) {
        await FirebaseFirestore.instance
            .collection('shop_reports')
            .doc(reportId)
            .set(updated.toMap(), SetOptions(merge: true))
            .timeout(const Duration(seconds: 5));
      }
    }
  }

  Future<void> deleteReport(String reportId) async {
    _reports.removeWhere((r) => r.id == reportId);
    _persistReports();
    notifyListeners();

    if (_isFirebaseReady) {
      try {
        await FirebaseFirestore.instance
            .collection('shop_reports')
            .doc(reportId)
            .delete()
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('deleteReport error: $e');
      }
    }
  }

  Future<void> deleteMessage(String threadId, String messageId) async {
    final threadIdx = _threads.indexWhere((t) => t.id == threadId);
    if (threadIdx != -1) {
      final thread = _threads[threadIdx];
      final updatedMsgs = thread.messages.where((m) => m.id != messageId).toList();
      final updatedThread = ChatThread(
        id: thread.id,
        userId: thread.userId,
        userName: thread.userName,
        userEmail: thread.userEmail,
        shopId: thread.shopId,
        shopOwnerUid: thread.shopOwnerUid,
        shopName: thread.shopName,
        shopAvatar: thread.shopAvatar,
        lastMessage: updatedMsgs.isNotEmpty ? updatedMsgs.last.text : 'Tin nhắn đã được xóa',
        lastMessageTime: updatedMsgs.isNotEmpty ? updatedMsgs.last.timestamp : thread.lastMessageTime,
        unreadCount: thread.unreadCount,
        messages: updatedMsgs,
      );
      _threads[threadIdx] = updatedThread;
      _persistThreads();
      notifyListeners();

      if (_isFirebaseReady) {
        try {
          final threadDoc = FirebaseFirestore.instance.collection('chat_threads').doc(threadId);
          await threadDoc.set(updatedThread.toMap(), SetOptions(merge: true));
          await threadDoc.collection('messages').doc(messageId).delete();
        } catch (e) {
          debugPrint('deleteMessage error: $e');
        }
      }
    }
  }

  Future<void> _persistReports() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefReportsKey,
        jsonEncode(_reports.map((r) => r.toMap()).toList()),
      );
    } catch (e) {
      debugPrint('persistReports error: $e');
    }
  }
}
