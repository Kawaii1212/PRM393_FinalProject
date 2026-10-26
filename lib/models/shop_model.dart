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
}
