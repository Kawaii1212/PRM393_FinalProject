class Shop {
  final String id;
  final String name;
  final String address;
  final String district;
  final String city;
  final double latitude;
  final double longitude;
  final double rating;
  final int reviewCount;
  final String machineModel; // e.g. "Máy điện tử Yonex Precision 9.0"
  final String stringerCert; // e.g. "Thợ đạt chuẩn Yonex Master Stringer"
  final String phone;
  final String openHours;
  final String imageUrl;
  final double distanceKm;
  final String? ownerUid;
  final String? ownerName;
  final String? ownerEmail;
  final String status; // 'pending' | 'approved' | 'disabled'

  Shop({
    required this.id,
    required this.name,
    required this.address,
    required this.district,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.rating,
    required this.reviewCount,
    required this.machineModel,
    required this.stringerCert,
    required this.phone,
    required this.openHours,
    required this.imageUrl,
    this.distanceKm = 1.2,
    this.ownerUid,
    this.ownerName,
    this.ownerEmail,
    this.status = 'approved',
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isDisabled => status == 'disabled';

  String get statusDisplayName {
    switch (status) {
      case 'pending':
        return 'Chờ phê duyệt';
      case 'disabled':
        return 'Đã vô hiệu hóa';
      case 'approved':
      default:
        return 'Đang hoạt động';
    }
  }

  Shop copyWith({
    String? id,
    String? name,
    String? address,
    String? district,
    String? city,
    double? latitude,
    double? longitude,
    double? rating,
    int? reviewCount,
    String? machineModel,
    String? stringerCert,
    String? phone,
    String? openHours,
    String? imageUrl,
    double? distanceKm,
    String? ownerUid,
    String? ownerName,
    String? ownerEmail,
    String? status,
  }) {
    return Shop(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      district: district ?? this.district,
      city: city ?? this.city,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      machineModel: machineModel ?? this.machineModel,
      stringerCert: stringerCert ?? this.stringerCert,
      phone: phone ?? this.phone,
      openHours: openHours ?? this.openHours,
      imageUrl: imageUrl ?? this.imageUrl,
      distanceKm: distanceKm ?? this.distanceKm,
      ownerUid: ownerUid ?? this.ownerUid,
      ownerName: ownerName ?? this.ownerName,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'district': district,
      'city': city,
      'latitude': latitude,
      'longitude': longitude,
      'rating': rating,
      'reviewCount': reviewCount,
      'machineModel': machineModel,
      'stringerCert': stringerCert,
      'phone': phone,
      'openHours': openHours,
      'imageUrl': imageUrl,
      'distanceKm': distanceKm,
      'ownerUid': ownerUid,
      'ownerName': ownerName,
      'ownerEmail': ownerEmail,
      'status': status,
    };
  }

  factory Shop.fromMap(Map<String, dynamic> map, {String? docId}) {
    return Shop(
      id: map['id']?.toString() ?? docId ?? '',
      name: map['name']?.toString() ?? 'Cửa hàng cầu lông',
      address: map['address']?.toString() ?? '',
      district: map['district']?.toString() ?? 'Khu vực lân cận',
      city: map['city']?.toString() ?? 'Việt Nam',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 21.0285,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 105.8542,
      rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
      machineModel:
          map['machineModel']?.toString() ?? 'Máy đan cước điện tử',
      stringerCert:
          map['stringerCert']?.toString() ?? 'Kỹ thuật viên đan vợt',
      phone: map['phone']?.toString() ?? '',
      openHours: map['openHours']?.toString() ?? '08:00 - 21:30',
      imageUrl: map['imageUrl']?.toString() ?? '',
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 1.0,
      ownerUid: map['ownerUid']?.toString(),
      ownerName: map['ownerName']?.toString(),
      ownerEmail: map['ownerEmail']?.toString(),
      status: map['status']?.toString() ?? 'approved',
    );
  }
}
