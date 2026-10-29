import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  static const String _prefCurrentUserKey = 'gearsports_current_user';
  static const String _prefLocalUsersKey = 'gearsports_local_users';

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isFirebaseAvailable = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isGuest => _currentUser?.uid == 'guest_user' || _currentUser?.email == 'guest@gearsports.vn';
  bool get isAuthenticatedUser => isLoggedIn && !isGuest;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isFirebaseAvailable => _isFirebaseAvailable;

  // Khởi tạo rỗng: Không sử dụng tài khoản mẫu hardcode
  static final Map<String, Map<String, dynamic>> _seedAccounts = {};

  AuthProvider() {
    _checkFirebaseStatus();
  }

  void _checkFirebaseStatus() {
    try {
      _isFirebaseAvailable = Firebase.apps.isNotEmpty;
    } catch (_) {
      _isFirebaseAvailable = false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Kiểm tra phiên đăng nhập khi mở app (Dùng ở SplashScreen)
  Future<bool> checkAuthSession() async {
    _checkFirebaseStatus();
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Kiểm tra trên Firebase Auth trước nếu khả dụng
      if (_isFirebaseAvailable) {
        final fbUser = FirebaseAuth.instance.currentUser;
        if (fbUser != null) {
          final profile = await _fetchOrCreateFirestoreProfile(fbUser);
          _currentUser = profile;
          await _saveSessionLocally(profile, prefs);
          notifyListeners();
          return true;
        }
      }

      // 2. Kiểm tra phiên lưu tại SharedPreferences
      final savedJson = prefs.getString(_prefCurrentUserKey);
      if (savedJson != null && savedJson.isNotEmpty) {
        final map = jsonDecode(savedJson) as Map<String, dynamic>;
        _currentUser = UserModel.fromMap(map);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('checkAuthSession error: $e');
    }
    return false;
  }

  /// Đăng nhập bằng Email & Mật khẩu (FR-01)
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final normalizedEmail = email.trim().toLowerCase();

    try {
      _checkFirebaseStatus();

      if (_isFirebaseAvailable) {
        try {
          final credential =
              await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: normalizedEmail,
            password: password,
          );
          if (credential.user != null) {
            final userModel =
                await _fetchOrCreateFirestoreProfile(credential.user!);
            if (userModel.isBlocked) {
              await FirebaseAuth.instance.signOut();
              _errorMessage = 'Tài khoản này đã bị khóa bởi Quản trị viên.';
              _isLoading = false;
              notifyListeners();
              return false;
            }
            _currentUser = userModel;
            final prefs = await SharedPreferences.getInstance();
            await _saveSessionLocally(userModel, prefs);
            _isLoading = false;
            notifyListeners();
            return true;
          }
        } on FirebaseAuthException catch (fbErr) {
          // Nếu là tài khoản mẫu chưa được tạo trên Firebase, tự động khởi tạo lên Firebase
          if (_seedAccounts.containsKey(normalizedEmail) &&
              _seedAccounts[normalizedEmail]!['password'] == password &&
              (fbErr.code == 'user-not-found' ||
                  fbErr.code == 'invalid-credential' ||
                  fbErr.code == 'invalid-login-credentials')) {
            try {
              final seedUser = UserModel.fromMap(
                _seedAccounts[normalizedEmail]!['user'] as Map<String, dynamic>,
              );
              final createdCred =
                  await FirebaseAuth.instance.createUserWithEmailAndPassword(
                email: normalizedEmail,
                password: password,
              );
              final uid = createdCred.user!.uid;
              await createdCred.user!.updateDisplayName(seedUser.fullName);
              final syncedUser = seedUser.copyWith(uid: uid);
              await _saveProfileToFirestore(syncedUser);
              _currentUser = syncedUser;
              final prefs = await SharedPreferences.getInstance();
              await _saveSessionLocally(syncedUser, prefs);
              _isLoading = false;
              notifyListeners();
              return true;
            } catch (_) {
              // Nếu Firebase Console chưa bật Email/Password, fallback xuống Local
            }
          } else if (fbErr.code == 'wrong-password') {
            _errorMessage = 'Mật khẩu không chính xác. Vui lòng thử lại.';
            _isLoading = false;
            notifyListeners();
            return false;
          } else if (fbErr.code == 'invalid-email') {
            _errorMessage = 'Định dạng Email không hợp lệ.';
            _isLoading = false;
            notifyListeners();
            return false;
          } else if (fbErr.code == 'user-disabled') {
            _errorMessage = 'Tài khoản này đã bị khóa.';
            _isLoading = false;
            notifyListeners();
            return false;
          }
          // Với lỗi cấu hình hoặc tài khoản lưu local, kiểm tra tiếp ở Local Storage bên dưới
        }
      }

      // Kiểm tra trong Local Storage & Seed Accounts
      final localUser = await _verifyLocalCredentials(normalizedEmail, password);
      if (localUser != null) {
        if (localUser.isBlocked) {
          _errorMessage = 'Tài khoản này đã bị khóa bởi Quản trị viên.';
          _isLoading = false;
          notifyListeners();
          return false;
        }
        _currentUser = localUser;
        // Đồng bộ lên Firestore nếu Firebase sẵn sàng
        if (_isFirebaseAvailable) {
          await _saveProfileToFirestore(localUser);
        }
        final prefs = await SharedPreferences.getInstance();
        await _saveSessionLocally(localUser, prefs);
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _errorMessage =
          'Email hoặc mật khẩu không đúng. Vui lòng kiểm tra lại hoặc Đăng ký mới.';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Đã xảy ra lỗi khi đăng nhập: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Đăng ký tài khoản mới (FR-01)
  Future<bool> register({
    required String fullName,
    required String phone,
    required String email,
    required String password,
    required UserRole role,
    String? playStyle,
    String? shopName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final normalizedEmail = email.trim().toLowerCase();
    final defaultStyle = role == UserRole.admin
        ? 'Quản trị viên hệ thống Gear Sports 🛡️'
        : role == UserRole.stringer
            ? 'Chuyên gia đan vợt & Phụ kiện cầu lông'
            : (playStyle != null && playStyle.trim().isNotEmpty
                ? playStyle.trim()
                : 'Thiên công 4U • Sẵn sàng ra sân 🏸');

    try {
      _checkFirebaseStatus();
      String uid = 'user_${DateTime.now().millisecondsSinceEpoch}';

      if (_isFirebaseAvailable) {
        try {
          final credential =
              await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: normalizedEmail,
            password: password,
          );
          if (credential.user != null) {
            uid = credential.user!.uid;
            await credential.user!.updateDisplayName(fullName.trim());
          }
        } on FirebaseAuthException catch (fbErr) {
          if (fbErr.code == 'email-already-in-use') {
            _errorMessage =
                'Email này đã được đăng ký. Vui lòng chuyển sang Đăng nhập.';
            _isLoading = false;
            notifyListeners();
            return false;
          } else if (fbErr.code == 'weak-password') {
            _errorMessage = 'Mật khẩu quá yếu (cần ít nhất 6 ký tự).';
            _isLoading = false;
            notifyListeners();
            return false;
          } else if (fbErr.code == 'invalid-email') {
            _errorMessage = 'Địa chỉ Email không hợp lệ.';
            _isLoading = false;
            notifyListeners();
            return false;
          }
          // Nếu lỗi cấu hình trên Console (vd operation-not-allowed), vẫn cho phép tạo và lưu Firestore + Local
        }
      }

      // Kiểm tra trùng email ở Local Storage
      final prefs = await SharedPreferences.getInstance();
      final localUsersMap = _getLocalUsersMap(prefs);
      if (localUsersMap.containsKey(normalizedEmail) &&
          uid.startsWith('user_')) {
        _errorMessage =
            'Email này đã được đăng ký. Vui lòng chuyển sang Đăng nhập.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final newUser = UserModel(
        uid: uid,
        email: normalizedEmail,
        fullName: fullName.trim(),
        phone: phone.trim(),
        role: role,
        playStyle: defaultStyle,
        shopName: role == UserRole.stringer ? (shopName ?? fullName.trim()) : null,
        createdAt: DateTime.now(),
      );

      // Lưu lên Cloud Firestore
      if (_isFirebaseAvailable) {
        await _saveProfileToFirestore(newUser);
      }

      // Lưu vào Local Storage & Session
      localUsersMap[normalizedEmail] = {
        'password': password,
        'user': newUser.toMap(),
      };
      await prefs.setString(_prefLocalUsersKey, jsonEncode(localUsersMap));
      await _saveSessionLocally(newUser, prefs);

      _currentUser = newUser;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Không thể tạo tài khoản: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Đăng nhập bằng Google (SRS 2.2 #1)
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _checkFirebaseStatus();
      UserModel? googleUser;

      if (_isFirebaseAvailable) {
        try {
          final googleProvider = GoogleAuthProvider();
          final credential =
              await FirebaseAuth.instance.signInWithProvider(googleProvider);
          if (credential.user != null) {
            googleUser = await _fetchOrCreateFirestoreProfile(credential.user!);
          }
        } catch (e) {
          debugPrint('Firebase Google Sign-In fallback: $e');
        }
      }

      if (googleUser == null) {
        _errorMessage = 'Không thể xác thực tài khoản Google trên thiết bị này.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (_isFirebaseAvailable) {
        await _saveProfileToFirestore(googleUser);
      }

      final prefs = await SharedPreferences.getInstance();
      await _saveSessionLocally(googleUser, prefs);

      _currentUser = googleUser;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Đăng nhập Google thất bại: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Đăng nhập nhanh với tư cách Khách (Guest Mode)
  Future<void> signInAsGuest() async {
    final guestUser = UserModel(
      uid: 'guest_user',
      email: 'guest@gearsports.vn',
      fullName: 'Khách Tham Quan',
      phone: 'Chưa cập nhật',
      role: UserRole.player,
      playStyle: 'Khách trải nghiệm • Chế độ xem thử 🏸',
      createdAt: DateTime.now(),
    );
    _currentUser = guestUser;
    final prefs = await SharedPreferences.getInstance();
    await _saveSessionLocally(guestUser, prefs);
    notifyListeners();
  }

  /// Cập nhật thông tin hồ sơ người dùng (Role được khóa cố định, không cho phép chỉnh sửa)
  Future<bool> updateProfile({
    required String fullName,
    required String phone,
    required String playStyle,
    String? shopName,
  }) async {
    if (_currentUser == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedUser = _currentUser!.copyWith(
        fullName: fullName.trim(),
        phone: phone.trim(),
        playStyle: playStyle.trim(),
        shopName: shopName ?? _currentUser!.shopName,
      );

      if (_isFirebaseAvailable) {
        try {
          await FirebaseAuth.instance.currentUser
              ?.updateDisplayName(updatedUser.fullName);
        } catch (_) {}
        await _saveProfileToFirestore(updatedUser);
      }

      final prefs = await SharedPreferences.getInstance();
      await _saveSessionLocally(updatedUser, prefs);

      // Cập nhật trong danh sách tài khoản local
      final localUsersMap = _getLocalUsersMap(prefs);
      final emailKey = updatedUser.email.toLowerCase();
      if (localUsersMap.containsKey(emailKey)) {
        final existing = localUsersMap[emailKey] as Map<String, dynamic>;
        localUsersMap[emailKey] = {
          'password': existing['password'] ?? '123456',
          'user': updatedUser.toMap(),
        };
        await prefs.setString(_prefLocalUsersKey, jsonEncode(localUsersMap));
      }

      _currentUser = updatedUser;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Cập nhật hồ sơ thất bại: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Gửi email khôi phục mật khẩu qua Firebase Auth
  Future<bool> resetPassword(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty || !trimmed.contains('@')) {
      _errorMessage = 'Vui lòng nhập địa chỉ Email hợp lệ.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_isFirebaseAvailable) {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: trimmed);
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        _errorMessage = 'Không tìm thấy tài khoản với Email này.';
      } else {
        // Nếu dùng tài khoản demo local, vẫn báo thành công để hỗ trợ demo
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _isLoading = false;
      notifyListeners();
      return true;
    }
  }

  /// Đăng xuất tài khoản (FR-01: Logout)
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_isFirebaseAvailable) {
        await FirebaseAuth.instance.signOut();
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefCurrentUserKey);
    } catch (e) {
      debugPrint('Logout error: $e');
    } finally {
      _currentUser = null;
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    }
  }

  // --- Helpers cho Cloud Firestore & Local Storage ---

  Future<UserModel> _fetchOrCreateFirestoreProfile(User fbUser) async {
    try {
      final docRef =
          FirebaseFirestore.instance.collection('users').doc(fbUser.uid);
      final docSnap =
          await docRef.get().timeout(const Duration(seconds: 5));

      if (docSnap.exists && docSnap.data() != null) {
        return UserModel.fromMap(docSnap.data()!, docId: fbUser.uid);
      }

      // Nếu chưa có document trên Firestore, kiểm tra seed account hoặc khởi tạo mới
      final email = (fbUser.email ?? '').toLowerCase();
      UserModel profile;
      if (_seedAccounts.containsKey(email)) {
        profile = UserModel.fromMap(
          _seedAccounts[email]!['user'] as Map<String, dynamic>,
        ).copyWith(uid: fbUser.uid);
      } else {
        profile = UserModel(
          uid: fbUser.uid,
          email: email,
          fullName: fbUser.displayName?.isNotEmpty == true
              ? fbUser.displayName!
              : 'Người chơi Gear Sports',
          phone: fbUser.phoneNumber ?? '0901234567',
          role: UserRole.player,
          playStyle: 'Thiên công 4U • Sẵn sàng ra sân 🏸',
          createdAt: DateTime.now(),
        );
      }

      await docRef
          .set(profile.toMap(), SetOptions(merge: true))
          .timeout(const Duration(seconds: 4));
      return profile;
    } catch (e) {
      debugPrint('Firestore profile fetch fallback: $e');
      final email = (fbUser.email ?? '').toLowerCase();
      if (_seedAccounts.containsKey(email)) {
        return UserModel.fromMap(
          _seedAccounts[email]!['user'] as Map<String, dynamic>,
        ).copyWith(uid: fbUser.uid);
      }
      return UserModel(
        uid: fbUser.uid,
        email: email,
        fullName: fbUser.displayName ?? 'Người chơi Gear Sports',
        phone: fbUser.phoneNumber ?? '',
        role: UserRole.player,
        createdAt: DateTime.now(),
      );
    }
  }

  Future<void> _saveProfileToFirestore(UserModel user) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(user.toMap(), SetOptions(merge: true))
          .timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('Save profile to Firestore skipped/offline: $e');
    }
  }

  Future<void> _saveSessionLocally(
    UserModel user,
    SharedPreferences prefs,
  ) async {
    await prefs.setString(_prefCurrentUserKey, jsonEncode(user.toMap()));
  }

  Map<String, dynamic> _getLocalUsersMap(SharedPreferences prefs) {
    final raw = prefs.getString(_prefLocalUsersKey);
    final Map<String, dynamic> combined = Map.from(_seedAccounts);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        combined.addAll(decoded);
      } catch (_) {}
    }
    return combined;
  }

  Future<UserModel?> _verifyLocalCredentials(
    String email,
    String password,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final usersMap = _getLocalUsersMap(prefs);
    if (!usersMap.containsKey(email)) return null;

    final entry = usersMap[email] as Map<String, dynamic>;
    if (entry['password'] == password) {
      return UserModel.fromMap(entry['user'] as Map<String, dynamic>);
    }
    return null;
  }
}
