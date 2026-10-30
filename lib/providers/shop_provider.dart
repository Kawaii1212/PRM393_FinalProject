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

  /// Số lượng Shop đối tác chính thức đã đăng ký trên app và được Admin phê duyệt (isVerifiedPartner)
  int get verifiedShopsCount =>
      allShopsForAdmin.where((s) => s.isVerifiedPartner).length;

  /// Số lượng Shop địa điểm Google Maps đang hiển thị hoạt động trên bản đồ (chưa có tài khoản chủ shop)
  int get mapsShopsCount =>
      allShopsForAdmin.where((s) => !s.isRegisteredOnApp && s.isApproved).length;

  /// Danh sách các Shop đối tác thực tế đã đăng ký tài khoản trên app và được Admin phê duyệt (isVerifiedPartner)
  /// Không bao gồm các địa điểm hiển thị trên Google Maps (CSV) chưa có tài khoản chủ shop
  List<Shop> get approvedShops {
    final verified = _firestoreShops.where((s) => s.isVerifiedPartner).toList();
    if (verified.isNotEmpty) return verified;
    return allShopsForAdmin.where((s) => s.isVerifiedPartner).toList();
  }

  /// Tìm cửa hàng của Chủ Shop đang đăng nhập (`ownerUid`)
  Shop? getShopForOwner(String ownerUid) {
    try {
      return _firestoreShops.firstWhere((s) => s.ownerUid == ownerUid);
    } catch (_) {
      return null;
    }
  }

  /// Trích xuất tọa độ (lat, lng) từ URL Google Maps hoặc chuỗi tọa độ nhập trực tiếp
  Future<LatLng?> extractCoordinatesFromGoogleMapsUrl(String input) async {
    final raw = input.trim();
    if (raw.isEmpty) return null;

    // 1. Kiểm tra nếu nhập trực tiếp dạng "lat, lng" (ví dụ: "21.01234, 105.5253")
    final directCoordRegex = RegExp(r'^([-+]?[0-9]*\.?[0-9]+)\s*,\s*([-+]?[0-9]*\.?[0-9]+)$');
    final directMatch = directCoordRegex.firstMatch(raw);
    if (directMatch != null) {
      final lat = double.tryParse(directMatch.group(1)!);
      final lng = double.tryParse(directMatch.group(2)!);
      if (lat != null && lng != null && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
        return LatLng(lat, lng);
      }
    }

    String urlToParse = raw;

    // 2. Nếu là link rút gọn (maps.app.goo.gl hoặc goo.gl/maps), gọi HTTP để lấy link đích sau khi redirect
    if (raw.contains('maps.app.goo.gl') || raw.contains('goo.gl/maps')) {
      try {
        final client = http.Client();
        final uri = Uri.parse(raw.startsWith('http') ? raw : 'https://$raw');
        final request = http.Request('GET', uri)..followRedirects = true;
        final response = await client.send(request).timeout(const Duration(seconds: 5));
        urlToParse = response.request?.url.toString() ?? urlToParse;
        client.close();
      } catch (e) {
        debugPrint('Lỗi giải mã redirect short URL Google Maps: $e');
      }
    }

    // 3. Phân tích các định dạng URL Google Maps phổ biến:
    // a) @lat,lng,zoom (ví dụ: /@21.012423,105.525312,17z)
    final atRegex = RegExp(r'@([-+]?[0-9]*\.?[0-9]+),([-+]?[0-9]*\.?[0-9]+)');
    final atMatch = atRegex.firstMatch(urlToParse);
    if (atMatch != null) {
      final lat = double.tryParse(atMatch.group(1)!);
      final lng = double.tryParse(atMatch.group(2)!);
      if (lat != null && lng != null && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
        return LatLng(lat, lng);
      }
    }

    // b) Tham số truy vấn q=lat,lng hoặc query=lat,lng hoặc ll=lat,lng hoặc destination=lat,lng
    final queryParamRegex = RegExp(r'[?&](?:q|query|ll|center|destination)=([-+]?[0-9]*\.?[0-9]+),([-+]?[0-9]*\.?[0-9]+)');
    final queryMatch = queryParamRegex.firstMatch(urlToParse);
    if (queryMatch != null) {
      final lat = double.tryParse(queryMatch.group(1)!);
      final lng = double.tryParse(queryMatch.group(2)!);
      if (lat != null && lng != null && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
        return LatLng(lat, lng);
      }
    }

    // c) Tìm bất kỳ cặp số thực dạng kinh/vĩ độ trong URL dạng embed !3d lat !4d lng
    final dataParamRegex = RegExp(r'!3d([-+]?[0-9]*\.?[0-9]+)!4d([-+]?[0-9]*\.?[0-9]+)');
    final dataMatch = dataParamRegex.firstMatch(urlToParse);
    if (dataMatch != null) {
      final lat = double.tryParse(dataMatch.group(1)!);
      final lng = double.tryParse(dataMatch.group(2)!);
      if (lat != null && lng != null && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
        return LatLng(lat, lng);
      }
    }

    return null;
  }

  /// Kiểm tra xem tọa độ (latitude, longitude) có bị trùng lặp với bất kỳ cửa hàng nào trong hệ thống
  /// Ngưỡng mặc định là 25 mét (thresholdMeters).
  Shop? findDuplicateShopByLocation(
    double latitude,
    double longitude, {
    double thresholdMeters = 25.0,
    String? excludeShopId,
  }) {
    const Distance distanceCalc = Distance();
    final targetPos = LatLng(latitude, longitude);

    for (final s in allShopsForAdmin) {
      if (excludeShopId != null && s.id == excludeShopId) continue;

      if ((s.latitude - latitude).abs() > 0.005 || (s.longitude - longitude).abs() > 0.005) {
        continue;
      }

      final distMeters = distanceCalc.as(
        LengthUnit.Meter,
        targetPos,
        LatLng(s.latitude, s.longitude),
      );

      if (distMeters <= thresholdMeters) {
        return s;
      }
    }
    return null;
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
      final distMeters = distanceCalc.as(
        LengthUnit.Meter,
        _userLocation,
        LatLng(s.latitude, s.longitude),
      );
      return s.copyWith(
        distanceKm: double.parse((distMeters / 1000.0).toStringAsFixed(1)),
      );
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

  /// Admin phê duyệt (`approved`) hoặc vô hiệu hóa (`disabled`) Cửa hàng theo shopId
  Future<void> approveShop(String shopId, bool isDisabling) async {
    final shop = getShopById(shopId);
    if (shop != null) {
      await updateShopStatus(shop, isDisabling ? 'disabled' : 'approved');
    }
  }

  /// Admin phê duyệt (`approved`) hoặc vô hiệu hóa (`disabled`) Cửa hàng
  /// Khi vô hiệu hóa shop, toàn bộ sản phẩm của shop sẽ tạm thời bị vô hiệu hóa theo (Cascade Deactivate)
  Future<void> updateShopStatus(Shop shop, String newStatus) async {
    final updated = shop.copyWith(status: newStatus);
    await upsertShop(updated);

    final isDisabling = (newStatus == 'disabled');
    for (int i = 0; i < _products.length; i++) {
      if (_products[i].shopId == shop.id) {
        _products[i] = _products[i].copyWith(
          status: isDisabling ? 'rejected' : 'approved',
        );
      }
    }
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefProductsKey,
        jsonEncode(_products.map((p) => p.toMap()).toList()),
      );

      if (_isFirebaseReady) {
        final firestore = FirebaseFirestore.instance;
        final prodsSnap = await firestore
            .collection('products')
            .where('shopId', isEqualTo: shop.id)
            .get()
            .timeout(const Duration(seconds: 5));

        if (prodsSnap.docs.isNotEmpty) {
          final batch = firestore.batch();
          for (final doc in prodsSnap.docs) {
            batch.update(doc.reference, {
              'status': isDisabling ? 'rejected' : 'approved',
            });
          }
          await batch.commit().timeout(const Duration(seconds: 5));
        }
      }
    } catch (e) {
      debugPrint('updateShopStatus cascade products error: $e');
    }
  }

  /// Xóa Cửa hàng và toàn bộ Sản phẩm/Dịch vụ liên quan khỏi Cloud Firestore (Cascade Delete)
  Future<void> deleteShop(String shopId) async {
    _firestoreShops.removeWhere((s) => s.id == shopId);
    _discoveredShops.removeWhere((s) => s.id == shopId);
    _allShops.removeWhere((s) => s.id == shopId);
    _shops.removeWhere((s) => s.id == shopId);

    // Xóa toàn bộ sản phẩm và dịch vụ của shop này khỏi bộ nhớ ứng dụng
    _products.removeWhere((p) => p.shopId == shopId);

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
      await prefs.setString(
        _prefProductsKey,
        jsonEncode(_products.map((p) => p.toMap()).toList()),
      );

      if (_isFirebaseReady) {
        final firestore = FirebaseFirestore.instance;
        final batch = firestore.batch();

        // 1. Xóa document cửa hàng trong collection 'shops'
        final shopDocRef = firestore.collection('shops').doc(shopId);
        batch.delete(shopDocRef);

        // 2. Tìm và xóa toàn bộ sản phẩm thuộc shopId trong collection 'products'
        final prodsSnap = await firestore
            .collection('products')
            .where('shopId', isEqualTo: shopId)
            .get()
            .timeout(const Duration(seconds: 5));

        for (final doc in prodsSnap.docs) {
          batch.delete(doc.reference);
        }

        await batch.commit().timeout(const Duration(seconds: 6));
      }
    } catch (e) {
      debugPrint('deleteShop cascade delete error: $e');
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
  /// Khi shop bị xóa hoặc bị vô hiệu hóa -> Toàn bộ sản phẩm sẽ biến mất khỏi danh mục Người chơi
  List<Product> getProductsForShop(String shopId) {
    final targetShop = getShopById(shopId);
    if (targetShop == null || !targetShop.isApproved) {
      return [];
    }

    final custom = _products
        .where(
          (p) =>
              (p.shopId == shopId || p.shopId == 'all') && !p.isRejected,
        )
        .toList();
    return custom;
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

    // 2. Tự động tìm thêm qua Google Places API nếu có cấu hình API Key, hoặc dự phòng qua Overpass POI
    try {
      List<Shop> places = await _fetchFromGooglePlacesNew(center);
      if (places.isEmpty) {
        places = await _fetchFromGooglePlacesLegacy(center);
      }
      if (places.isEmpty) {
        places = await _fetchRealPOIShopsFallback(center);
      }
      for (final s in places) {
        baseShopMap[s.id] = s;
      }
    } catch (e) {
      debugPrint('Google Places / POI search note: $e');
    }

    // 3. Tính khoảng cách thực tế từ vị trí người dùng đến từng shop
    final computedShops = baseShopMap.values.map((s) {
      final distMeters = distanceCalc.as(
        LengthUnit.Meter,
        center,
        LatLng(s.latitude, s.longitude),
      );
      return s.copyWith(
        distanceKm: double.parse((distMeters / 1000.0).toStringAsFixed(1)),
      );
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
    // 1. Thử giải mã địa chỉ tiếng Việt qua BigDataCloud Free Client Reverse Geocoding API (nhanh, miễn phí, không chặn ở VN)
    try {
      final url = Uri.parse(
        'https://api-bdc.io/data/reverse-geocode-client?latitude=$lat&longitude=$lng&localityLanguage=vi',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final city = data['principalSubdivision']?.toString() ??
            data['city']?.toString() ??
            '';
        final locality = data['locality']?.toString() ?? '';

        String district = '';
        if (data['localityInfo'] != null &&
            data['localityInfo']['administrative'] is List) {
          final admin = data['localityInfo']['administrative'] as List;
          for (final item in admin.reversed) {
            final desc = item['description']?.toString().toLowerCase() ?? '';
            final name = item['name']?.toString() ?? '';
            if (desc.contains('quận') ||
                desc.contains('huyện') ||
                desc.contains('thị xã') ||
                desc.contains('thành phố thuộc') ||
                name.startsWith('Quận') ||
                name.startsWith('Huyện')) {
              district = name;
              break;
            }
          }
        }

        final parts = <String>[
          if (locality.isNotEmpty) locality,
          if (district.isNotEmpty && district != locality) district,
          if (city.isNotEmpty && city != district) city,
        ];

        if (parts.isNotEmpty) {
          return {
            'shortAddress': parts.join(', '),
            'district': district.isNotEmpty ? district : locality,
            'city': city.isNotEmpty ? city : 'Việt Nam',
          };
        }
      }
    } catch (e) {
      debugPrint('Reverse geocode BDC note: $e');
    }

    // 2. Dự phòng: Tìm cửa hàng cầu lông gần nhất trong database để xác định Quận/Huyện và Thành phố
    try {
      const Distance distanceCalc = Distance();
      Shop? nearestShop;
      double minDistance = double.infinity;
      for (final s in [...HcmShopData.shops, ...CsvShopData.shops]) {
        final d = distanceCalc.as(
          LengthUnit.Kilometer,
          LatLng(lat, lng),
          LatLng(s.latitude, s.longitude),
        );
        if (d < minDistance) {
          minDistance = d;
          nearestShop = s;
        }
      }

      if (nearestShop != null && minDistance <= 8.0) {
        final district = nearestShop.district.isNotEmpty
            ? nearestShop.district
            : nearestShop.city;
        return {
          'shortAddress': '$district, ${nearestShop.city}',
          'district': district,
          'city': nearestShop.city,
        };
      }
    } catch (e) {
      debugPrint('Reverse geocode shop fallback note: $e');
    }

    // 3. Dự phòng theo phân vùng địa lý Việt Nam nếu offline hoàn toàn (Tuyệt đối không hiển thị tọa độ số)
    if (lat >= 20.0 && lat <= 22.0) {
      return {
        'shortAddress': 'Hà Nội',
        'district': 'Hà Nội',
        'city': 'Hà Nội',
      };
    }
    if (lat >= 10.0 && lat <= 12.0) {
      return {
        'shortAddress': 'TP. Hồ Chí Minh',
        'district': 'TP. Hồ Chí Minh',
        'city': 'TP. Hồ Chí Minh',
      };
    }
    if (lat >= 15.5 && lat <= 16.5) {
      return {
        'shortAddress': 'Đà Nẵng',
        'district': 'Đà Nẵng',
        'city': 'Đà Nẵng',
      };
    }

    return {
      'shortAddress': 'Vị trí hiện tại của bạn',
      'district': 'Khu vực lân cận',
      'city': 'Việt Nam',
    };
  }
}
