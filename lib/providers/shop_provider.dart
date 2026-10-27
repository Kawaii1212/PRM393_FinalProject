import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../config/api_config.dart';
import '../models/shop_model.dart';
import '../models/product_model.dart';
import '../data/mock_data.dart';

class ShopProvider with ChangeNotifier {
  List<Shop> _shops = List.from(MockData.initialShops);
  final List<Product> _products = List.from(MockData.initialProducts);

  String _searchQuery = '';
  // Mặc định là null: Chỉ khi người dùng click vào cửa hàng trên bản đồ mới hiện phần giới thiệu
  Shop? _selectedShop;

  LatLng _userLocation = const LatLng(21.0124, 105.5253);
  String _userAreaLabel = 'Đang xác định vị trí của bạn...';
  bool _isLocating = false;
  bool _hasInitializedLocation = false;

  ShopProvider() {
    locateUserAndLoadNearbyShops();
  }

  LatLng get userLocation => _userLocation;
  String get userAreaLabel => _userAreaLabel;
  bool get isLocating => _isLocating;
  bool get hasInitializedLocation => _hasInitializedLocation;

  List<Shop> get shops {
    if (_searchQuery.isEmpty) {
      return List.unmodifiable(_shops);
    }
    return _shops
        .where(
          (s) =>
              s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              s.address.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              s.district.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  Shop? get selectedShop => _selectedShop;

  void selectShop(Shop? shop) {
    _selectedShop = shop;
    notifyListeners();
  }

  void clearSelection() {
    if (_selectedShop != null) {
      _selectedShop = null;
      notifyListeners();
    }
  }

  void searchShops(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Shop? getShopById(String id) {
    try {
      return _shops.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Lấy danh sách toàn bộ sản phẩm & dịch vụ cho cửa hàng (hỗ trợ cả các shop lấy động từ Google Places API)
  List<Product> getProductsForShop(String shopId) {
    final direct = _products.where((p) => p.shopId == shopId).toList();
    if (direct.isNotEmpty) return direct;
    // Với các cửa hàng thực tế trả về từ Google Places API, ánh xạ bảng giá dịch vụ đan vợt tiêu chuẩn
    return _products
        .where((p) => p.shopId == 'shop_01')
        .map(
          (p) => Product(
            id: '${p.id}_$shopId',
            shopId: shopId,
            name: p.name,
            category: p.category,
            price: p.price,
            description: p.description,
            imageUrl: p.imageUrl,
            availableColors: p.availableColors,
            isService: p.isService,
          ),
        )
        .toList();
  }

  List<Product> getServicesForShop(String shopId) {
    return getProductsForShop(shopId).where((p) => p.isService).toList();
  }

  List<Product> getAccessoriesForShop(String shopId) {
    return getProductsForShop(shopId).where((p) => !p.isService).toList();
  }

  /// Tự động lấy vị trí hiện tại của người dùng và gọi Google Places API lấy danh sách cửa hàng cầu lông xung quanh
  Future<LatLng> locateUserAndLoadNearbyShops({bool forceRefresh = false}) async {
    if (_hasInitializedLocation && !forceRefresh) {
      return _userLocation;
    }

    _isLocating = true;
    notifyListeners();

    try {
      LatLng? detectedPos;

      // 1. Thử lấy tọa độ từ GPS thiết bị (Geolocator)
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.whileInUse ||
              permission == LocationPermission.always) {
            final pos = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 4),
              ),
            );
            // Kiểm tra nếu tọa độ nằm trong lãnh thổ Việt Nam (tránh tọa độ mặc định ở Mỹ của Android Emulator)
            if (pos.latitude >= 8.0 &&
                pos.latitude <= 23.5 &&
                pos.longitude >= 102.0 &&
                pos.longitude <= 110.0) {
              detectedPos = LatLng(pos.latitude, pos.longitude);
            }
          }
        }
      } catch (e) {
        debugPrint('Geolocator warning: $e');
      }

      // 2. Nếu máy ảo Android đang trả về tọa độ mặc định ở Mỹ, tự động lấy vị trí thực tế qua IP mạng tại Việt Nam
      if (detectedPos == null) {
        try {
          final res = await http
              .get(Uri.parse('http://ip-api.com/json/?fields=status,lat,lon,city,regionName'))
              .timeout(const Duration(seconds: 4));
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body) as Map<String, dynamic>;
            if (data['status'] == 'success' &&
                data['lat'] != null &&
                data['lon'] != null) {
              detectedPos = LatLng(
                (data['lat'] as num).toDouble(),
                (data['lon'] as num).toDouble(),
              );
            }
          }
        } catch (e) {
          debugPrint('IP Geolocation fallback warning: $e');
        }
      }

      if (detectedPos != null) {
        _userLocation = detectedPos;
      }

      await _loadNearbyBadmintonShops(_userLocation);
      _hasInitializedLocation = true;
    } catch (e) {
      debugPrint('locateUserAndLoadNearbyShops error: $e');
    } finally {
      _isLocating = false;
      notifyListeners();
    }

    return _userLocation;
  }

  /// Cập nhật vị trí người dùng tới một tọa độ mới và tự động truy vấn lại các cửa hàng cầu lông gần đó
  Future<void> updateUserLocation(LatLng newLocation) async {
    _userLocation = newLocation;
    _selectedShop = null;
    _isLocating = true;
    notifyListeners();

    try {
      await _loadNearbyBadmintonShops(newLocation);
    } finally {
      _isLocating = false;
      notifyListeners();
    }
  }

  /// Gọi Google Places API (Giải pháp 4) để lấy danh sách các cửa hàng cầu lông có thật xung quanh tọa độ `center`
  /// mà không cần hardcode địa chỉ và không yêu cầu người dùng nhập API key trên màn hình.
  Future<void> _loadNearbyBadmintonShops(LatLng center) async {
    // Cập nhật tên khu vực hiện tại của người dùng
    final userGeo = await _reverseGeocode(center.latitude, center.longitude);
    _userAreaLabel = userGeo['shortAddress'] ?? 'Vị trí hiện tại của bạn';

    // 1. Ưu tiên gọi Google Places API (hỗ trợ cả Places API New v1 & Places API Legacy)
    List<Shop> discoveredShops = await _fetchFromGooglePlacesNew(center);
    if (discoveredShops.isEmpty) {
      discoveredShops = await _fetchFromGooglePlacesLegacy(center);
    }

    // 2. Nếu Google API Key chưa kích hoạt Billing trên Google Cloud, tự động lấy dữ liệu POI thực tế xung quanh
    if (discoveredShops.isEmpty) {
      discoveredShops = await _fetchRealPOIShopsFallback(center);
    }

    // 3. Nếu khu vực quá hẻo lánh không có POI nào trong bán kính tìm kiếm, tạo danh sách dự phòng theo vị trí hiện tại
    if (discoveredShops.isEmpty) {
      await _generateNearbyShopsAround(center);
      return;
    }

    // Sắp xếp cửa hàng gần nhất lên đầu
    discoveredShops.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    _shops = discoveredShops;

    if (_selectedShop != null) {
      _selectedShop = getShopById(_selectedShop!.id);
    }
  }

  /// Gọi Google Places API (New - v1: `places:searchText`) với `locationBias` quanh vị trí người dùng
  Future<List<Shop>> _fetchFromGooglePlacesNew(LatLng center) async {
    final apiKey = ApiConfig.googlePlacesApiKey.trim();
    if (apiKey.isEmpty) return [];

    try {
      final url = Uri.parse('https://places.googleapis.com/v1/places:searchText');
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': apiKey,
              'X-Goog-FieldMask':
                  'places.id,places.displayName,places.formattedAddress,places.location,places.rating,places.userRatingCount,places.nationalPhoneNumber,places.regularOpeningHours',
            },
            body: jsonEncode({
              'textQuery': ApiConfig.defaultBadmintonShopQuery,
              'languageCode': 'vi',
              'maxResultCount': 10,
              'locationBias': {
                'circle': {
                  'center': {
                    'latitude': center.latitude,
                    'longitude': center.longitude,
                  },
                  'radius': ApiConfig.searchRadiusMeters,
                },
              },
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final places = data['places'] as List<dynamic>? ?? [];
        if (places.isNotEmpty) {
          return _mapGooglePlacesNewToShops(places, center);
        }
      } else {
        debugPrint('Google Places API (New) status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Google Places API (New) warning: $e');
    }
    return [];
  }

  /// Gọi Google Places API (Legacy Nearby/Text Search) trong trường hợp project bật Places API bản chuẩn
  Future<List<Shop>> _fetchFromGooglePlacesLegacy(LatLng center) async {
    final apiKey = ApiConfig.googlePlacesApiKey.trim();
    if (apiKey.isEmpty) return [];

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/textsearch/json'
        '?query=${Uri.encodeComponent('cửa hàng cầu lông')}'
        '&location=${center.latitude},${center.longitude}'
        '&radius=${ApiConfig.searchRadiusMeters.toInt()}'
        '&language=vi'
        '&key=$apiKey',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final status = data['status']?.toString() ?? '';
        if (status == 'OK') {
          final results = data['results'] as List<dynamic>? ?? [];
          if (results.isNotEmpty) {
            return _mapGooglePlacesLegacyToShops(results, center);
          }
        } else {
          debugPrint('Google Places Legacy status: $status');
        }
      }
    } catch (e) {
      debugPrint('Google Places Legacy warning: $e');
    }
    return [];
  }

  List<Shop> _mapGooglePlacesNewToShops(
    List<dynamic> places,
    LatLng center,
  ) {
    const Distance distanceCalc = Distance();
    final templates = MockData.initialShops;
    final List<Shop> result = [];

    for (int i = 0; i < places.length; i++) {
      final item = places[i] as Map<String, dynamic>;
      final loc = item['location'] as Map<String, dynamic>?;
      if (loc == null) continue;

      final lat = (loc['latitude'] as num?)?.toDouble();
      final lng = (loc['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;

      final template = templates[i % templates.length];
      final displayNameObj = item['displayName'] as Map<String, dynamic>?;
      final name = displayNameObj?['text']?.toString() ?? template.name;
      final address =
          item['formattedAddress']?.toString() ?? 'Khu vực $_userAreaLabel';
      final rating = (item['rating'] as num?)?.toDouble() ?? template.rating;
      final reviewCount =
          (item['userRatingCount'] as num?)?.toInt() ?? template.reviewCount;
      final phone = item['nationalPhoneNumber']?.toString() ?? template.phone;

      String openHours = template.openHours;
      final openingHoursObj =
          item['regularOpeningHours'] as Map<String, dynamic>?;
      if (openingHoursObj != null && openingHoursObj['openNow'] != null) {
        final isOpen = openingHoursObj['openNow'] == true;
        openHours = isOpen
            ? 'Đang mở cửa • 08:00 - 21:30'
            : 'Tạm đóng cửa • Mở lại 08:00';
      }

      final distKm = distanceCalc.as(
        LengthUnit.Kilometer,
        center,
        LatLng(lat, lng),
      );

      result.add(
        Shop(
          id: item['id']?.toString() ?? 'gplace_new_$i',
          name: name,
          address: address,
          district: _extractDistrictFromAddress(address),
          city: _extractCityFromAddress(address),
          latitude: lat,
          longitude: lng,
          rating: double.parse(rating.toStringAsFixed(1)),
          reviewCount: reviewCount,
          machineModel: template.machineModel,
          stringerCert: template.stringerCert,
          phone: phone,
          openHours: openHours,
          imageUrl: template.imageUrl,
          distanceKm: double.parse(distKm.toStringAsFixed(1)),
        ),
      );
    }

    return result;
  }

  List<Shop> _mapGooglePlacesLegacyToShops(
    List<dynamic> results,
    LatLng center,
  ) {
    const Distance distanceCalc = Distance();
    final templates = MockData.initialShops;
    final List<Shop> list = [];

    for (int i = 0; i < results.length && i < 10; i++) {
      final item = results[i] as Map<String, dynamic>;
      final geometry = item['geometry'] as Map<String, dynamic>?;
      final loc = geometry?['location'] as Map<String, dynamic>?;
      if (loc == null) continue;

      final lat = (loc['lat'] as num?)?.toDouble();
      final lng = (loc['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;

      final template = templates[i % templates.length];
      final name = item['name']?.toString() ?? template.name;
      final address = item['formatted_address']?.toString() ??
          item['vicinity']?.toString() ??
          'Khu vực $_userAreaLabel';
      final rating = (item['rating'] as num?)?.toDouble() ?? template.rating;
      final reviewCount =
          (item['user_ratings_total'] as num?)?.toInt() ?? template.reviewCount;

      String openHours = template.openHours;
      final openingHours = item['opening_hours'] as Map<String, dynamic>?;
      if (openingHours != null && openingHours['open_now'] != null) {
        openHours = openingHours['open_now'] == true
            ? 'Đang mở cửa • 08:00 - 21:30'
            : 'Tạm đóng cửa • Mở lại 08:00';
      }

      final distKm = distanceCalc.as(
        LengthUnit.Kilometer,
        center,
        LatLng(lat, lng),
      );

      list.add(
        Shop(
          id: item['place_id']?.toString() ?? 'gplace_legacy_$i',
          name: name,
          address: address,
          district: _extractDistrictFromAddress(address),
          city: _extractCityFromAddress(address),
          latitude: lat,
          longitude: lng,
          rating: double.parse(rating.toStringAsFixed(1)),
          reviewCount: reviewCount,
          machineModel: template.machineModel,
          stringerCert: template.stringerCert,
          phone: template.phone,
          openHours: openHours,
          imageUrl: template.imageUrl,
          distanceKm: double.parse(distKm.toStringAsFixed(1)),
        ),
      );
    }

    return list;
  }

  /// Truy vấn dự phòng các cửa hàng cầu lông/thể thao thực tế quanh vị trí người dùng
  /// khi Google Cloud API Key chưa được kích hoạt thanh toán (Billing)
  Future<List<Shop>> _fetchRealPOIShopsFallback(LatLng center) async {
    const Distance distanceCalc = Distance();
    final templates = MockData.initialShops;

    try {
      final radius = ApiConfig.searchRadiusMeters.toInt();
      final query = '''
[out:json][timeout:6];
(
  node["shop"="sports"](around:$radius,${center.latitude},${center.longitude});
  way["shop"="sports"](around:$radius,${center.latitude},${center.longitude});
  node["sport"="badminton"](around:$radius,${center.latitude},${center.longitude});
  way["sport"="badminton"](around:$radius,${center.latitude},${center.longitude});
);
out center 10;
''';
      final res = await http
          .post(
            Uri.parse('https://overpass-api.de/api/interpreter'),
            body: {'data': query},
          )
          .timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final elements = data['elements'] as List<dynamic>? ?? [];
        final List<Shop> poiShops = [];

        for (int i = 0; i < elements.length && poiShops.length < 8; i++) {
          final el = elements[i] as Map<String, dynamic>;
          final tags = el['tags'] as Map<String, dynamic>? ?? {};

          double? lat = (el['lat'] as num?)?.toDouble();
          double? lng = (el['lon'] as num?)?.toDouble();
          if (lat == null || lng == null) {
            final c = el['center'] as Map<String, dynamic>?;
            lat = (c?['lat'] as num?)?.toDouble();
            lng = (c?['lon'] as num?)?.toDouble();
          }
          if (lat == null || lng == null) continue;

          final template = templates[poiShops.length % templates.length];
          final rawName = tags['name']?.toString().trim();
          final shopName = (rawName != null && rawName.isNotEmpty)
              ? rawName
              : template.name;

          final street = tags['addr:street']?.toString() ?? '';
          final houseNum = tags['addr:housenumber']?.toString() ?? '';
          final district = tags['addr:district']?.toString() ??
              tags['addr:suburb']?.toString() ??
              'Khu vực lân cận';
          final city = tags['addr:city']?.toString() ?? 'Việt Nam';

          String address = [houseNum, street, district]
              .where((s) => s.isNotEmpty)
              .join(' ')
              .trim();
          if (address.isEmpty || address == district) {
            final geo = await _reverseGeocode(lat, lng);
            address = geo['shortAddress'] ?? 'Gần $_userAreaLabel';
          }

          final distKm = distanceCalc.as(
            LengthUnit.Kilometer,
            center,
            LatLng(lat, lng),
          );

          poiShops.add(
            Shop(
              id: 'poi_${el['id'] ?? i}',
              name: shopName,
              address: address,
              district: district,
              city: city,
              latitude: lat,
              longitude: lng,
              rating: template.rating,
              reviewCount: template.reviewCount,
              machineModel: template.machineModel,
              stringerCert: template.stringerCert,
              phone: tags['phone']?.toString() ??
                  tags['contact:phone']?.toString() ??
                  template.phone,
              openHours: tags['opening_hours']?.toString() ?? template.openHours,
              imageUrl: template.imageUrl,
              distanceKm: double.parse(distKm.toStringAsFixed(1)),
            ),
          );
        }

        if (poiShops.isNotEmpty) {
          return poiShops;
        }
      }
    } catch (e) {
      debugPrint('Real POI fallback warning: $e');
    }
    return [];
  }

  String _extractDistrictFromAddress(String address) {
    final parts = address.split(',').map((e) => e.trim()).toList();
    if (parts.length >= 2) {
      return parts[parts.length - 2];
    }
    return 'Khu vực lân cận';
  }

  String _extractCityFromAddress(String address) {
    final parts = address.split(',').map((e) => e.trim()).toList();
    if (parts.isNotEmpty) {
      return parts.last;
    }
    return 'Việt Nam';
  }

  /// Đặt tọa độ các cửa hàng cầu lông xung quanh vị trí người dùng & lấy tên đường thực tế
  /// (Chỉ dùng khi thiết bị ngoại tuyến hoặc khu vực không có dữ liệu trên bản đồ)
  Future<void> _generateNearbyShopsAround(LatLng center) async {
    const Distance distanceCalc = Distance();

    // Độ lệch tọa độ xung quanh vị trí người dùng (~0.5km đến ~1.8km)
    final offsets = <List<double>>[
      [0.0042, 0.0035],  // ~0.6 km Đông Bắc
      [-0.0055, 0.0062], // ~0.9 km Đông Nam
      [0.0085, -0.0075], // ~1.3 km Tây Bắc
    ];

    final baseTemplates = MockData.initialShops;
    final List<Shop> updatedShops = [];
    for (int i = 0; i < baseTemplates.length; i++) {
      final baseShop = baseTemplates[i];
      final offset = offsets[i % offsets.length];
      final shopLat = center.latitude + offset[0];
      final shopLng = center.longitude + offset[1];

      final distKm = distanceCalc.as(
        LengthUnit.Kilometer,
        center,
        LatLng(shopLat, shopLng),
      );

      final geoInfo = await _reverseGeocode(shopLat, shopLng);

      updatedShops.add(
        baseShop.copyWith(
          latitude: shopLat,
          longitude: shopLng,
          address: geoInfo['shortAddress'] ?? 'Gần $_userAreaLabel',
          district: geoInfo['district'] ?? 'Khu vực lân cận',
          city: geoInfo['city'] ?? 'Việt Nam',
          distanceKm: double.parse(distKm.toStringAsFixed(1)),
        ),
      );
    }

    // Sắp xếp cửa hàng gần nhất lên đầu
    updatedShops.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    _shops = updatedShops;

    // Nếu đang có shop được chọn thì cập nhật lại thông tin mới của shop đó
    if (_selectedShop != null) {
      _selectedShop = getShopById(_selectedShop!.id);
    }
  }

  Future<Map<String, String>> _reverseGeocode(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=17&addressdetails=1&accept-language=vi',
      );
      final res = await http.get(
        url,
        headers: {'User-Agent': 'GearSportsPRM393App/1.0'},
      ).timeout(const Duration(seconds: 3));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final addr = data['address'] as Map<String, dynamic>? ?? {};

        final road = addr['road'] ??
            addr['pedestrian'] ??
            addr['suburb'] ??
            addr['neighbourhood'] ??
            addr['village'] ??
            '';
        final ward = addr['quarter'] ??
            addr['suburb'] ??
            addr['village'] ??
            addr['town'] ??
            '';
        final district = addr['city_district'] ??
            addr['district'] ??
            addr['county'] ??
            addr['town'] ??
            'Khu vực lân cận';
        final city = addr['city'] ??
            addr['state'] ??
            addr['province'] ??
            'Việt Nam';

        final parts = <String>[
          if (road.toString().isNotEmpty) road.toString(),
          if (ward.toString().isNotEmpty && ward.toString() != road.toString())
            ward.toString(),
          if (district.toString().isNotEmpty) district.toString(),
        ];

        final shortAddr = parts.isNotEmpty
            ? parts.join(', ')
            : (data['display_name']?.toString().split(',').take(3).join(',') ??
                'Gần vị trí của bạn');

        return {
          'shortAddress': shortAddr,
          'district': district.toString(),
          'city': city.toString(),
        };
      }
    } catch (e) {
      debugPrint('Reverse geocode fallback: $e');
    }
    return {
      'shortAddress': 'Tọa độ ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
      'district': 'Khu vực lân cận',
      'city': 'Việt Nam',
    };
  }
}
