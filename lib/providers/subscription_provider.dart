import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subscription_model.dart';
import '../models/user_model.dart';
import '../models/shop_model.dart';
import '../models/notification_model.dart';
import '../services/vietqr_service.dart';
import '../services/sepay_service.dart';
import 'auth_provider.dart';
import 'shop_provider.dart';
import 'notification_provider.dart';
import 'admin_provider.dart';

class SubscriptionProvider with ChangeNotifier {
  static const String _prefTransactionsKey = 'gearsports_subscription_transactions';

  final List<PaymentTransaction> _transactions = [];
  bool _isLoading = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _transactionsSubscription;

  SubscriptionProvider() {
    _initTransactions();
  }

  bool get isLoading => _isLoading;
  List<PaymentTransaction> get transactions => List.unmodifiable(_transactions);

  bool get _isFirebaseReady {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // --- Thống kê doanh thu và gói cước dành cho Admin ---
  int get totalRevenueVnd {
    return _transactions
        .where((t) => t.isCompleted)
        .fold(0, (acc, t) => acc + t.amount);
  }

  int get playerVipRevenueVnd {
    return _transactions
        .where((t) => t.isCompleted && t.planId.startsWith('player_'))
        .fold(0, (acc, t) => acc + t.amount);
  }

  int get shopSubscriptionRevenueVnd {
    return _transactions
        .where((t) => t.isCompleted && t.planId.startsWith('shop_'))
        .fold(0, (acc, t) => acc + t.amount);
  }

  int get totalTransactionsCount => _transactions.length;
  int get completedTransactionsCount =>
      _transactions.where((t) => t.isCompleted).length;

  // --- Danh sách chống gian lận & dùng lại giao dịch cũ (Replay Attack Prevention) ---
  Set<String> get usedTransactionIds {
    final set = <String>{};
    for (final t in _transactions) {
      if (t.isCompleted) {
        if (t.id.isNotEmpty) set.add(t.id);
      }
    }
    return set;
  }

  Set<String> get usedTransferCodes {
    final set = <String>{};
    for (final t in _transactions) {
      if (t.isCompleted && t.bankTransferCode.isNotEmpty) {
        set.add(SepayService.normalizeCode(t.bankTransferCode));
      }
    }
    return set;
  }

  Future<void> _initTransactions() async {
    // 1. Tải cache cục bộ trước
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedRaw = prefs.getString(_prefTransactionsKey);
      if (cachedRaw != null && cachedRaw.isNotEmpty) {
        final decoded = jsonDecode(cachedRaw) as List<dynamic>;
        _transactions.clear();
        _transactions.addAll(
          decoded.map((e) => PaymentTransaction.fromMap(Map<String, dynamic>.from(e))),
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Load cached transactions error: $e');
    }

    // 2. Lắng nghe real-time từ Cloud Firestore nếu sẵn sàng
    if (_isFirebaseReady) {
      try {
        _transactionsSubscription = FirebaseFirestore.instance
            .collection('subscription_transactions')
            .orderBy('createdAt', descending: true)
            .snapshots()
            .listen((snapshot) async {
          final incoming = snapshot.docs
              .map((doc) => PaymentTransaction.fromMap(doc.data(), docId: doc.id))
              .toList();
          _transactions.clear();
          _transactions.addAll(incoming);
          _saveCache();
          notifyListeners();
        }, onError: (err) {
          debugPrint('subscription_transactions listener warning: $err');
        });
      } catch (e) {
        debugPrint('setup transactions subscription error: $e');
      }
    }
  }

  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _transactions.map((t) => t.toMap()).toList();
      await prefs.setString(_prefTransactionsKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Save transactions cache error: $e');
    }
  }

  /// Nâng cấp gói VIP cho Player
  Future<bool> upgradePlayerSubscription({
    required BuildContext context,
    required UserModel user,
    required SubscriptionPlan plan,
    String? customTxId,
    String? customTransferCode,
    String? paymentMethod,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Tính thời hạn VIP mới
      final now = DateTime.now();
      DateTime newVipExpires;
      if (user.isVipActive && user.vipExpiresAt != null && user.vipExpiresAt!.isAfter(now)) {
        newVipExpires = user.vipExpiresAt!.add(Duration(days: plan.durationDays));
      } else {
        newVipExpires = now.add(Duration(days: plan.durationDays));
      }

      // 2. Tạo bản ghi giao dịch
      final txId = customTxId ?? 'TX_VIP_${now.millisecondsSinceEpoch}';
      final transferCode = customTransferCode ??
          VietQrConfig.generateTransferContent(
            prefix: 'VIP',
            userId: user.uid,
          );

      final transaction = PaymentTransaction(
        id: txId,
        userId: user.uid,
        userEmail: user.email,
        userName: user.fullName,
        userRole: 'player',
        planId: plan.id,
        planTitle: plan.title,
        amount: plan.priceVnd,
        durationDays: plan.durationDays,
        paymentMethod: paymentMethod ?? 'VietQR (Napas 24/7)',
        bankTransferCode: transferCode,
        status: 'completed',
        createdAt: now,
        completedAt: now,
      );

      // 3. Cập nhật VIP trong AuthProvider & Firestore users
      final authProv = context.read<AuthProvider>();
      await authProv.updateVipStatus(
        isVip: true,
        vipExpiresAt: newVipExpires,
        targetUid: user.uid,
      );

      // 4. Lưu giao dịch lên Firestore & Local
      await _recordTransaction(transaction);

      // 5. Gửi thông báo hệ thống chúc mừng
      if (context.mounted) {
        final notifProv = context.read<NotificationProvider>();
        notifProv.addNotification(
          title: 'Nâng Cấp VIP Thành Công! 👑',
          message: 'Chúc mừng bạn đã kích hoạt ${plan.title}. Giờ đây bạn có thể quản lý không giới hạn số lượng vợt và sử dụng trọn vẹn Bác Sĩ Thể Thao!',
          type: NotificationType.promo,
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('upgradePlayerSubscription error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Gia hạn gói duy trì cho Chủ Cửa Hàng (Shop)
  Future<bool> upgradeShopSubscription({
    required BuildContext context,
    required Shop shop,
    required UserModel user,
    required SubscriptionPlan plan,
    String? customTxId,
    String? customTransferCode,
    String? paymentMethod,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      DateTime newSubscriptionExpires;
      if (shop.isPaidActive && shop.subscriptionExpiresAt != null && shop.subscriptionExpiresAt!.isAfter(now)) {
        newSubscriptionExpires = shop.subscriptionExpiresAt!.add(Duration(days: plan.durationDays));
      } else if (shop.isTrialActive && shop.effectiveTrialExpiry.isAfter(now)) {
        newSubscriptionExpires = shop.effectiveTrialExpiry.add(Duration(days: plan.durationDays));
      } else {
        newSubscriptionExpires = now.add(Duration(days: plan.durationDays));
      }

      final txId = customTxId ?? 'TX_SHOP_${now.millisecondsSinceEpoch}';
      final transferCode = customTransferCode ??
          VietQrConfig.generateTransferContent(
            prefix: 'SHOP',
            userId: shop.id,
          );

      final transaction = PaymentTransaction(
        id: txId,
        userId: user.uid,
        userEmail: user.email,
        userName: user.fullName,
        userRole: 'stringer',
        shopId: shop.id,
        shopName: shop.name,
        planId: plan.id,
        planTitle: plan.title,
        amount: plan.priceVnd,
        durationDays: plan.durationDays,
        paymentMethod: paymentMethod ?? 'VietQR (Napas 24/7)',
        bankTransferCode: transferCode,
        status: 'completed',
        createdAt: now,
        completedAt: now,
      );

      // Cập nhật hạn đăng ký của shop qua ShopProvider
      final shopProv = context.read<ShopProvider>();
      await shopProv.updateShopSubscription(
        shopId: shop.id,
        subscriptionExpiresAt: newSubscriptionExpires,
      );

      // Lưu giao dịch
      await _recordTransaction(transaction);

      // Gửi thông báo
      if (context.mounted) {
        final notifProv = context.read<NotificationProvider>();
        notifProv.addNotification(
          title: 'Gia Hạn Dịch Vụ Shop Thành Công! 🏸',
          message: 'Cửa hàng ${shop.name} đã được gia hạn ${plan.shortTitle}. Cửa hàng của bạn luôn sẵn sàng phục vụ các tay vợt!',
          type: NotificationType.promo,
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('upgradeShopSubscription error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Admin cấp VIP miễn phí cho Player
  Future<bool> adminGrantVip({
    required BuildContext context,
    required UserModel user,
    required int days,
  }) async {
    try {
      final now = DateTime.now();
      DateTime newVipExpires;
      if (user.isVipActive && user.vipExpiresAt != null && user.vipExpiresAt!.isAfter(now)) {
        newVipExpires = user.vipExpiresAt!.add(Duration(days: days));
      } else {
        newVipExpires = now.add(Duration(days: days));
      }

      final txId = 'TX_ADMIN_VIP_${now.millisecondsSinceEpoch}';
      final transaction = PaymentTransaction(
        id: txId,
        userId: user.uid,
        userEmail: user.email,
        userName: user.fullName,
        userRole: 'player',
        planId: 'admin_grant_${days}d',
        planTitle: 'Admin Cấp VIP Đặc Quyền ($days ngày)',
        amount: 0,
        durationDays: days,
        paymentMethod: 'Quản trị viên cấp miễn phí',
        bankTransferCode: 'ADMIN_GRANT',
        status: 'completed',
        createdAt: now,
        completedAt: now,
      );

      final authProv = context.read<AuthProvider>();
      AdminProvider? adminProv;
      try {
        adminProv = context.read<AdminProvider>();
      } catch (_) {}

      await authProv.updateVipStatus(
        isVip: true,
        vipExpiresAt: newVipExpires,
        targetUid: user.uid,
      );

      // Cập nhật ngay danh sách _users trong AdminProvider để UI Admin cập nhật tức thì
      if (adminProv != null) {
        try {
          await adminProv.updateUserVipStatus(
            uid: user.uid,
            isVip: true,
            vipExpiresAt: newVipExpires,
          );
        } catch (e) {
          debugPrint('AdminProvider updateUserVipStatus in adminGrantVip warning: $e');
        }
      }

      await _recordTransaction(transaction);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('adminGrantVip error: $e');
      return false;
    }
  }

  /// Admin gia hạn dịch vụ miễn phí cho Shop
  Future<bool> adminGrantShopSubscription({
    required BuildContext context,
    required Shop shop,
    required int days,
  }) async {
    try {
      final now = DateTime.now();
      DateTime newExpires;
      if (shop.isPaidActive && shop.subscriptionExpiresAt != null && shop.subscriptionExpiresAt!.isAfter(now)) {
        newExpires = shop.subscriptionExpiresAt!.add(Duration(days: days));
      } else if (shop.isTrialActive && shop.effectiveTrialExpiry.isAfter(now)) {
        newExpires = shop.effectiveTrialExpiry.add(Duration(days: days));
      } else {
        newExpires = now.add(Duration(days: days));
      }

      final txId = 'TX_ADMIN_SHOP_${now.millisecondsSinceEpoch}';
      final transaction = PaymentTransaction(
        id: txId,
        userId: shop.ownerUid ?? 'unknown',
        userEmail: shop.ownerEmail ?? '',
        userName: shop.ownerName ?? shop.name,
        userRole: 'stringer',
        shopId: shop.id,
        shopName: shop.name,
        planId: 'admin_grant_shop_${days}d',
        planTitle: 'Admin Gia Hạn Cửa Hàng ($days ngày)',
        amount: 0,
        durationDays: days,
        paymentMethod: 'Quản trị viên gia hạn',
        bankTransferCode: 'ADMIN_GRANT',
        status: 'completed',
        createdAt: now,
        completedAt: now,
      );

      final shopProv = context.read<ShopProvider>();
      await shopProv.updateShopSubscription(
        shopId: shop.id,
        subscriptionExpiresAt: newExpires,
      );

      await _recordTransaction(transaction);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('adminGrantShopSubscription error: $e');
      return false;
    }
  }

  Future<void> _recordTransaction(PaymentTransaction transaction) async {
    _transactions.removeWhere((t) => t.id == transaction.id);
    _transactions.insert(0, transaction);
    await _saveCache();

    if (_isFirebaseReady) {
      try {
        await FirebaseFirestore.instance
            .collection('subscription_transactions')
            .doc(transaction.id)
            .set(transaction.toMap(), SetOptions(merge: true))
            .timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('Firestore save transaction warning: $e');
      }
    }
  }

  @override
  void dispose() {
    _transactionsSubscription?.cancel();
    super.dispose();
  }
}
