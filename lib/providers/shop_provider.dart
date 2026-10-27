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

class ShopProvider with ChangeNotifier {
  static const String _prefShopsKey = 'gearsports_admin_shops';
  static const String _prefProductsKey = 'gearsports_admin_products';

  List<Shop> _shops = [];
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
    _shops = merged;
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
      try {
        return _firestoreShops.firstWhere((s) => s.id == id);
      } catch (_) {
        return null;
      }
    }
  }

  /// Lấy danh sách sản phẩm & dịch vụ hợp lệ hiển thị cho Người chơi
  List<Product> getProductsForShop(String shopId) {
    return _products
        .where(
          (p) =>
              (p.shopId == shopId || p.shopId == 'all') && !p.isRejected,
        )
        .toList();
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

    // Sắp xếp cửa hàng gần nhất lên đầu và gộp với cửa hàng trên Cloud Firestore
    discoveredShops.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    _discoveredShops = discoveredShops;
    _mergeFirestoreShopsIntoList();

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
    final List<Shop> result = [];

    for (int i = 0; i < places.length; i++) {
      final item = places[i] as Map<String, dynamic>;
      final loc = item['location'] as Map<String, dynamic>?;
      if (loc == null) continue;

      final lat = (loc['latitude'] as num?)?.toDouble();
      final lng = (loc['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;

      final displayNameObj = item['displayName'] as Map<String, dynamic>?;
      final name = displayNameObj?['text']?.toString() ?? 'Cửa hàng thể thao';
      final address =
          item['formattedAddress']?.toString() ?? 'Khu vực $_userAreaLabel';
      final rating = (item['rating'] as num?)?.toDouble() ?? 0.0;
      final reviewCount = (item['userRatingCount'] as num?)?.toInt() ?? 0;
      final phone = item['nationalPhoneNumber']?.toString() ?? 'Chưa cập nhật';

      String openHours = 'Chưa cập nhật giờ mở cửa';
      final openingHoursObj =
          item['regularOpeningHours'] as Map<String, dynamic>?;
      if (openingHoursObj != null && openingHoursObj['openNow'] != null) {
        final isOpen = openingHoursObj['openNow'] == true;
        openHours = isOpen ? 'Đang mở cửa' : 'Đang đóng cửa';
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
          machineModel: 'Chưa cập nhật thông tin máy đan',
          stringerCert: 'Chưa cập nhật chứng chỉ thợ đan',
          phone: phone,
          openHours: openHours,
          imageUrl: '',
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
    final List<Shop> list = [];

    for (int i = 0; i < results.length && i < 10; i++) {
      final item = results[i] as Map<String, dynamic>;
      final geometry = item['geometry'] as Map<String, dynamic>?;
      final loc = geometry?['location'] as Map<String, dynamic>?;
      if (loc == null) continue;

      final lat = (loc['lat'] as num?)?.toDouble();
      final lng = (loc['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;

      final name = item['name']?.toString() ?? 'Cửa hàng thể thao';
      final address = item['formatted_address']?.toString() ??
          item['vicinity']?.toString() ??
          'Khu vực $_userAreaLabel';
      final rating = (item['rating'] as num?)?.toDouble() ?? 0.0;
      final reviewCount = (item['user_ratings_total'] as num?)?.toInt() ?? 0;

      String openHours = 'Chưa cập nhật giờ mở cửa';
      final openingHours = item['opening_hours'] as Map<String, dynamic>?;
      if (openingHours != null && openingHours['open_now'] != null) {
        openHours = openingHours['open_now'] == true
            ? 'Đang mở cửa'
            : 'Đang đóng cửa';
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
          machineModel: 'Chưa cập nhật thông tin máy đan',
          stringerCert: 'Chưa cập nhật chứng chỉ thợ đan',
          phone: 'Chưa cập nhật',
          openHours: openHours,
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

          final rawName = tags['name']?.toString().trim();
          if (rawName == null || rawName.isEmpty) continue;

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
