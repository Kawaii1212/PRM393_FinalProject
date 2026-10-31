import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/racket_model.dart';

class UserRacketRecord {
  final String ownerUid;
  final String ownerName;
  final String ownerEmail;
  final Racket racket;

  const UserRacketRecord({
    required this.ownerUid,
    required this.ownerName,
    required this.ownerEmail,
    required this.racket,
  });
}

class AdminProvider with ChangeNotifier {
  static const String _prefLocalUsersKey = 'gearsports_local_users';

  List<UserModel> _users = [];
  List<UserRacketRecord> _allUserRackets = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<UserModel> get users => List.unmodifiable(_users);
  List<UserModel> get allUsers => List.unmodifiable(_users);
  List<UserRacketRecord> get allUserRackets =>
      List.unmodifiable(_allUserRackets);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get totalUsersCount => _users.length;
  int get playerCount =>
      _users.where((u) => u.role == UserRole.player).length;
  int get stringerCount =>
      _users.where((u) => u.role == UserRole.stringer).length;
  int get adminCount =>
      _users.where((u) => u.role == UserRole.admin).length;
  int get blockedUsersCount => _users.where((u) => u.isBlocked).length;
  int get totalCommunityRacketsCount => _allUserRackets.length;

  bool get _isFirebaseReady {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Tải toàn bộ danh sách Người dùng và Vợt cộng đồng từ Cloud Firestore + Local Storage
  Future<void> refreshAdminData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, UserModel> userMap = {};

      // 1. Đọc từ Local Storage trước
      final rawLocalUsers = prefs.getString(_prefLocalUsersKey);
      if (rawLocalUsers != null && rawLocalUsers.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawLocalUsers) as Map<String, dynamic>;
          for (final entry in decoded.values) {
            final map = entry as Map<String, dynamic>;
            if (map['user'] != null) {
              final u = UserModel.fromMap(
                Map<String, dynamic>.from(map['user']),
              );
              if (u.uid.isNotEmpty) {
                userMap[u.uid] = u;
              }
            }
          }
        } catch (_) {}
      }

      // 2. Đồng bộ từ Cloud Firestore: collection('users')
      if (_isFirebaseReady) {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .get()
            .timeout(const Duration(seconds: 7));

        for (final doc in snap.docs) {
          final u = UserModel.fromMap(doc.data(), docId: doc.id);
          userMap[u.uid] = u;
        }
      }

      final sortedUsers = userMap.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _users = sortedUsers;

      // 3. Tải danh sách vợt của tất cả người dùng (Kiểm duyệt dữ liệu cộng đồng UGC)
      final List<UserRacketRecord> racketsList = [];
      for (final user in _users) {
        bool loadedFromFirestore = false;
        if (_isFirebaseReady) {
          try {
            final racketSnap = await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('rackets')
                .get()
                .timeout(const Duration(seconds: 5));
            if (racketSnap.docs.isNotEmpty) {
              loadedFromFirestore = true;
              for (final rDoc in racketSnap.docs) {
                racketsList.add(
                  UserRacketRecord(
                    ownerUid: user.uid,
                    ownerName: user.fullName,
                    ownerEmail: user.email,
                    racket: Racket.fromMap(rDoc.data(), docId: rDoc.id),
                  ),
                );
              }
            }
          } catch (_) {}
        }

        if (!loadedFromFirestore) {
          final localRacketRaw = prefs.getString(
            'gearsports_rackets_${user.uid}',
          );
          if (localRacketRaw != null && localRacketRaw.isNotEmpty) {
            try {
              final decoded = jsonDecode(localRacketRaw) as List<dynamic>;
              for (final item in decoded) {
                racketsList.add(
                  UserRacketRecord(
                    ownerUid: user.uid,
                    ownerName: user.fullName,
                    ownerEmail: user.email,
                    racket: Racket.fromMap(Map<String, dynamic>.from(item)),
                  ),
                );
              }
            } catch (_) {}
          }
        }
      }

      _allUserRackets = racketsList;
    } catch (e) {
      _errorMessage = 'Lỗi đồng bộ dữ liệu Quản trị: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cập nhật thông tin người dùng (Họ tên, SĐT, Vai trò, Khóa/Mở khóa tài khoản)
  Future<void> updateUserByAdmin(UserModel updatedUser) async {
    final idx = _users.indexWhere((u) => u.uid == updatedUser.uid);
    if (idx != -1) {
      _users[idx] = updatedUser;
    } else {
      _users.insert(0, updatedUser);
    }
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawLocalUsers = prefs.getString(_prefLocalUsersKey);
      if (rawLocalUsers != null && rawLocalUsers.isNotEmpty) {
        final decoded = jsonDecode(rawLocalUsers) as Map<String, dynamic>;
        final emailKey = updatedUser.email.toLowerCase();
        if (decoded.containsKey(emailKey)) {
          final existing = decoded[emailKey] as Map<String, dynamic>;
          decoded[emailKey] = {
            'password': existing['password'] ?? '123456',
            'user': updatedUser.toMap(),
          };
          await prefs.setString(_prefLocalUsersKey, jsonEncode(decoded));
        }
      }

      if (_isFirebaseReady) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(updatedUser.uid)
            .set(updatedUser.toMap(), SetOptions(merge: true))
            .timeout(const Duration(seconds: 5));
      }
    } catch (e) {
      debugPrint('updateUserByAdmin error: $e');
    }
  }

  /// Cập nhật trạng thái VIP của người dùng trong RAM và SharedPreferences
  Future<void> updateUserVipStatus({
    required String uid,
    required bool isVip,
    required DateTime? vipExpiresAt,
  }) async {
    final idx = _users.indexWhere((u) => u.uid == uid);
    if (idx != -1) {
      final updated = _users[idx].copyWith(
        isVip: isVip,
        vipExpiresAt: vipExpiresAt,
      );
      _users[idx] = updated;
      notifyListeners();

      try {
        final prefs = await SharedPreferences.getInstance();
        final rawLocalUsers = prefs.getString(_prefLocalUsersKey);
        if (rawLocalUsers != null && rawLocalUsers.isNotEmpty) {
          final decoded = jsonDecode(rawLocalUsers) as Map<String, dynamic>;
          final emailKey = updated.email.toLowerCase();
          if (decoded.containsKey(emailKey)) {
            final existing = decoded[emailKey] as Map<String, dynamic>;
            decoded[emailKey] = {
              'password': existing['password'] ?? '123456',
              'user': updated.toMap(),
            };
            await prefs.setString(_prefLocalUsersKey, jsonEncode(decoded));
          }
        }

        if (_isFirebaseReady) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .set({
                'isVip': isVip,
                'vipExpiresAt': vipExpiresAt?.toIso8601String(),
              }, SetOptions(merge: true))
              .timeout(const Duration(seconds: 5));
        }
      } catch (e) {
        debugPrint('AdminProvider updateUserVipStatus error: $e');
      }
    }
  }

  /// Khóa hoặc Mở khóa tài khoản người dùng
  Future<void> toggleBlockUser(UserModel user) async {
    final updated = user.copyWith(isBlocked: !user.isBlocked);
    await updateUserByAdmin(updated);
  }

  /// Đổi vai trò (Role) của người dùng
  Future<void> changeUserRole(UserModel user, UserRole newRole) async {
    final updated = user.copyWith(role: newRole);
    await updateUserByAdmin(updated);
  }

  /// Xóa tài khoản người dùng khỏi hệ thống (Cloud Firestore + Local)
  Future<void> deleteUserByAdmin(UserModel user) async {
    _users.removeWhere((u) => u.uid == user.uid);
    _allUserRackets.removeWhere((r) => r.ownerUid == user.uid);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawLocalUsers = prefs.getString(_prefLocalUsersKey);
      if (rawLocalUsers != null && rawLocalUsers.isNotEmpty) {
        final decoded = jsonDecode(rawLocalUsers) as Map<String, dynamic>;
        decoded.remove(user.email.toLowerCase());
        await prefs.setString(_prefLocalUsersKey, jsonEncode(decoded));
      }
      await prefs.remove('gearsports_rackets_${user.uid}');

      if (_isFirebaseReady) {
        final userDoc = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid);
        final racketsSnap = await userDoc.collection('rackets').get();
        for (final doc in racketsSnap.docs) {
          await doc.reference.delete();
        }
        await userDoc.delete().timeout(const Duration(seconds: 5));
      }
    } catch (e) {
      debugPrint('deleteUserByAdmin error: $e');
    }
  }

  /// Kiểm duyệt & Xóa cây vợt vi phạm/sai lệch trong Gara của người dùng
  Future<void> deleteUserRacketByAdmin(
    String ownerUid,
    String racketId,
  ) async {
    _allUserRackets.removeWhere(
      (item) => item.ownerUid == ownerUid && item.racket.id == racketId,
    );
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'gearsports_rackets_$ownerUid';
      final raw = prefs.getString(cacheKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        list.removeWhere((e) => (e as Map<String, dynamic>)['id'] == racketId);
        await prefs.setString(cacheKey, jsonEncode(list));
      }

      if (_isFirebaseReady) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(ownerUid)
            .collection('rackets')
            .doc(racketId)
            .delete()
            .timeout(const Duration(seconds: 5));
      }
    } catch (e) {
      debugPrint('deleteUserRacketByAdmin error: $e');
    }
  }
}
