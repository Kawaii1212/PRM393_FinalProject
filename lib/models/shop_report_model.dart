class ShopReport {
  final String id;
  final String shopId;
  final String shopName;
  final String reporterUid;
  final String reporterName;
  final String reporterEmail;
  final String reason;
  final String description;
  final String? chatEvidence;
  final DateTime createdAt;
  final String status; // 'pending' | 'resolved' | 'dismissed'
  final String? adminNote;

  ShopReport({
    required this.id,
    required this.shopId,
    required this.shopName,
    required this.reporterUid,
    required this.reporterName,
    required this.reporterEmail,
    required this.reason,
    required this.description,
    this.chatEvidence,
    required this.createdAt,
    this.status = 'pending',
    this.adminNote,
  });

  bool get isPending => status == 'pending';
  bool get isResolved => status == 'resolved';
  bool get isDismissed => status == 'dismissed';

  String get statusDisplayName {
    switch (status) {
      case 'resolved':
        return 'Đã giải quyết';
      case 'dismissed':
        return 'Đã bác bỏ';
      case 'pending':
      default:
        return 'Chờ Admin xử lý';
    }
  }

  ShopReport copyWith({
    String? id,
    String? shopId,
    String? shopName,
    String? reporterUid,
    String? reporterName,
    String? reporterEmail,
    String? reason,
    String? description,
    String? chatEvidence,
    DateTime? createdAt,
    String? status,
    String? adminNote,
  }) {
    return ShopReport(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      shopName: shopName ?? this.shopName,
      reporterUid: reporterUid ?? this.reporterUid,
      reporterName: reporterName ?? this.reporterName,
      reporterEmail: reporterEmail ?? this.reporterEmail,
      reason: reason ?? this.reason,
      description: description ?? this.description,
      chatEvidence: chatEvidence ?? this.chatEvidence,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      adminNote: adminNote ?? this.adminNote,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shopId': shopId,
      'shopName': shopName,
      'reporterUid': reporterUid,
      'reporterName': reporterName,
      'reporterEmail': reporterEmail,
      'reason': reason,
      'description': description,
      'chatEvidence': chatEvidence,
      'createdAt': createdAt.toIso8601String(),
      'status': status,
      'adminNote': adminNote,
    };
  }

  factory ShopReport.fromMap(Map<String, dynamic> map, {String? docId}) {
    return ShopReport(
      id: docId ?? map['id']?.toString() ?? '',
      shopId: map['shopId']?.toString() ?? '',
      shopName: map['shopName']?.toString() ?? '',
      reporterUid: map['reporterUid']?.toString() ?? '',
      reporterName: map['reporterName']?.toString() ?? '',
      reporterEmail: map['reporterEmail']?.toString() ?? '',
      reason: map['reason']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      chatEvidence: map['chatEvidence']?.toString(),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      status: map['status']?.toString() ?? 'pending',
      adminNote: map['adminNote']?.toString(),
    );
  }
}
