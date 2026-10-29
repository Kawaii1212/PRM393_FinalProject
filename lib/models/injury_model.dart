import 'package:flutter/material.dart';

/// Các vùng cơ thể thường gặp chấn thương trong cầu lông
enum BodyPart {
  elbow,
  wrist,
  shoulder,
  knee,
  ankle,
  back;

  String get label {
    switch (this) {
      case BodyPart.elbow:
        return 'Khuỷu tay (Elbow)';
      case BodyPart.wrist:
        return 'Cổ tay (Wrist)';
      case BodyPart.shoulder:
        return 'Khớp vai (Shoulder)';
      case BodyPart.knee:
        return 'Đầu gối (Knee)';
      case BodyPart.ankle:
        return 'Cổ chân / Gót (Ankle)';
      case BodyPart.back:
        return 'Thắt lưng (Lower Back)';
    }
  }

  String get shortLabel {
    switch (this) {
      case BodyPart.elbow:
        return 'Khuỷu tay';
      case BodyPart.wrist:
        return 'Cổ tay';
      case BodyPart.shoulder:
        return 'Khớp vai';
      case BodyPart.knee:
        return 'Đầu gối';
      case BodyPart.ankle:
        return 'Cổ chân & Gót';
      case BodyPart.back:
        return 'Thắt lưng';
    }
  }

  IconData get icon {
    switch (this) {
      case BodyPart.elbow:
        return Icons.sports_tennis_rounded;
      case BodyPart.wrist:
        return Icons.front_hand_rounded;
      case BodyPart.shoulder:
        return Icons.accessibility_new_rounded;
      case BodyPart.knee:
        return Icons.airline_seat_legroom_extra_rounded;
      case BodyPart.ankle:
        return Icons.directions_walk_rounded;
      case BodyPart.back:
        return Icons.fitness_center_rounded;
    }
  }

  String get commonInjuriesHint {
    switch (this) {
      case BodyPart.elbow:
        return 'Tennis Elbow (ngoài), Golfer\'s Elbow (trong), rung chấn cước';
      case BodyPart.wrist:
        return 'Viêm bao gân De Quervain, bong gân cổ tay, sụn TFCC';
      case BodyPart.shoulder:
        return 'Viêm gân chóp xoay, kẹt mỏm cùng vai do smash quá tầm';
      case BodyPart.knee:
        return 'Viêm gân bánh chè (Jumper\'s Knee), đau mặt trước gối khi lunge';
      case BodyPart.ankle:
        return 'Lật sơ mi (bong gân mắt cá), viêm gân gót Achilles, gan chân';
      case BodyPart.back:
        return 'Căng cơ thắt lưng, quá tải do với cầu muộn phía sau';
    }
  }

  static BodyPart fromString(String? val) {
    return BodyPart.values.firstWhere(
      (e) => e.name == val,
      orElse: () => BodyPart.elbow,
    );
  }
}

/// Mức độ nghiêm trọng của chấn thương
enum PainSeverity {
  mild,
  moderate,
  severe;

  String get label {
    switch (this) {
      case PainSeverity.mild:
        return 'Mức độ Nhẹ (Cấp 1)';
      case PainSeverity.moderate:
        return 'Mức độ Vừa (Cấp 2)';
      case PainSeverity.severe:
        return 'Nguy cơ Cao (Cấp 3 - Cảnh báo đỏ)';
    }
  }

  Color get color {
    switch (this) {
      case PainSeverity.mild:
        return const Color(0xFF00E676); // Green
      case PainSeverity.moderate:
        return const Color(0xFFFF9100); // Amber
      case PainSeverity.severe:
        return const Color(0xFFFF5252); // Red
    }
  }

  String get actionSummary {
    switch (this) {
      case PainSeverity.mild:
        return 'Nghỉ ngơi 2-3 ngày, chườm lạnh, có thể tự phục hồi tại nhà.';
      case PainSeverity.moderate:
        return 'Tạm ngưng chơi 1-3 tuần, áp dụng R.I.C.E và tập vật lý trị liệu phục hồi.';
      case PainSeverity.severe:
        return 'Tuyệt đối KHÔNG tiếp tục chơi. Cần đến cơ sở y tế hoặc bác sĩ thể thao khám ngay!';
    }
  }

  static PainSeverity fromScore(int score) {
    if (score <= 3) return PainSeverity.mild;
    if (score <= 6) return PainSeverity.moderate;
    return PainSeverity.severe;
  }

  static PainSeverity fromString(String? val) {
    return PainSeverity.values.firstWhere(
      (e) => e.name == val,
      orElse: () => PainSeverity.mild,
    );
  }
}

/// Trạng thái phục hồi chấn thương
enum RecoveryStatus {
  activePain,
  recovering,
  fullyRecovered;

  String get label {
    switch (this) {
      case RecoveryStatus.activePain:
        return 'Đang đau / Cần nghỉ';
      case RecoveryStatus.recovering:
        return 'Đang hồi phục';
      case RecoveryStatus.fullyRecovered:
        return 'Đã bình phục';
    }
  }

  Color get color {
    switch (this) {
      case RecoveryStatus.activePain:
        return const Color(0xFFFF5252);
      case RecoveryStatus.recovering:
        return const Color(0xFFFF9100);
      case RecoveryStatus.fullyRecovered:
        return const Color(0xFF00E676);
    }
  }

  static RecoveryStatus fromString(String? val) {
    return RecoveryStatus.values.firstWhere(
      (e) => e.name == val,
      orElse: () => RecoveryStatus.activePain,
    );
  }
}

/// Bài tập vật lý trị liệu & phục hồi chức năng
class RehabExercise {
  final String id;
  final String name;
  final String targetPart;
  final String durationOrReps;
  final String instructions;
  final String cautionNote;

  const RehabExercise({
    required this.id,
    required this.name,
    required this.targetPart,
    required this.durationOrReps,
    required this.instructions,
    required this.cautionNote,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'targetPart': targetPart,
    'durationOrReps': durationOrReps,
    'instructions': instructions,
    'cautionNote': cautionNote,
  };

  factory RehabExercise.fromMap(Map<String, dynamic> map) {
    return RehabExercise(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      targetPart: map['targetPart'] ?? '',
      durationOrReps: map['durationOrReps'] ?? '',
      instructions: map['instructions'] ?? '',
      cautionNote: map['cautionNote'] ?? '',
    );
  }
}

/// Khuyến nghị điều chỉnh dụng cụ (Gear Advice)
class GearAdvice {
  final String tensionAdvice;
  final String racketSpecAdvice;
  final String stringAdvice;
  final String otherAdvice;

  const GearAdvice({
    required this.tensionAdvice,
    required this.racketSpecAdvice,
    required this.stringAdvice,
    required this.otherAdvice,
  });

  Map<String, dynamic> toMap() => {
    'tensionAdvice': tensionAdvice,
    'racketSpecAdvice': racketSpecAdvice,
    'stringAdvice': stringAdvice,
    'otherAdvice': otherAdvice,
  };

  factory GearAdvice.fromMap(Map<String, dynamic> map) {
    return GearAdvice(
      tensionAdvice: map['tensionAdvice'] ?? '',
      racketSpecAdvice: map['racketSpecAdvice'] ?? '',
      stringAdvice: map['stringAdvice'] ?? '',
      otherAdvice: map['otherAdvice'] ?? '',
    );
  }
}

/// Định nghĩa một bệnh lý / chấn thương thể thao chuẩn
class InjuryType {
  final String id;
  final String nameVi;
  final String medicalName;
  final BodyPart bodyPart;
  final String description;
  final List<String> primarySymptoms;
  final String riceProtocol;
  final GearAdvice gearAdvice;
  final List<RehabExercise> exercises;

  const InjuryType({
    required this.id,
    required this.nameVi,
    required this.medicalName,
    required this.bodyPart,
    required this.description,
    required this.primarySymptoms,
    required this.riceProtocol,
    required this.gearAdvice,
    required this.exercises,
  });
}

/// Dữ liệu đầu vào người dùng khảo sát
class InjuryAssessmentInput {
  final BodyPart bodyPart;
  final int painScore; // 1 - 10
  final List<String> selectedSymptoms;
  final String triggerAction;
  final String onsetTime;
  final String? relatedRacketId;
  final String? relatedRacketName;
  final double? racketTensionLbs;
  final String? racketShaftStiffness;
  final int? racketBalanceMm;
  final double? racketTensionLossPercent;

  const InjuryAssessmentInput({
    required this.bodyPart,
    required this.painScore,
    required this.selectedSymptoms,
    required this.triggerAction,
    required this.onsetTime,
    this.relatedRacketId,
    this.relatedRacketName,
    this.racketTensionLbs,
    this.racketShaftStiffness,
    this.racketBalanceMm,
    this.racketTensionLossPercent,
  });
}

/// Kết quả chuẩn đoán tổng hợp
class InjuryDiagnosisResult {
  final InjuryType injuryType;
  final int confidencePercent;
  final PainSeverity severity;
  final String gearAnalysisSummary;
  final bool isGearFactorHigh;
  final bool canPlayBadmintonNow;
  final String safeToPlayAdvice;
  final DateTime diagnosedAt;

  InjuryDiagnosisResult({
    required this.injuryType,
    required this.confidencePercent,
    required this.severity,
    required this.gearAnalysisSummary,
    required this.isGearFactorHigh,
    required this.canPlayBadmintonNow,
    required this.safeToPlayAdvice,
    DateTime? diagnosedAt,
  }) : diagnosedAt = diagnosedAt ?? DateTime.now();
}

/// Bản ghi lịch sử chấn thương lưu trên tài khoản Player
class InjuryRecord {
  final String id;
  final String userId;
  final DateTime createdAt;
  final BodyPart bodyPart;
  final int painScore;
  final String injuryTypeId;
  final String injuryNameVi;
  final String medicalName;
  final PainSeverity severity;
  final RecoveryStatus status;
  final String? relatedRacketId;
  final String? relatedRacketName;
  final String gearAnalysis;
  final String notes;

  const InjuryRecord({
    required this.id,
    required this.userId,
    required this.createdAt,
    required this.bodyPart,
    required this.painScore,
    required this.injuryTypeId,
    required this.injuryNameVi,
    required this.medicalName,
    required this.severity,
    this.status = RecoveryStatus.activePain,
    this.relatedRacketId,
    this.relatedRacketName,
    this.gearAnalysis = '',
    this.notes = '',
  });

  InjuryRecord copyWith({
    String? id,
    String? userId,
    DateTime? createdAt,
    BodyPart? bodyPart,
    int? painScore,
    String? injuryTypeId,
    String? injuryNameVi,
    String? medicalName,
    PainSeverity? severity,
    RecoveryStatus? status,
    String? relatedRacketId,
    String? relatedRacketName,
    String? gearAnalysis,
    String? notes,
  }) {
    return InjuryRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      bodyPart: bodyPart ?? this.bodyPart,
      painScore: painScore ?? this.painScore,
      injuryTypeId: injuryTypeId ?? this.injuryTypeId,
      injuryNameVi: injuryNameVi ?? this.injuryNameVi,
      medicalName: medicalName ?? this.medicalName,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      relatedRacketId: relatedRacketId ?? this.relatedRacketId,
      relatedRacketName: relatedRacketName ?? this.relatedRacketName,
      gearAnalysis: gearAnalysis ?? this.gearAnalysis,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
      'bodyPart': bodyPart.name,
      'painScore': painScore,
      'injuryTypeId': injuryTypeId,
      'injuryNameVi': injuryNameVi,
      'medicalName': medicalName,
      'severity': severity.name,
      'status': status.name,
      'relatedRacketId': relatedRacketId,
      'relatedRacketName': relatedRacketName,
      'gearAnalysis': gearAnalysis,
      'notes': notes,
    };
  }

  factory InjuryRecord.fromMap(Map<String, dynamic> map, {String? docId}) {
    return InjuryRecord(
      id: docId ?? map['id'] ?? '',
      userId: map['userId'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      bodyPart: BodyPart.fromString(map['bodyPart']),
      painScore: map['painScore'] is int ? map['painScore'] : 5,
      injuryTypeId: map['injuryTypeId'] ?? '',
      injuryNameVi: map['injuryNameVi'] ?? 'Chấn thương cầu lông',
      medicalName: map['medicalName'] ?? '',
      severity: PainSeverity.fromString(map['severity']),
      status: RecoveryStatus.fromString(map['status']),
      relatedRacketId: map['relatedRacketId'],
      relatedRacketName: map['relatedRacketName'],
      gearAnalysis: map['gearAnalysis'] ?? '',
      notes: map['notes'] ?? '',
    );
  }
}
