import '../firebase_options.dart';

/// Cấu hình API cho dịch vụ Bản đồ & Tìm kiếm Địa điểm (Google Places API).
///
/// LƯU Ý DÀNH CHO DEVELOPER:
/// - Người dùng cuối sẽ KHÔNG bao giờ phải nhập API Key trên giao diện ứng dụng.
/// - Mặc định hệ thống sử dụng Google API Key của project (`DefaultFirebaseOptions.android.apiKey`)
///   hoặc nhận qua biến môi trường lúc build (`--dart-define=GOOGLE_MAPS_API_KEY=...`).
/// - Bạn cũng có thể thay trực tiếp chuỗi `_customGooglePlacesApiKey` bên dưới bằng
///   API Key đã bật "Places API (New)" hoặc "Places API" trên Google Cloud Console.
class ApiConfig {
  static const String _envApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  /// Điền trực tiếp Google Maps / Places API Key của bạn vào đây nếu tách riêng khỏi Firebase Key:
  static const String _customGooglePlacesApiKey = '';

  /// Trả về Google Places API Key dùng để truy vấn tự động các cửa hàng cầu lông xung quanh.
  static String get googlePlacesApiKey {
    if (_envApiKey.isNotEmpty) {
      return _envApiKey;
    }
    if (_customGooglePlacesApiKey.isNotEmpty) {
      return _customGooglePlacesApiKey;
    }
    return DefaultFirebaseOptions.android.apiKey;
  }

  /// Bán kính tìm kiếm cửa hàng cầu lông tối đa xung quanh vị trí người dùng (mét)
  static const double searchRadiusMeters = 20000.0; // 20 km

  /// Từ khóa tìm kiếm mặc định gửi lên Google Places API
  static const String defaultBadmintonShopQuery =
      'cửa hàng cầu lông đan vợt badminton shop';
}
