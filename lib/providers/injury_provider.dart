import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/injury_model.dart';
import '../data/injury_knowledge_base.dart';

class InjuryProvider with ChangeNotifier {
  List<InjuryRecord> _records = [];
  InjuryDiagnosisResult? _latestResult;
  String? _currentUserId;
  bool _isSyncing = false;

  List<InjuryRecord> get records => List.unmodifiable(_records);
  InjuryDiagnosisResult? get latestResult => _latestResult;
  bool get isSyncing => _isSyncing;
  String? get currentUserId => _currentUserId;

  /// Chấn thương đang điều trị/chưa bình phục gần nhất của Player
  InjuryRecord? get activeInjury {
    try {
      return _records.firstWhere(
        (r) => r.status != RecoveryStatus.fullyRecovered,
      );
    } catch (_) {
      return null;
    }
  }

  bool get hasActiveInjury => activeInjury != null;

  bool get _isFirebaseReady {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  String get _localCacheKey =>
      'gearsports_injuries_${_currentUserId ?? "default"}';

  /// Đồng bộ danh sách chấn thương của người dùng
  Future<void> syncForUser(String? uid) async {
    if (_currentUserId == uid && _records.isNotEmpty) return;
    _currentUserId = uid;

    if (uid == null || uid.isEmpty) {
      _records = [];
      _latestResult = null;
      notifyListeners();
      return;
    }

    _isSyncing = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Tải từ Local Cache trước
      final cachedJson = prefs.getString(_localCacheKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final decoded = jsonDecode(cachedJson) as List<dynamic>;
        _records = decoded
            .map((e) => InjuryRecord.fromMap(Map<String, dynamic>.from(e)))
            .toList();
        notifyListeners();
      } else {
        _records = [];
        notifyListeners();
      }

      // 2. Đồng bộ từ Cloud Firestore: users/{uid}/injuries
      if (_isFirebaseReady) {
        final colRef = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('injuries');

        final snapshot =
            await colRef.orderBy('createdAt', descending: true).get().timeout(
                  const Duration(seconds: 6),
                );

        _records = snapshot.docs
            .map((doc) => InjuryRecord.fromMap(doc.data(), docId: doc.id))
            .toList();

        await _saveToLocalCache(prefs);
      }
    } catch (e) {
      debugPrint('InjuryProvider syncForUser fallback: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Thực hiện chuẩn đoán và cập nhật kết quả mới nhất
  InjuryDiagnosisResult runDiagnosis(InjuryAssessmentInput input) {
    final result = InjuryKnowledgeBase.diagnose(input);
    _latestResult = result;
    notifyListeners();
    return result;
  }

  /// Lưu kết quả chuẩn đoán vào lịch sử chấn thương của Player
  Future<InjuryRecord> saveDiagnosisRecord({
    required InjuryDiagnosisResult result,
    required InjuryAssessmentInput input,
    String notes = '',
  }) async {
    final newId = 'injury_${DateTime.now().millisecondsSinceEpoch}';
    final record = InjuryRecord(
      id: newId,
      userId: _currentUserId ?? 'local_user',
      createdAt: DateTime.now(),
      bodyPart: input.bodyPart,
      painScore: input.painScore,
      injuryTypeId: result.injuryType.id,
      injuryNameVi: result.injuryType.nameVi,
      medicalName: result.injuryType.medicalName,
      severity: result.severity,
      status: RecoveryStatus.activePain,
      relatedRacketId: input.relatedRacketId,
      relatedRacketName: input.relatedRacketName,
      gearAnalysis: result.gearAnalysisSummary,
      notes: notes,
    );

    _records.insert(0, record);
    notifyListeners();

    await _persistRecordUpsert(record);
    return record;
  }

  /// Cập nhật tiến trình hồi phục của chấn thương
  Future<void> updateRecordStatus(String recordId, RecoveryStatus newStatus) async {
    final index = _records.indexWhere((r) => r.id == recordId);
    if (index != -1) {
      final updated = _records[index].copyWith(status: newStatus);
      _records[index] = updated;
      notifyListeners();
      await _persistRecordUpsert(updated);
    }
  }

  /// Xóa bản ghi chấn thương
  Future<void> deleteRecord(String recordId) async {
    _records.removeWhere((r) => r.id == recordId);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await _saveToLocalCache(prefs);

      if (_isFirebaseReady && _currentUserId != null && _currentUserId!.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUserId)
            .collection('injuries')
            .doc(recordId)
            .delete();
      }
    } catch (e) {
      debugPrint('InjuryProvider deleteRecord error: $e');
    }
  }

  Future<void> _persistRecordUpsert(InjuryRecord record) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _saveToLocalCache(prefs);

      if (_isFirebaseReady && _currentUserId != null && _currentUserId!.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUserId)
            .collection('injuries')
            .doc(record.id)
            .set(record.toMap(), SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('InjuryProvider persist error: $e');
    }
  }

  Future<void> _saveToLocalCache(SharedPreferences prefs) async {
    final listMap = _records.map((r) => r.toMap()).toList();
    await prefs.setString(_localCacheKey, jsonEncode(listMap));
  }
}
