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
  });

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
    );
  }
}
