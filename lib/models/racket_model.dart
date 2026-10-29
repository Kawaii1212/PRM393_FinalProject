import 'tension_log_model.dart';

class Racket {
  final String id;
  final String brand;
  final String modelName;
  final String editionGen;
  final String colorway;
  final String weightU; // 3U, 4U, 5U, 6U
  final String gripG; // G4, G5, G6
  final String shaftStiffness; // Rất cứng, Cứng, Trung bình, Dẻo
  final int balancePointMm; // e.g. 305mm
  final double swingWeight; // e.g. 88.0 kg.cm²
  final String frameProfile; // Khung hộp (Box), Khung vát (Aero), Lai (Aero-Box)
  final double maxTensionLbs; // e.g. 28.0 lbs

  // Current String status
  final String currentStringModel;
  final double initialTensionLbs;
  final DateTime? strungDate;
  final int sessionsPlayed;
  final String gripCondition;
  final String? imageUrl;
  final List<TensionLog> tensionLogs;

  Racket({
    required this.id,
    required this.brand,
    required this.modelName,
    this.editionGen = 'Bản gốc',
    this.colorway = 'Tiêu chuẩn',
    required this.weightU,
    this.gripG = 'G5',
    required this.shaftStiffness,
    required this.balancePointMm,
    this.swingWeight = 85.0,
    this.frameProfile = 'Lai (Aero-Box)',
    required this.maxTensionLbs,
    this.currentStringModel = 'Chưa đan',
    this.initialTensionLbs = 0.0,
    this.strungDate,
    this.sessionsPlayed = 0,
    this.gripCondition = 'Bọc quấn cán mới',
    this.imageUrl,
    List<TensionLog>? tensionLogs,
  }) : tensionLogs = tensionLogs ?? [];

  /// Number of days since last stringing
  int get daysSinceStrung {
    if (strungDate == null || tensionLogs.isEmpty) return 0;
    return DateTime.now().difference(strungDate!).inDays;
  }

  /// Kiểm tra vợt đã có nhật ký đan cước chưa
  bool get hasTensionLog => tensionLogs.isNotEmpty && initialTensionLbs > 0;

  /// Calculates tension loss percentage based on days and play sessions.
  /// Công thức chuẩn: 0.2% cho mỗi ngày trôi qua và 0.7% cho mỗi buổi đánh cầu.
  double get tensionLossPercent {
    if (!hasTensionLog || strungDate == null) return 0.0;
    final days = daysSinceStrung;
    final loss = (days * 0.2) + (sessionsPlayed * 0.7);
    return double.parse(loss.clamp(0.0, 100.0).toStringAsFixed(1));
  }

  /// Estimated current real tension
  double get estimatedCurrentTension {
    if (!hasTensionLog) return 0.0;
    final current = initialTensionLbs * (1.0 - (tensionLossPercent / 100.0));
    return double.parse(current.clamp(0.0, initialTensionLbs).toStringAsFixed(1));
  }

  /// Check if the string needs to be replaced (over 45 days, or >20% tension loss)
  bool get needsRestring {
    if (!hasTensionLog) return false;
    return tensionLossPercent >= 20.0 || daysSinceStrung >= 45;
  }

  /// Check if a requested tension exceeds racket maximum tolerance (risk of frame warping/crack)
  bool isTensionExceeded(double requestedTension) {
    return requestedTension > maxTensionLbs;
  }

  /// Racket classification based on balance point
  String get playStyle {
    if (balancePointMm > 295) {
      return 'Thiên Công (Head-Heavy)';
    } else if (balancePointMm < 290) {
      return 'Thiên Thủ / Phản Tạt (Head-Light)';
    } else {
      return 'Công Thủ Toàn Diện (Even-Balance)';
    }
  }

  Racket copyWith({
    String? id,
    String? brand,
    String? modelName,
    String? editionGen,
    String? colorway,
    String? weightU,
    String? gripG,
    String? shaftStiffness,
    int? balancePointMm,
    double? swingWeight,
    String? frameProfile,
    double? maxTensionLbs,
    String? currentStringModel,
    double? initialTensionLbs,
    DateTime? strungDate,
    int? sessionsPlayed,
    String? gripCondition,
    String? imageUrl,
    List<TensionLog>? tensionLogs,
  }) {
    return Racket(
      id: id ?? this.id,
      brand: brand ?? this.brand,
      modelName: modelName ?? this.modelName,
      editionGen: editionGen ?? this.editionGen,
      colorway: colorway ?? this.colorway,
      weightU: weightU ?? this.weightU,
      gripG: gripG ?? this.gripG,
      shaftStiffness: shaftStiffness ?? this.shaftStiffness,
      balancePointMm: balancePointMm ?? this.balancePointMm,
      swingWeight: swingWeight ?? this.swingWeight,
      frameProfile: frameProfile ?? this.frameProfile,
      maxTensionLbs: maxTensionLbs ?? this.maxTensionLbs,
      currentStringModel: currentStringModel ?? this.currentStringModel,
      initialTensionLbs: initialTensionLbs ?? this.initialTensionLbs,
      strungDate: strungDate ?? this.strungDate,
      sessionsPlayed: sessionsPlayed ?? this.sessionsPlayed,
      gripCondition: gripCondition ?? this.gripCondition,
      imageUrl: imageUrl ?? this.imageUrl,
      tensionLogs: tensionLogs ?? this.tensionLogs,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'brand': brand,
      'modelName': modelName,
      'editionGen': editionGen,
      'colorway': colorway,
      'weightU': weightU,
      'gripG': gripG,
      'shaftStiffness': shaftStiffness,
      'balancePointMm': balancePointMm,
      'swingWeight': swingWeight,
      'frameProfile': frameProfile,
      'maxTensionLbs': maxTensionLbs,
      'currentStringModel': currentStringModel,
      'initialTensionLbs': initialTensionLbs,
      'strungDate': strungDate?.toIso8601String(),
      'sessionsPlayed': sessionsPlayed,
      'gripCondition': gripCondition,
      'imageUrl': imageUrl,
      'tensionLogs': tensionLogs.map((log) => log.toMap()).toList(),
    };
  }

  factory Racket.fromMap(Map<String, dynamic> map, {String? docId}) {
    final logsRaw = map['tensionLogs'] as List<dynamic>? ?? [];
    return Racket(
      id: map['id']?.toString() ?? docId ?? '',
      brand: map['brand']?.toString() ?? 'Yonex',
      modelName: map['modelName']?.toString() ?? '',
      editionGen: map['editionGen']?.toString() ?? 'Bản gốc',
      colorway: map['colorway']?.toString() ?? 'Tiêu chuẩn',
      weightU: map['weightU']?.toString() ?? '4U (80-84g)',
      gripG: map['gripG']?.toString() ?? 'G5',
      shaftStiffness: map['shaftStiffness']?.toString() ?? 'Cứng (Stiff)',
      balancePointMm: (map['balancePointMm'] as num?)?.toInt() ?? 298,
      swingWeight: (map['swingWeight'] as num?)?.toDouble() ?? 85.0,
      frameProfile: map['frameProfile']?.toString() ?? 'Lai (Aero-Box)',
      maxTensionLbs: (map['maxTensionLbs'] as num?)?.toDouble() ?? 28.0,
      currentStringModel: map['currentStringModel']?.toString() ?? 'Chưa đan',
      initialTensionLbs:
          (map['initialTensionLbs'] as num?)?.toDouble() ?? 0.0,
      strungDate: map['strungDate'] != null
          ? DateTime.tryParse(map['strungDate'].toString())
          : null,
      sessionsPlayed: (map['sessionsPlayed'] as num?)?.toInt() ?? 0,
      gripCondition: map['gripCondition']?.toString() ?? 'Bọc quấn cán mới',
      imageUrl: map['imageUrl']?.toString(),
      tensionLogs: logsRaw
          .map((item) => TensionLog.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}
