import 'package:flutter/foundation.dart';
import '../models/racket_model.dart';
import '../models/tension_log_model.dart';
import '../data/mock_data.dart';

class RacketProvider with ChangeNotifier {
  final List<Racket> _rackets = List.from(MockData.initialRackets);
  String _selectedBrandFilter = 'Tất cả';

  List<Racket> get rackets {
    if (_selectedBrandFilter == 'Tất cả') {
      return List.unmodifiable(_rackets);
    }
    return _rackets.where((r) => r.brand.toLowerCase() == _selectedBrandFilter.toLowerCase()).toList();
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

  void addRacket(Racket racket) {
    _rackets.insert(0, racket);
    notifyListeners();
  }

  void updateRacket(Racket updated) {
    final index = _rackets.indexWhere((r) => r.id == updated.id);
    if (index != -1) {
      _rackets[index] = updated;
      notifyListeners();
    }
  }

  void deleteRacket(String id) {
    _rackets.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  /// Adds a new tension log and updates racket current string parameters
  void addTensionLog(String racketId, TensionLog log) {
    final index = _rackets.indexWhere((r) => r.id == racketId);
    if (index != -1) {
      final racket = _rackets[index];
      final updatedLogs = List<TensionLog>.from(racket.tensionLogs)..insert(0, log);

      _rackets[index] = racket.copyWith(
        currentStringModel: log.stringModel,
        initialTensionLbs: log.tensionLbs,
        strungDate: log.strungDate,
        sessionsPlayed: 0,
        tensionLogs: updatedLogs,
      );
      notifyListeners();
    }
  }

  /// Increment play sessions (adds friction & fatigue to the strings)
  void recordPlaySession(String racketId) {
    final index = _rackets.indexWhere((r) => r.id == racketId);
    if (index != -1) {
      final racket = _rackets[index];
      _rackets[index] = racket.copyWith(
        sessionsPlayed: racket.sessionsPlayed + 1,
      );
      notifyListeners();
    }
  }
}
