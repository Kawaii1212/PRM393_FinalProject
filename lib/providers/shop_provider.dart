import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../config/api_config.dart';
import '../models/shop_model.dart';
import '../models/product_model.dart';
import '../data/csv_shop_data.dart';
import '../data/hcm_shop_data.dart';

class ShopProvider with ChangeNotifier {
  static const String _prefShopsKey = 'gearsports_admin_shops';
  static const String _prefProductsKey = 'gearsports_admin_products';

  /// Bán kính tìm kiếm cửa hàng xung quanh người dùng mặc định (8.0 km)
  static const double defaultSearchRadiusKm = 8.0;
  static const double searchRadiusKm = defaultSearchRadiusKm;

  double _searchRadiusKm = defaultSearchRadiusKm;
  List<Shop> _shops = [];
  List<Shop> _allShops = [];
  List<Shop> _discoveredShops = [];
  List<Shop> _firestoreShops = [];
  List<Product> _products = [];

  String _searchQuery = '';
  // Mặc định là null: Chỉ khi người dùng click vào cửa hàng trên bản đồ mới hiện phần giới thiệu
  Shop? _selectedShop;

  LatLng _userLocation = const LatLng(21.0124, 105.5253);
  String _userAreaLabel = 'Đang xác định vị trí của bạn...';
  bool _isLocating = false;
  bool _hasInitializedLocation = false;

  ShopProvider() {
    syncCatalogFromFirestore();
    locateUserAndLoadNearbyShops();
  }

  bool get _isFirebaseReady {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  List<Shop> get firestoreShops => List.unmodifiable(_firestoreShops);
  List<Product> get allProducts => List.unmodifiable(_products);

  /// Danh sách tất cả cửa hàng dành cho Admin kiểm duyệt (bao gồm Chờ duyệt, Đang hoạt động, Đã vô hiệu hóa)
  List<Shop> get allShopsForAdmin {
    final mapById = <String, Shop>{};
    for (final s in _firestoreShops) {
      mapById[s.id] = s;
    }
    for (final s in _discoveredShops) {
      mapById.putIfAbsent(s.id, () => s);
    }
    final list = mapById.values.toList();
    int rankStatus(String st) {
      if (st == 'pending') return 0;
      if (st == 'approved') return 1;
      return 2;
    }

    list.sort((a, b) {
      final cmp = rankStatus(a.status).compareTo(rankStatus(b.status));
      if (cmp != 0) return cmp;
      return a.distanceKm.compareTo(b.distanceKm);
    });
    return list;
  }

  int get pendingShopsCount =>
      allShopsForAdmin.where((s) => s.isPending).length;
  int get approvedShopsCount =>
      allShopsForAdmin.where((s) => s.isApproved).length;
  int get disabledShopsCount =>
      allShopsForAdmin.where((s) => s.isDisabled).length;

  /// Tìm cửa hàng của Chủ Shop đang đăng nhập (`ownerUid`)
  Shop? getShopForOwner(String ownerUid) {
    try {
      return _firestoreShops.firstWhere((s) => s.ownerUid == ownerUid);
    } catch (_) {
      return null;
    }
  }

  /// Đồng bộ Cửa hàng & Sản phẩm/Dịch vụ từ Cloud Firestore (`shops`, `products`)
  Future<void> syncCatalogFromFirestore() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Đọc từ Local Cache trước
      final rawShops = prefs.getString(_prefShopsKey);
      if (rawShops != null && rawShops.isNotEmpty) {
        final list = jsonDecode(rawShops) as List<dynamic>;
        _firestoreShops = list
            .map((e) => Shop.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }

      final rawProds = prefs.getString(_prefProductsKey);
      if (rawProds != null && rawProds.isNotEmpty) {
        final list = jsonDecode(rawProds) as List<dynamic>;
        _products = list
            .map((e) => Product.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }
      _mergeFirestoreShopsIntoList();
      notifyListeners();

      // 2. Đồng bộ với Cloud Firestore
      if (_isFirebaseReady) {
        final shopSnap = await FirebaseFirestore.instance
            .collection('shops')
            .get()
            .timeout(const Duration(seconds: 6));
        if (shopSnap.docs.isNotEmpty || _firestoreShops.isEmpty) {
          final remoteShops = shopSnap.docs
              .map((d) => Shop.fromMap(d.data(), docId: d.id))
              .toList();
          final mergedMap = <String, Shop>{};
          for (final s in _firestoreShops) {
            mergedMap[s.id] = s;
          }
          for (final s in remoteShops) {
            mergedMap[s.id] = s;
          }
          _firestoreShops = mergedMap.values.toList();
        }

        final prodSnap = await FirebaseFirestore.instance
            .collection('products')
            .get()
            .timeout(const Duration(seconds: 6));
        if (prodSnap.docs.isNotEmpty || _products.isEmpty) {
          final remoteProds = prodSnap.docs
              .map((d) => Product.fromMap(d.data(), docId: d.id))
              .toList();
          final mergedProdMap = <String, Product>{};
          for (final p in _products) {
            mergedProdMap[p.id] = p;
          }
          for (final p in remoteProds) {
            mergedProdMap[p.id] = p;
          }
          _products = mergedProdMap.values.toList();
        }

        await prefs.setString(
          _prefShopsKey,
          jsonEncode(_firestoreShops.map((s) => s.toMap()).toList()),
        );
        await prefs.setString(
          _prefProductsKey,
          jsonEncode(_products.map((p) => p.toMap()).toList()),
        );
        _mergeFirestoreShopsIntoList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('syncCatalogFromFirestore warning: $e');
    }
  }

  void _mergeFirestoreShopsIntoList() {
    const Distance distanceCalc = Distance();
    final updatedFirestore = _firestoreShops.map((s) {
      final dist = distanceCalc.as(
        LengthUnit.Kilometer,
        _userLocation,
        LatLng(s.latitude, s.longitude),
      );
      return s.copyWith(distanceKm: double.parse(dist.toStringAsFixed(1)));
    }).toList();

    _firestoreShops = updatedFirestore;

    final mapById = <String, Shop>{};
    for (final s in _discoveredShops) {
      if (s.isApproved) {
        mapById[s.id] = s;
      }
    }
    for (final s in updatedFirestore) {
      if (s.isApproved) {
        mapById[s.id] = s;
      } else {
        // Nếu shop bị vô hiệu hóa hoặc đang chờ duyệt thì không hiển thị trên bản đồ Người chơi
        mapById.remove(s.id);
      }
    }

    final merged = mapById.values.toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    _allShops = merged;
    _filterShopsByRadius();
    notifyListeners();
  }

  /// Thêm hoặc cập nhật Cửa hàng trên Cloud Firestore (`shops/{id}`)
  Future<void> upsertShop(Shop shop) async {
    final idx = _firestoreShops.indexWhere((s) => s.id == shop.id);
    if (idx != -1) {
      _firestoreShops[idx] = shop;
    } else {
      _firestoreShops.insert(0, shop);
    }
    _mergeFirestoreShopsIntoList();
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefShopsKey,
        jsonEncode(_firestoreShops.map((s) => s.toMap()).toList()),
      );
      if (_isFirebaseReady) {
        await FirebaseFirestore.instance
            .collection('shops')
            .doc(shop.id)
            .set(shop.toMap(), SetOptions(merge: true))
            .timeout(const Duration(seconds: 5));
      }
    } catch (e) {
      debugPrint('upsertShop error: $e');
    }
  }

  /// Admin phê duyệt (`approved`) hoặc vô hiệu hóa (`disabled`) Cửa hàng
  Future<void> updateShopStatus(Shop shop, String newStatus) async {
    final updated = shop.copyWith(status: newStatus);
    await upsertShop(updated);
  }

  /// Xóa Cửa hàng khỏi Cloud Firestore (`shops/{id}`)
  Future<void> deleteShop(String shopId) async {
    _firestoreShops.removeWhere((s) => s.id == shopId);
    _discoveredShops.removeWhere((s) => s.id == shopId);
    _allShops.removeWhere((s) => s.id == shopId);
    _shops.removeWhere((s) => s.id == shopId);
    if (_selectedShop?.id == shopId) {
      _selectedShop = null;
    }
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefShopsKey,
        jsonEncode(_firestoreShops.map((s) => s.toMap()).toList()),
      );
      if (_isFirebaseReady) {
        await FirebaseFirestore.instance
            .collection('shops')
            .doc(shopId)
            .delete()
            .timeout(const Duration(seconds: 5));
      }
    } catch (e) {
      debugPrint('deleteShop error: $e');
    }
  }

  /// Thêm hoặc cập nhật Sản phẩm / Dịch vụ đan cước trên Cloud Firestore (`products/{id}`)
  Future<void> upsertProduct(Product product) async {
    final idx = _products.indexWhere((p) => p.id == product.id);
    if (idx != -1) {
      _products[idx] = product;
    } else {
      _products.insert(0, product);
    }
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefProductsKey,
        jsonEncode(_products.map((p) => p.toMap()).toList()),
      );
      if (_isFirebaseReady) {
        await FirebaseFirestore.instance
            .collection('products')
            .doc(product.id)
            .set(product.toMap(), SetOptions(merge: true))
            .timeout(const Duration(seconds: 5));
      }
    } catch (e) {
      debugPrint('upsertProduct error: $e');
    }
  }

  /// Admin kiểm duyệt hợp lệ (`approved`) hoặc đánh dấu vi phạm (`rejected`) vật phẩm/dịch vụ
  Future<void> updateProductStatus(Product product, String newStatus) async {
    final updated = product.copyWith(status: newStatus);
    await upsertProduct(updated);
  }

  /// Xóa Sản phẩm / Dịch vụ khỏi Cloud Firestore (`products/{id}`)
  Future<void> deleteProduct(String productId) async {
    _products.removeWhere((p) => p.id == productId);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefProductsKey,
        jsonEncode(_products.map((p) => p.toMap()).toList()),
      );
      if (_isFirebaseReady) {
        await FirebaseFirestore.instance
            .collection('products')
            .doc(productId)
            .delete()
            .timeout(const Duration(seconds: 5));
      }
    } catch (e) {
      debugPrint('deleteProduct error: $e');
    }
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
        return _firestoreShops.firstWhere((s) => s.id == id);
      } catch (_) {
        try {
          return _shops.firstWhere((s) => s.id == id);
        } catch (_) {
          return null;
        }
      }
    }
  }

  /// Lấy danh sách sản phẩm & dịch vụ hợp lệ hiển thị cho Người chơi
  List<Product> getProductsForShop(String shopId) {
    final custom = _products
        .where(
          (p) =>
              (p.shopId == shopId || p.shopId == 'all') && !p.isRejected,
        )
        .toList();
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

  /// Lấy toàn bộ sản phẩm & dịch vụ của riêng một cửa hàng cho Chủ Shop / Admin quản lý
  List<Product> getDirectProductsForShop(String shopId) {
    return _products.where((p) => p.shopId == shopId).toList();
  }

  List<Product> getServicesForShop(String shopId) {
    return getProductsForShop(shopId).where((p) => p.isService).toList();
  }

  List<Product> getAccessoriesForShop(String shopId) {
    return getProductsForShop(shopId).where((p) => !p.isService).toList();
  }

  /// Tự động lấy vị trí hiện tại của người dùng và truy vấn danh sách cửa hàng cầu lông xung quanh
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
  ///    kết hợp 117 cửa hàng từ google.csv (CsvShopData) và Cloud Firestore
  /// 2. Hỗ trợ tìm kiếm thời gian thực qua Google Places API (nếu bật)
  /// 3. Sắp xếp các shop từ gần nhất đến xa nhất và lọc theo bán kính
  Future<void> _loadNearbyBadmintonShops(LatLng center) async {
    // Cập nhật tên khu vực hiện tại của người dùng
    final userGeo = await _reverseGeocode(center.latitude, center.longitude);
    _userAreaLabel = userGeo['shortAddress'] ?? 'Vị trí hiện tại của bạn';

    const Distance distanceCalc = Distance();

    // 1. Dữ liệu nền tảng phong phú: 121 shop TP.HCM thực tế + Hà Nội
    final Map<String, Shop> baseShopMap = {
      for (final s in HcmShopData.shops) s.id: s,
      for (final s in CsvShopData.shops) s.id: s,
    };

    // 2. Tự động tìm thêm qua Google Places API nếu có cấu hình API Key
    try {
      List<Shop> places = await _fetchFromGooglePlacesNew(center);
      if (places.isEmpty) {
        places = await _fetchFromGooglePlacesLegacy(center);
      }
      for (final s in places) {
        baseShopMap[s.id] = s;
      }
    } catch (e) {
      debugPrint('Google Places search note: $e');
    }

    // 3. Tính khoảng cách thực tế từ vị trí người dùng đến từng shop
    final computedShops = baseShopMap.values.map((s) {
      final distKm = distanceCalc.as(
        LengthUnit.Kilometer,
        center,
        LatLng(s.latitude, s.longitude),
      );
      return s.copyWith(distanceKm: double.parse(distKm.toStringAsFixed(1)));
    }).toList();

    _discoveredShops = computedShops;
    _mergeFirestoreShopsIntoList();

    if (_selectedShop != null) {
      _selectedShop = getShopById(_selectedShop!.id);
    }
  }

  /// Lọc danh sách shop hiển thị dựa theo bán kính _searchRadiusKm
  void _filterShopsByRadius() {
    if (_allShops.isEmpty) {
      _shops = [];
      return;
    }

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
      final query = Uri.encodeComponent(ApiConfig.defaultBadmintonShopQuery);
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/textsearch/json?query=$query&location=${center.latitude},${center.longitude}&radius=${ApiConfig.searchRadiusMeters}&language=vi&key=$apiKey',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>? ?? [];
        if (results.isNotEmpty) {
          return _mapGooglePlacesLegacyToShops(results, center);
        }
      }
    } catch (e) {
      debugPrint('Google Places API (Legacy) warning: $e');
    }
    return [];
  }

  List<Shop> _mapGooglePlacesNewToShops(List<dynamic> places, LatLng center) {
    const Distance distanceCalc = Distance();
    final List<Shop> list = [];

    for (int i = 0; i < places.length; i++) {
      final p = places[i] as Map<String, dynamic>;
      final loc = p['location'] as Map<String, dynamic>?;
      if (loc == null) continue;

      final lat = (loc['latitude'] as num?)?.toDouble() ?? 0.0;
      final lng = (loc['longitude'] as num?)?.toDouble() ?? 0.0;
      final nameObj = p['displayName'] as Map<String, dynamic>?;
      final name = nameObj?['text']?.toString() ?? 'Cửa hàng cầu lông';
      final address = p['formattedAddress']?.toString() ?? 'Khu vực lân cận';
      final rating = (p['rating'] as num?)?.toDouble() ?? 5.0;
      final reviewCount = (p['userRatingCount'] as num?)?.toInt() ?? 0;
      final phone = p['nationalPhoneNumber']?.toString() ?? 'Chưa cập nhật';

      final distKm = distanceCalc.as(
        LengthUnit.Kilometer,
        center,
        LatLng(lat, lng),
      );

      list.add(
        Shop(
          id: p['id']?.toString() ?? 'gplace_new_$i',
          name: name,
          address: address,
          district: _extractDistrictFromAddress(address),
          city: _extractCityFromAddress(address),
          latitude: lat,
          longitude: lng,
          rating: double.parse(rating.toStringAsFixed(1)),
          reviewCount: reviewCount,
          machineModel: 'Máy đan cước điện tử chuẩn BWF',
          stringerCert: 'Kỹ thuật viên đan 4 nút chuyên nghiệp',
          phone: phone,
          openHours: '08:00 - 21:30',
          imageUrl: '',
          distanceKm: double.parse(distKm.toStringAsFixed(1)),
        ),
      );
    }
    return list;
  }

  List<Shop> _mapGooglePlacesLegacyToShops(List<dynamic> results, LatLng center) {
    const Distance distanceCalc = Distance();
    final List<Shop> list = [];

    for (int i = 0; i < results.length; i++) {
      final item = results[i] as Map<String, dynamic>;
      final geom = item['geometry'] as Map<String, dynamic>?;
      final loc = geom?['location'] as Map<String, dynamic>?;
      if (loc == null) continue;

      final lat = (loc['lat'] as num?)?.toDouble() ?? 0.0;
      final lng = (loc['lng'] as num?)?.toDouble() ?? 0.0;
      final name = item['name']?.toString() ?? 'Cửa hàng cầu lông';
      final address = item['formatted_address']?.toString() ??
          item['vicinity']?.toString() ??
          'Khu vực lân cận';
      final rating = (item['rating'] as num?)?.toDouble() ?? 5.0;
      final reviewCount = (item['user_ratings_total'] as num?)?.toInt() ?? 0;

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
          machineModel: 'Máy đan cước điện tử chuẩn BWF',
          stringerCert: 'Kỹ thuật viên đan 4 nút chuyên nghiệp',
          phone: 'Chưa cập nhật',
          openHours: '08:00 - 21:30',
          imageUrl: '',
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
out center 40;
''';
      final res = await http
          .post(
            Uri.parse('https://overpass-api.de/api/interpreter'),
            body: {'data': query},
          )
          .timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final rawElements = data['elements'] as List<dynamic>? ?? [];
        // Sắp xếp ưu tiên các điểm gần vị trí người dùng nhất (đặc biệt trong bán kính 2 km)
        final elementsWithDist = <Map<String, dynamic>>[];
        for (final raw in rawElements) {
          final el = raw as Map<String, dynamic>;
          final tags = el['tags'] as Map<String, dynamic>? ?? {};
          final rawName = tags['name']?.toString().trim();
          if (rawName == null || rawName.isEmpty) continue;

          double? lat = (el['lat'] as num?)?.toDouble();
          double? lng = (el['lon'] as num?)?.toDouble();
          if (lat == null || lng == null) {
            final c = el['center'] as Map<String, dynamic>?;
            lat = (c?['lat'] as num?)?.toDouble();
            lng = (c?['lon'] as num?)?.toDouble();
          }
          if (lat == null || lng == null) continue;

          final distKm = distanceCalc.as(
            LengthUnit.Kilometer,
            center,
            LatLng(lat, lng),
          );
          elementsWithDist.add({
            'el': el,
            'lat': lat,
            'lng': lng,
            'distKm': distKm,
          });
        }
        elementsWithDist.sort(
          (a, b) => (a['distKm'] as double).compareTo(b['distKm'] as double),
        );

        final List<Shop> poiShops = [];

        for (int i = 0; i < elementsWithDist.length && poiShops.length < 15; i++) {
          final item = elementsWithDist[i];
          final el = item['el'] as Map<String, dynamic>;
          final lat = item['lat'] as double;
          final lng = item['lng'] as double;
          final distKm = item['distKm'] as double;
          final tags = el['tags'] as Map<String, dynamic>? ?? {};
          final rawName = tags['name']!.toString().trim();

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

          poiShops.add(
            Shop(
              id: 'poi_${el['id'] ?? i}',
              name: rawName,
              address: address,
              district: district,
              city: city,
              latitude: lat,
              longitude: lng,
              rating: 0.0,
              reviewCount: 0,
              machineModel: 'Chưa cập nhật thông tin máy đan',
              stringerCert: 'Chưa cập nhật chứng chỉ thợ đan',
              phone: tags['phone']?.toString() ??
                  tags['contact:phone']?.toString() ??
                  'Chưa cập nhật',
              openHours: tags['opening_hours']?.toString() ?? 'Chưa cập nhật',
              imageUrl: '',
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
