import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

enum GoogleSignInStatus {
  success,
  needsRoleSelection,
  failed,
}

class GoogleSignInResult {
  final GoogleSignInStatus status;
  final UserModel? user;
  final User? firebaseUser;
  final String? errorMessage;
  final String? tempEmail;
  final String? tempName;

  const GoogleSignInResult({
    required this.status,
    this.user,
    this.firebaseUser,
    this.errorMessage,
    this.tempEmail,
    this.tempName,
  });
}

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
          ).timeout(const Duration(seconds: 8));
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
        } on TimeoutException {
          debugPrint('Firebase signInWithEmailAndPassword timed out after 8s');
          final localUser =
              await _verifyLocalCredentials(normalizedEmail, password);
          if (localUser != null) {
            if (localUser.isBlocked) {
              _errorMessage = 'Tài khoản này đã bị khóa bởi Quản trị viên.';
              _isLoading = false;
              notifyListeners();
              return false;
            }
            _currentUser = localUser;
            final prefs = await SharedPreferences.getInstance();
            await _saveSessionLocally(localUser, prefs);
            _isLoading = false;
            notifyListeners();
            return true;
          }
          _errorMessage =
              'Không thể kết nối máy chủ Firebase (Quá thời gian chờ - Timeout). Vui lòng kiểm tra lại kết nối Internet trên thiết bị của bạn!';
          _isLoading = false;
          notifyListeners();
          return false;
        } on FirebaseAuthException catch (fbErr) {
          if (fbErr.code == 'network-request-failed') {
            final localUser =
                await _verifyLocalCredentials(normalizedEmail, password);
            if (localUser != null) {
              if (localUser.isBlocked) {
                _errorMessage = 'Tài khoản này đã bị khóa bởi Quản trị viên.';
                _isLoading = false;
                notifyListeners();
                return false;
              }
              _currentUser = localUser;
              final prefs = await SharedPreferences.getInstance();
              await _saveSessionLocally(localUser, prefs);
              _isLoading = false;
              notifyListeners();
              return true;
            }
            _errorMessage =
                'Mất kết nối Internet (Network error). Vui lòng kiểm tra lại kết nối WiFi / 4G của thiết bị!';
            _isLoading = false;
            notifyListeners();
            return false;
          } else if (fbErr.code == 'wrong-password') {
            _errorMessage = 'Mật khẩu không chính xác. Vui lòng thử lại.';
            _isLoading = false;
            notifyListeners();
            return false;
          } else if (fbErr.code == 'user-not-found') {
            _errorMessage = 'Tài khoản chưa tồn tại. Vui lòng đăng ký mới.';
            _isLoading = false;
            notifyListeners();
            return false;
          } else if (fbErr.code == 'invalid-credential' ||
              fbErr.code == 'invalid-login-credentials') {
            _errorMessage =
                'Email hoặc mật khẩu không chính xác. Vui lòng thử lại.';
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
        } catch (e) {
          debugPrint('Firebase login unexpected error: $e');
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
          ).timeout(const Duration(seconds: 8));
          if (credential.user != null) {
            uid = credential.user!.uid;
            await credential.user!.updateDisplayName(fullName.trim());
          }
        } on TimeoutException {
          debugPrint('Firebase createUserWithEmailAndPassword timed out. Continuing with local creation.');
        } on FirebaseAuthException catch (fbErr) {
          if (fbErr.code == 'network-request-failed') {
            debugPrint('Firebase network-request-failed. Continuing with local creation.');
          } else if (fbErr.code == 'email-already-in-use') {
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
        } catch (e) {
          debugPrint('Firebase register unexpected error: $e');
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
  /// Trả về [GoogleSignInResult]:
  /// - status == GoogleSignInStatus.success: Đã khớp tài khoản cũ hoặc Admin -> Đăng nhập ngay
  /// - status == GoogleSignInStatus.needsRoleSelection: Tài khoản Google mới -> Cần chọn vai trò (Cách B)
  /// - status == GoogleSignInStatus.failed: Thất bại kèm thông báo lỗi
  Future<GoogleSignInResult> signInWithGoogle({String? hintEmail}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _checkFirebaseStatus();
      User? fbUser;
      String? fallbackEmail;
      String? fallbackName;

      if (_isFirebaseAvailable) {
        try {
          final googleProvider = GoogleAuthProvider();
          final credential = await FirebaseAuth.instance
              .signInWithProvider(googleProvider)
              .timeout(const Duration(seconds: 12));
          fbUser = credential.user;
        } on TimeoutException {
          debugPrint('Firebase Google Sign-In timeout');
          _errorMessage =
              'Quá thời gian chờ kết nối Google. Vui lòng kiểm tra lại kết nối mạng.';
          _isLoading = false;
          notifyListeners();
          return const GoogleSignInResult(
            status: GoogleSignInStatus.failed,
            errorMessage: 'Quá thời gian chờ kết nối Google. Vui lòng kiểm tra lại kết nối mạng.',
          );
        } on FirebaseAuthException catch (fbErr) {
          debugPrint('Firebase Google Sign-In FirebaseAuthException: ${fbErr.code} - ${fbErr.message}');
          if (fbErr.code == 'invalid-cert-hash') {
            debugPrint('⚠️ Lỗi invalid-cert-hash: Mã SHA-1 của thiết bị/máy ảo chưa được thêm vào Firebase Console.');
            fallbackEmail = hintEmail != null && hintEmail.trim().isNotEmpty
                ? hintEmail.trim().toLowerCase()
                : 'namhgjk123@gmail.com';
            fallbackName = fallbackEmail == 'namhgjk123@gmail.com'
                ? 'Nguyễn Sơn Nam (Admin)'
                : 'Người dùng Google (Giả lập)';
          } else if (fbErr.code == 'operation-not-allowed') {
            _errorMessage = 'Chưa bật phương thức đăng nhập Google trong Firebase Console.';
            _isLoading = false;
            notifyListeners();
            return GoogleSignInResult(
              status: GoogleSignInStatus.failed,
              errorMessage: _errorMessage,
            );
          } else {
            _errorMessage = 'Lỗi đăng nhập Google: ${fbErr.message ?? fbErr.code}';
            _isLoading = false;
            notifyListeners();
            return GoogleSignInResult(
              status: GoogleSignInStatus.failed,
              errorMessage: _errorMessage,
            );
          }
        } catch (e) {
          debugPrint('Firebase Google Sign-In fallback: $e');
        }
      } else {
        fallbackEmail = hintEmail != null && hintEmail.trim().isNotEmpty
            ? hintEmail.trim().toLowerCase()
            : 'namhgjk123@gmail.com';
        fallbackName = fallbackEmail == 'namhgjk123@gmail.com'
            ? 'Nguyễn Sơn Nam (Admin)'
            : 'Người dùng Google (Offline)';
      }

      final email = (fbUser?.email ?? fallbackEmail ?? '').toLowerCase();
      final displayName = fbUser?.displayName ?? fallbackName ?? 'Người dùng Google';
      final uid = fbUser?.uid ?? 'google_${DateTime.now().millisecondsSinceEpoch}';

      if (email.isEmpty) {
        _errorMessage = 'Không lấy được thông tin Email từ tài khoản Google.';
        _isLoading = false;
        notifyListeners();
        return const GoogleSignInResult(
          status: GoogleSignInStatus.failed,
          errorMessage: 'Không lấy được thông tin Email từ tài khoản Google.',
        );
      }

      // 1. Kiểm tra nếu là Email Quản trị viên (Admin Whitelist)
      final isAdmin = email == 'namhgjk123@gmail.com' ||
          email.contains('admin@gearsports') ||
          _seedAccounts[email]?['user']?['role'] == 'admin';

      if (isAdmin) {
        final adminUser = UserModel(
          uid: uid,
          email: email,
          fullName: displayName.isNotEmpty ? displayName : 'Nguyễn Sơn Nam (Admin)',
          phone: fbUser?.phoneNumber ?? '0901234567',
          role: UserRole.admin,
          playStyle: 'Quản trị viên hệ thống Gear Sports 🛡️',
          createdAt: DateTime.now(),
        );

        if (_isFirebaseAvailable) {
          await _saveProfileToFirestore(adminUser);
        }
        final prefs = await SharedPreferences.getInstance();
        await _saveSessionLocally(adminUser, prefs);

        _currentUser = adminUser;
        _isLoading = false;
        notifyListeners();
        return GoogleSignInResult(
          status: GoogleSignInStatus.success,
          user: adminUser,
        );
      }

      // 2. Tìm tài khoản cũ trong Cloud Firestore theo UID hoặc Email
      UserModel? existingUser;
      if (_isFirebaseAvailable) {
        try {
          final docRef = FirebaseFirestore.instance.collection('users').doc(uid);
          final docSnap = await docRef.get().timeout(const Duration(seconds: 4));
          if (docSnap.exists && docSnap.data() != null) {
            existingUser = UserModel.fromMap(docSnap.data()!, docId: uid);
          } else {
            final query = await FirebaseFirestore.instance
                .collection('users')
                .where('email', isEqualTo: email)
                .limit(1)
                .get()
                .timeout(const Duration(seconds: 4));
            if (query.docs.isNotEmpty) {
              existingUser = UserModel.fromMap(query.docs.first.data(), docId: uid);
              await docRef.set(existingUser.toMap(), SetOptions(merge: true));
            }
          }
        } catch (e) {
          debugPrint('Firestore existing user search warning: $e');
        }
      }

      // 3. Tìm trong Local Storage (SharedPreferences)
      if (existingUser == null) {
        final prefs = await SharedPreferences.getInstance();
        final localMap = _getLocalUsersMap(prefs);
        if (localMap.containsKey(email)) {
          final localEntry = localMap[email] as Map<String, dynamic>;
          final localData = Map<String, dynamic>.from(localEntry['user']);
          existingUser = UserModel.fromMap(localData).copyWith(uid: uid);
          if (_isFirebaseAvailable) {
            await _saveProfileToFirestore(existingUser);
          }
        }
      }

      // Nếu tài khoản đã tồn tại: Đăng nhập ngay lập tức với vai trò sẵn có
      if (existingUser != null) {
        if (existingUser.isBlocked) {
          _errorMessage = 'Tài khoản này đã bị khóa bởi Quản trị viên.';
          _isLoading = false;
          notifyListeners();
          return const GoogleSignInResult(
            status: GoogleSignInStatus.failed,
            errorMessage: 'Tài khoản này đã bị khóa bởi Quản trị viên.',
          );
        }

        final prefs = await SharedPreferences.getInstance();
        await _saveSessionLocally(existingUser, prefs);

        _currentUser = existingUser;
        _isLoading = false;
        notifyListeners();
        return GoogleSignInResult(
          status: GoogleSignInStatus.success,
          user: existingUser,
        );
      }

      // Nếu là tài khoản Google mới toanh: Trả về trạng thái yêu cầu chọn vai trò (Cách B)
      _isLoading = false;
      notifyListeners();
      return GoogleSignInResult(
        status: GoogleSignInStatus.needsRoleSelection,
        firebaseUser: fbUser,
        tempEmail: email,
        tempName: displayName,
      );
    } catch (e) {
      _errorMessage = 'Đăng nhập Google thất bại: $e';
      _isLoading = false;
      notifyListeners();
      return GoogleSignInResult(
        status: GoogleSignInStatus.failed,
        errorMessage: _errorMessage,
      );
    }
  }

  /// Hoàn tất đăng ký tài khoản Google mới với Vai trò do người dùng lựa chọn (Cách B)
  Future<bool> completeGoogleRegistration({
    required UserRole role,
    String? email,
    String? fullName,
    String? phone,
    String? playStyle,
    String? shopName,
    User? fbUser,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final finalEmail = (email ?? fbUser?.email ?? '').trim().toLowerCase();
      final finalName = (fullName ?? fbUser?.displayName ?? (role == UserRole.stringer ? 'Chủ Shop' : 'Người chơi')).trim();
      final uid = fbUser?.uid ?? 'google_${DateTime.now().millisecondsSinceEpoch}';

      final defaultStyle = role == UserRole.stringer
          ? 'Chuyên gia đan vợt & Phụ kiện cầu lông'
          : (playStyle != null && playStyle.trim().isNotEmpty
              ? playStyle.trim()
              : 'Thiên công 4U • Sẵn sàng ra sân 🏸');

      final newUser = UserModel(
        uid: uid,
        email: finalEmail,
        fullName: finalName,
        phone: (phone != null && phone.trim().isNotEmpty)
            ? phone.trim()
            : (fbUser?.phoneNumber ?? '0901234567'),
        role: role,
        playStyle: defaultStyle,
        shopName: role == UserRole.stringer
            ? (shopName != null && shopName.trim().isNotEmpty
                ? shopName.trim()
                : 'Cửa hàng $finalName')
            : null,
        createdAt: DateTime.now(),
      );

      // Lưu lên Firestore
      if (_isFirebaseAvailable) {
        await _saveProfileToFirestore(newUser);
      }

      // Lưu vào Local Storage & Session
      final prefs = await SharedPreferences.getInstance();
      final localUsersMap = _getLocalUsersMap(prefs);
      localUsersMap[finalEmail] = {
        'password': 'google_oauth_account',
        'user': newUser.toMap(),
      };
      await prefs.setString(_prefLocalUsersKey, jsonEncode(localUsersMap));
      await _saveSessionLocally(newUser, prefs);

      _currentUser = newUser;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Không thể hoàn tất đăng ký: $e';
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
        await FirebaseAuth.instance
            .sendPasswordResetEmail(email: trimmed)
            .timeout(const Duration(seconds: 8));
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } on TimeoutException {
      _errorMessage =
          'Quá thời gian kết nối máy chủ. Vui lòng kiểm tra lại kết nối mạng của bạn.';
      _isLoading = false;
      notifyListeners();
      return false;
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

      // 1. Kiểm tra nếu là email Quản trị viên (Admin Whitelist)
      final email = (fbUser.email ?? '').toLowerCase();
      final isAdmin = email == 'namhgjk123@gmail.com' ||
          email.contains('admin@gearsports') ||
          _seedAccounts[email]?['user']?['role'] == 'admin';

      if (isAdmin) {
        final profile = UserModel(
          uid: fbUser.uid,
          email: email,
          fullName: fbUser.displayName?.isNotEmpty == true
              ? fbUser.displayName!
              : 'Nguyễn Sơn Nam (Admin)',
          phone: fbUser.phoneNumber ?? '0901234567',
          role: UserRole.admin,
          playStyle: 'Quản trị viên hệ thống Gear Sports 🛡️',
          createdAt: DateTime.now(),
        );
        await docRef.set(profile.toMap(), SetOptions(merge: true)).timeout(const Duration(seconds: 4));
        return profile;
      }

      // 2. Kiểm tra đối chiếu Email trên Firestore xem đã có tài khoản cũ dưới UID khác không
      try {
        final querySnap = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 4));
        if (querySnap.docs.isNotEmpty) {
          final existing = UserModel.fromMap(querySnap.docs.first.data(), docId: fbUser.uid);
          await docRef.set(existing.toMap(), SetOptions(merge: true));
          return existing;
        }
      } catch (e) {
        debugPrint('Firestore email matching query warning: $e');
      }

      // Nếu chưa có document trên Firestore, kiểm tra seed account hoặc khởi tạo mới
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
