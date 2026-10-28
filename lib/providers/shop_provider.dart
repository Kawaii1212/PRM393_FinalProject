import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shop_model.dart';
import '../models/product_model.dart';
import '../data/csv_shop_data.dart';
import '../data/hcm_shop_data.dart';


class ShopProvider with ChangeNotifier {
  /// Bán kính tìm kiếm cửa hàng xung quanh người dùng mặc định (8.0 km)
  static const double defaultSearchRadiusKm = 8.0;
  static const double searchRadiusKm = defaultSearchRadiusKm;

  double _searchRadiusKm = defaultSearchRadiusKm;
  List<Shop> _shops = [];
  List<Shop> _allShops = [];
  final List<Product> _products = [];

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
  double get currentSearchRadiusKm => _searchRadiusKm;

  /// Nhãn hiển thị bán kính ngắn gọn (ví dụ: "8km", "15km", "30km")
  String get radiusLabel {
    if (_searchRadiusKm == _searchRadiusKm.roundToDouble()) {
      return '${_searchRadiusKm.toInt()}km';
    }
    return '${_searchRadiusKm.toStringAsFixed(1)}km';
  }

  /// Cập nhật bán kính tìm kiếm và tự động lọc lại danh sách cửa hàng
  void setSearchRadius(double radiusKm) {
    if ((_searchRadiusKm - radiusKm).abs() < 0.05) return;
    _searchRadiusKm = radiusKm;
    _filterShopsByRadius();
    notifyListeners();
  }

  /// Đặt lại bán kính về mặc định 8km
  void resetSearchRadius() {
    setSearchRadius(defaultSearchRadiusKm);
  }

  /// Đếm số lượng cửa hàng tìm thấy tương ứng với từng bán kính (dùng cho Slider)
  int getShopCountForRadius(double radiusKm) {
    if (_allShops.isEmpty) return 0;
    return _allShops.where((s) => s.distanceKm <= radiusKm).length;
  }

  /// Lấy toàn bộ cửa hàng có sẵn đã tính khoảng cách
  List<Shop> get allShops => List.unmodifiable(_allShops);

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
      return _allShops.firstWhere((s) => s.id == id);
    } catch (_) {
      try {
        return _shops.firstWhere((s) => s.id == id);
      } catch (_) {
        return null;
      }
    }
  }

  /// Lấy danh sách toàn bộ sản phẩm & dịch vụ cho cửa hàng
  List<Product> getProductsForShop(String shopId) {
    final custom = _products.where((p) => p.shopId == shopId).toList();
    if (custom.isNotEmpty) return custom;

    // Danh mục dịch vụ đan cước & phụ kiện mặc định cho mọi shop
    return [
      Product(
        id: '${shopId}_srv_01',
        shopId: shopId,
        name: 'Công đan cước 4 nút máy điện tử Yonex',
        category: ProductCategory.service,
        price: 40000,
        description:
            'Đan theo chuẩn Yonex World Tour, kẹp cước điện tử không dập cước, bảo vệ khung tuyệt đối.',
        imageUrl:
            'https://images.unsplash.com/photo-1587280501635-68a0e82cd5ff?auto=format&fit=crop&w=600&q=80',
        isService: true,
      ),
      Product(
        id: '${shopId}_srv_02',
        shopId: shopId,
        name: 'Gói đan cước lấy ngay trong 20 phút',
        category: ProductCategory.service,
        price: 60000,
        description:
            'Ưu tiên lên máy ngay lập tức, kiểm tra gen miễn phí, căn chỉnh cân bằng tĩnh.',
        imageUrl:
            'https://images.unsplash.com/photo-1587280501635-68a0e82cd5ff?auto=format&fit=crop&w=600&q=80',
        isService: true,
      ),
      Product(
        id: '${shopId}_str_01',
        shopId: shopId,
        name: 'Dây Cước Yonex Exbolt 65 (0.65mm)',
        category: ProductCategory.string,
        price: 175000,
        description:
            'Công nghệ sợi Forged Fiber siêu bền, trợ lực bùng nổ, âm thanh vang dội đanh tai.',
        imageUrl:
            'https://images.unsplash.com/photo-1626224583764-f87db24ac4ea?auto=format&fit=crop&w=600&q=80',
        availableColors: ['Trắng', 'Vàng Chanh', 'Đen'],
      ),
      Product(
        id: '${shopId}_str_02',
        shopId: shopId,
        name: 'Dây Cước Li-Ning No.1 (0.65mm)',
        category: ProductCategory.string,
        price: 150000,
        description:
            'Độ nảy 10/10, âm nổ cực đanh, cước trợ lực số 1 của thương hiệu Li-Ning.',
        imageUrl:
            'https://images.unsplash.com/photo-1626224583764-f87db24ac4ea?auto=format&fit=crop&w=600&q=80',
        availableColors: ['Trắng', 'Đỏ', 'Cam'],
      ),
      Product(
        id: '${shopId}_str_03',
        shopId: shopId,
        name: 'Dây Cước Yonex BG65 Ti Quốc Dân (0.70mm)',
        category: ProductCategory.string,
        price: 130000,
        description:
            'Phủ hợp kim Titanium bền bỉ, thích hợp người chơi phong trào tiết kiệm chi phí.',
        imageUrl:
            'https://images.unsplash.com/photo-1626224583764-f87db24ac4ea?auto=format&fit=crop&w=600&q=80',
        availableColors: ['Trắng', 'Đen', 'Vàng'],
      ),
      Product(
        id: '${shopId}_grp_01',
        shopId: shopId,
        name: 'Quấn cán Yonex AC102EX Super Grap',
        category: ProductCategory.grip,
        price: 35000,
        description:
            'Quấn cán cao su bám tay số 1 thế giới, chống trơn tuyệt đối, độ dày 0.6mm.',
        imageUrl:
            'https://images.unsplash.com/photo-1541534741688-6078c6bfb5c5?auto=format&fit=crop&w=600&q=80',
        availableColors: ['Trắng', 'Đen', 'Vàng', 'Đỏ', 'Tím'],
      ),
    ];
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

  /// Nạp danh sách các cửa hàng cầu lông:
  /// 1. Tải toàn bộ 121 cửa hàng thực tế TP.HCM từ mapHCM.csv (HcmShopData)
  ///    kết hợp 117 cửa hàng từ google.csv (CsvShopData) và Cloud Firestore (nếu có)
  /// 2. Tự động tính khoảng cách thực tế (km) từ vị trí hiện tại của người dùng đến từng shop
  /// 3. Sắp xếp các shop từ gần nhất đến xa nhất
  Future<void> _loadNearbyBadmintonShops(LatLng center) async {
    // Cập nhật tên khu vực hiện tại của người dùng
    final userGeo = await _reverseGeocode(center.latitude, center.longitude);
    _userAreaLabel = userGeo['shortAddress'] ?? 'Vị trí hiện tại của bạn';

    const Distance distanceCalc = Distance();

    // 1. Dữ liệu nền tảng phong phú: 121 shop TP.HCM thực tế (từ mapHCM.csv) + Hà Nội (google.csv)
    final Map<String, Shop> shopMap = {
      for (final s in HcmShopData.shops) s.id: s,
      for (final s in CsvShopData.shops) s.id: s,
    };

    // 2. Đồng bộ thêm từ Cloud Firestore (collection 'shops') nếu có
    if (_isFirebaseReady) {
      try {
        final firestoreShops = await _fetchShopsFromFirestore();
        for (final s in firestoreShops) {
          shopMap[s.id] = s;
        }
      } catch (e) {
        debugPrint('Firestore shop sync note: $e');
      }
    }

    final List<Shop> allAvailableShops = shopMap.values.toList();

    // Tính toán khoảng cách thực tế từ vị trí người dùng đến từng shop
    final List<Shop> computedShops = allAvailableShops.map((s) {
      final distKm = distanceCalc.as(
        LengthUnit.Kilometer,
        center,
        LatLng(s.latitude, s.longitude),
      );
      return s.copyWith(distanceKm: double.parse(distKm.toStringAsFixed(1)));
    }).toList();

    // Sắp xếp các shop gần vị trí hiện tại nhất lên đầu
    computedShops.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    _allShops = computedShops;

    // Lọc danh sách hiển thị theo bán kính người dùng đã chọn
    _filterShopsByRadius();

    if (_selectedShop != null) {
      _selectedShop = getShopById(_selectedShop!.id);
    }
  }

  /// Lọc danh sách shop hiển thị dựa theo bán kính _searchRadiusKm
  void _filterShopsByRadius() {
    if (_allShops.isEmpty) return;

    final filtered = _allShops
        .where((s) => s.distanceKm <= _searchRadiusKm)
        .toList();

    // Nếu ở tỉnh xa (shop gần nhất cách > 50km) và không có shop nào trong bán kính:
    // Fallback 5 shop gần nhất để người dùng thử nghiệm tính năng
    if (filtered.isEmpty &&
        _allShops.isNotEmpty &&
        _allShops.first.distanceKm > 50.0) {
      _shops = _allShops.take(5).toList();
    } else {
      _shops = filtered;
    }

    // Nếu shop đang chọn nằm ngoài bán kính mới thì bỏ chọn
    if (_selectedShop != null &&
        !_shops.any((s) => s.id == _selectedShop!.id)) {
      _selectedShop = null;
    }
  }

  // --- Cloud Firestore Integration ---
  bool get _isFirebaseReady => Firebase.apps.isNotEmpty;

  /// Lấy danh sách cửa hàng từ Cloud Firestore
  Future<List<Shop>> _fetchShopsFromFirestore() async {
    if (!_isFirebaseReady) return [];
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('shops')
          .get()
          .timeout(const Duration(seconds: 4));
      return snapshot.docs
          .map((doc) => Shop.fromMap(doc.data(), docId: doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error fetching shops from Firestore: $e');
      return [];
    }
  }

  /// Đẩy dữ liệu cửa hàng lên Cloud Firestore (collection 'shops')
  Future<int> seedShopsToFirestore({bool hcmOnly = false}) async {
    if (!_isFirebaseReady) {
      debugPrint('Firebase is not initialized.');
      return 0;
    }
    try {
      final firestore = FirebaseFirestore.instance;
      final targetShops = hcmOnly
          ? HcmShopData.shops
          : [...HcmShopData.shops, ...CsvShopData.shops];

      // Đẩy theo từng batch (Firestore cho phép tối đa 500 ops/batch)
      const int batchSize = 400;
      int count = 0;
      for (int i = 0; i < targetShops.length; i += batchSize) {
        final batch = firestore.batch();
        final chunk = targetShops.skip(i).take(batchSize);
        for (final shop in chunk) {
          final docRef = firestore.collection('shops').doc(shop.id);
          batch.set(docRef, shop.toMap(), SetOptions(merge: true));
          count++;
        }
        await batch.commit();
      }
      debugPrint('Successfully seeded $count shops to Firestore!');
      return count;
    } catch (e) {
      debugPrint('seedShopsToFirestore error: $e');
      return 0;
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
