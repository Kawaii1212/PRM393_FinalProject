class TensionLog {
  final String id;
  final String racketId;
  final String stringModel;
  final double tensionLbs;
  final DateTime strungDate;
  final String shopName;
  final String notes;
  final double rating;

  TensionLog({
    required this.id,
    required this.racketId,
    required this.stringModel,
    required this.tensionLbs,
    required this.strungDate,
    required this.shopName,
    this.notes = '',
    this.rating = 5.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'racketId': racketId,
      'stringModel': stringModel,
      'tensionLbs': tensionLbs,
      'strungDate': strungDate.toIso8601String(),
      'shopName': shopName,
      'notes': notes,
      'rating': rating,
    };
  }

  factory TensionLog.fromMap(Map<String, dynamic> map) {
    return TensionLog(
      id: map['id'] ?? '',
      racketId: map['racketId'] ?? '',
      stringModel: map['stringModel'] ?? '',
      tensionLbs: (map['tensionLbs'] as num).toDouble(),
      strungDate: DateTime.parse(map['strungDate']),
      shopName: map['shopName'] ?? '',
      notes: map['notes'] ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
    );
  }
}
