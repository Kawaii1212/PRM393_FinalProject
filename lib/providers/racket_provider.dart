import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/racket_model.dart';
import '../models/tension_log_model.dart';

class RacketProvider with ChangeNotifier {
  List<Racket> _rackets = [];
  String _selectedBrandFilter = 'Tất cả';
  String? _currentUserId;
  bool _isSyncing = false;

  bool get isSyncing => _isSyncing;
  String? get currentUserId => _currentUserId;

  List<Racket> get rackets {
    if (_selectedBrandFilter == 'Tất cả') {
      return List.unmodifiable(_rackets);
    }
    if (_selectedBrandFilter == 'Khác') {
      const mainBrands = [
        'yonex',
        'victor',
        'li-ning',
        'mizuno',
        'felet',
        'kumpoo',
      ];
      return _rackets
          .where((r) => !mainBrands.contains(r.brand.toLowerCase()))
          .toList();
    }
    return _rackets
        .where(
          (r) => r.brand.toLowerCase() == _selectedBrandFilter.toLowerCase(),
        )
        .toList();
  }

  List<Racket> get allRackets => List.unmodifiable(_rackets);

  String get selectedBrandFilter => _selectedBrandFilter;

  void setBrandFilter(String brand) {
    _selectedBrandFilter = brand;
    notifyListeners();
  }

  List<Racket> get racketsNeedingRestring {
    return _rackets.where((r) => r.needsRestring).toList();
  }

  int get totalRacketsCount => _rackets.length;

  Racket? getRacketById(String id) {
    try {
      return _rackets.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  bool get _isFirebaseReady {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  String get _localCacheKey =>
      'gearsports_rackets_${_currentUserId ?? "default"}';

  /// Đồng bộ danh sách vợt theo tài khoản người dùng đang đăng nhập (Firestore: users/{uid}/rackets)
  Future<void> syncForUser(String? uid) async {
    if (_currentUserId == uid && _rackets.isNotEmpty) return;
    _currentUserId = uid;

    if (uid == null || uid.isEmpty) {
      _rackets = [];
      notifyListeners();
      return;
    }

    _isSyncing = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Tải trước từ Local Cache để UI phản hồi tức thì
      final cachedJson = prefs.getString(_localCacheKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final decoded = jsonDecode(cachedJson) as List<dynamic>;
        _rackets = decoded
            .map((e) => Racket.fromMap(Map<String, dynamic>.from(e)))
            .toList();
        notifyListeners();
      } else {
        _rackets = [];
        notifyListeners();
      }

      // 2. Đồng bộ với Cloud Firestore: users/{uid}/rackets
      if (_isFirebaseReady) {
        final colRef = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('rackets');

        final snapshot =
            await colRef.get().timeout(const Duration(seconds: 6));

        _rackets = snapshot.docs
            .map((doc) => Racket.fromMap(doc.data(), docId: doc.id))
            .toList();
        await _saveToLocalCache(prefs);
      }
    } catch (e) {
      debugPrint('RacketProvider syncForUser fallback: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> addRacket(Racket racket) async {
    _rackets.insert(0, racket);
    notifyListeners();
    await _persistRacketUpsert(racket);
  }

  Future<void> updateRacket(Racket updated) async {
    final index = _rackets.indexWhere((r) => r.id == updated.id);
    if (index != -1) {
      _rackets[index] = updated;
      notifyListeners();
      await _persistRacketUpsert(updated);
    }
  }

  Future<void> deleteRacket(String id) async {
    _rackets.removeWhere((r) => r.id == id);
    notifyListeners();
    await _persistRacketDelete(id);
  }

  /// Adds a new tension log and updates racket current string parameters
  Future<void> addTensionLog(String racketId, TensionLog log) async {
    final index = _rackets.indexWhere((r) => r.id == racketId);
    if (index != -1) {
      final racket = _rackets[index];
      final updatedLogs = List<TensionLog>.from(racket.tensionLogs)
        ..insert(0, log);

      final updatedRacket = racket.copyWith(
        currentStringModel: log.stringModel,
        initialTensionLbs: log.tensionLbs,
        strungDate: log.strungDate,
        sessionsPlayed: 0,
        tensionLogs: updatedLogs,
      );
      _rackets[index] = updatedRacket;
      notifyListeners();
      await _persistRacketUpsert(updatedRacket);
    }
  }

  /// Deletes a tension log and recalculates racket current string parameters from remaining logs
  Future<void> deleteTensionLog(String racketId, String logId) async {
    final index = _rackets.indexWhere((r) => r.id == racketId);
    if (index != -1) {
      final racket = _rackets[index];
      final updatedLogs = List<TensionLog>.from(racket.tensionLogs)
        ..removeWhere((l) => l.id == logId);

      Racket updatedRacket;
      if (updatedLogs.isNotEmpty) {
        final latest = updatedLogs.first;
        updatedRacket = racket.copyWith(
          currentStringModel: latest.stringModel,
          initialTensionLbs: latest.tensionLbs,
          strungDate: latest.strungDate,
          tensionLogs: updatedLogs,
        );
      } else {
        updatedRacket = racket.copyWith(
          currentStringModel: 'Chưa đan',
          initialTensionLbs: 0.0,
          tensionLogs: updatedLogs,
        );
      }
      _rackets[index] = updatedRacket;
      notifyListeners();
      await _persistRacketUpsert(updatedRacket);
    }
  }

  /// Increment play sessions (adds friction & fatigue to the strings)
  Future<void> recordPlaySession(String racketId) async {
    final index = _rackets.indexWhere((r) => r.id == racketId);
    if (index != -1) {
      final racket = _rackets[index];
      final updatedRacket = racket.copyWith(
        sessionsPlayed: racket.sessionsPlayed + 1,
      );
      _rackets[index] = updatedRacket;
      notifyListeners();
      await _persistRacketUpsert(updatedRacket);
    }
  }

  // --- Cloud Firestore & Local Storage Persistence ---

  Future<void> _persistRacketUpsert(Racket racket) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _saveToLocalCache(prefs);

      if (_isFirebaseReady &&
          _currentUserId != null &&
          _currentUserId!.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUserId)
            .collection('rackets')
            .doc(racket.id)
            .set(racket.toMap(), SetOptions(merge: true))
            .timeout(const Duration(seconds: 5));
      }
    } catch (e) {
      debugPrint('Persist racket upsert error: $e');
    }
  }

  Future<void> _persistRacketDelete(String racketId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _saveToLocalCache(prefs);

      if (_isFirebaseReady &&
          _currentUserId != null &&
          _currentUserId!.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUserId)
            .collection('rackets')
            .doc(racketId)
            .delete()
            .timeout(const Duration(seconds: 4));
      }
    } catch (e) {
      debugPrint('Persist racket delete error: $e');
    }
  }

  Future<void> _saveToLocalCache(SharedPreferences prefs) async {
    final encoded = jsonEncode(_rackets.map((r) => r.toMap()).toList());
    await prefs.setString(_localCacheKey, encoded);
  }
}
