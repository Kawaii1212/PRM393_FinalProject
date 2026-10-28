import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/shop_model.dart';
import '../../providers/shop_provider.dart';
import '../../providers/chat_provider.dart';
import '../../theme/app_theme.dart';
import 'shop_detail_screen.dart';
import '../chat/chat_screen.dart';

enum MapStyleMode {
  osmStandard,
  cartoVoyager,
  cartoDark;

  String get label {
    switch (this) {
      case MapStyleMode.osmStandard:
        return 'OpenStreetMap (Tiêu chuẩn)';
      case MapStyleMode.cartoVoyager:
        return 'Bản đồ Sáng (Voyager)';
      case MapStyleMode.cartoDark:
        return 'Bản đồ Tối (Dark Mode)';
    }
  }

  String get urlTemplate {
    switch (this) {
      case MapStyleMode.osmStandard:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case MapStyleMode.cartoVoyager:
        return 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';
      case MapStyleMode.cartoDark:
        return 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';
    }
  }
}

class ShopMapScreen extends StatefulWidget {
  const ShopMapScreen({super.key});

  @override
  State<ShopMapScreen> createState() => _ShopMapScreenState();
}

class _ShopMapScreenState extends State<ShopMapScreen> {
  static const List<double> _radiusOptions = [1.0, 2.0, 5.0, 10.0, 20.0];

  final MapController _mapController = MapController();
  double _currentZoom = 14.3;
  // Mặc định ban đầu trong mục bản đồ là bán kính 2 km
  double _selectedRadiusKm = 2.0;
  MapStyleMode _mapStyle = MapStyleMode.osmStandard;

  /// Tính toán mức zoom bản đồ phù hợp với từng bán kính (km)
  double _zoomForRadius(double radiusKm) {
    if (radiusKm <= 1.0) return 15.2;
    if (radiusKm <= 2.0) return 14.3;
    if (radiusKm <= 5.0) return 13.0;
    if (radiusKm <= 10.0) return 12.0;
    return 11.0;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initNearbyLocation();
    });
  }

  Future<void> _initNearbyLocation({bool forceRefresh = false}) async {
    final shopProvider = context.read<ShopProvider>();
    // Đảm bảo ban đầu chưa chọn cửa hàng nào để ẩn khung giới thiệu cho tới khi người dùng click
    shopProvider.clearSelection();
    final userPos = await shopProvider.locateUserAndLoadNearbyShops(
      forceRefresh: forceRefresh,
    );
    if (!mounted) return;
    _mapController.move(userPos, _currentZoom);
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _onShopTapped(Shop shop) {
    context.read<ShopProvider>().selectShop(shop);
    _mapController.move(LatLng(shop.latitude, shop.longitude), 15.3);
  }

  void _moveToUserLocation() {
    _initNearbyLocation(forceRefresh: true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đang định vị và tải các cửa hàng cầu lông gần bạn... 📍'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  /// Mở ứng dụng Google Maps chỉ đường từ vị trí hiện tại tới cửa hàng
  Future<void> _openMapDirections(Shop shop, LatLng userLocation) async {
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&origin=${userLocation.latitude},${userLocation.longitude}&destination=${shop.latitude},${shop.longitude}&travelmode=driving',
    );
    try {
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Tọa độ của ${shop.name}: ${shop.latitude.toStringAsFixed(4)}, ${shop.longitude.toStringAsFixed(4)}',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tọa độ của ${shop.name}: ${shop.latitude.toStringAsFixed(4)}, ${shop.longitude.toStringAsFixed(4)}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopProvider = context.watch<ShopProvider>();
    // Lọc các cửa hàng cầu lông theo khoảng cách bán kính đã chọn (mặc định ban đầu là 2 km)
    final shops = shopProvider.shops
        .where((s) => s.distanceKm <= _selectedRadiusKm)
        .toList();
    final rawSelected = shopProvider.selectedShop;
    final selectedShop = (rawSelected != null &&
            rawSelected.distanceKm <= _selectedRadiusKm)
        ? rawSelected
        : null;
    final userLocation = shopProvider.userLocation;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cửa Hàng Cầu Lông Gần Bạn'),
        actions: [
          // Nút chuyển kiểu giao diện bản đồ (OpenStreetMap / Voyager / Dark)
          PopupMenuButton<MapStyleMode>(
            tooltip: 'Chọn kiểu bản đồ',
            icon: const Icon(
              Icons.layers_outlined,
              color: AppTheme.primaryDark,
            ),
            color: AppTheme.surface,
            onSelected: (mode) => setState(() => _mapStyle = mode),
            itemBuilder: (_) => MapStyleMode.values
                .map(
                  (m) => PopupMenuItem(
                    value: m,
                    child: Row(
                      children: [
                        Icon(
                          _mapStyle == m
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: _mapStyle == m
                              ? AppTheme.primary
                              : AppTheme.textMuted,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          m.label,
                          style: const TextStyle(color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          // Nút xem nhanh các shop tại khu vực trung tâm Hà Nội
          IconButton(
            tooltip: 'Xem khu vực trung tâm Hà Nội',
            icon: const Icon(Icons.location_city_rounded, color: AppTheme.accent),
            onPressed: () {
              _mapController.move(const LatLng(21.0271, 105.7733), 13.5);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Đang xem các Cửa Hàng Cầu Lông khu vực trung tâm Hà Nội 🏸',
                  ),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          // Nút định vị lại vị trí của tôi
          IconButton(
            tooltip: 'Định vị lại vị trí của tôi',
            icon: shopProvider.isLocating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primary,
                    ),
                  )
                : const Icon(
                    Icons.my_location_rounded,
                    color: AppTheme.primary,
                  ),
            onPressed: shopProvider.isLocating ? null : _moveToUserLocation,
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. BẢN ĐỒ TƯƠNG TÁC FLUTTER_MAP + LATLONG2
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: userLocation,
              initialZoom: _currentZoom,
              minZoom: 5.0,
              maxZoom: 18.5,
              onTap: (_, _) => shopProvider.clearSelection(),
              onLongPress: (_, latLng) {
                shopProvider.updateUserLocation(latLng);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Đã cập nhật vị trí của bạn & tìm các cửa hàng cầu lông xung quanh!',
                    ),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _mapStyle.urlTemplate,
                userAgentPackageName: 'com.example.finalproject',
              ),

              // Vòng tròn bán kính hiển thị các shop cầu lông quanh người dùng (mặc định 2 km)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: userLocation,
                    radius: _selectedRadiusKm * 1000,
                    useRadiusInMeter: true,
                    color: AppTheme.primary.withOpacity(0.10),
                    borderColor: AppTheme.primaryDark.withOpacity(0.55),
                    borderStrokeWidth: 1.8,
                  ),
                ],
              ),

              // Chỉ vẽ đường nối khi người dùng đã click chọn một cửa hàng trên bản đồ
              if (selectedShop != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [
                        userLocation,
                        LatLng(selectedShop.latitude, selectedShop.longitude),
                      ],
                      strokeWidth: 4.0,
                      color: AppTheme.primaryDark.withOpacity(0.9),
                    ),
                  ],
                ),

              // MarkerLayer
              MarkerLayer(
                markers: [
                  // Marker vị trí hiện tại của người dùng
                  Marker(
                    point: userLocation,
                    width: 115,
                    height: 62,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black45,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Text(
                            'Vị trí của bạn',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.3),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Center(
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: AppTheme.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Marker của các Cửa Hàng Cầu Lông
                  for (int i = 0; i < shops.length; i++) ...[
                    () {
                      final shop = shops[i];
                      final isSelected = selectedShop?.id == shop.id;
                      final isTop3 = i < 3;

                      if (isSelected) {
                        return Marker(
                          point: LatLng(shop.latitude, shop.longitude),
                          width: 180,
                          height: 74,
                          child: GestureDetector(
                            onTap: () => _onShopTapped(shop),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.black,
                                      width: 1.5,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black54,
                                        blurRadius: 6,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.sports_tennis_rounded,
                                        color: Colors.black,
                                        size: 13,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          '${shop.name.split('-').first.trim()} (${shop.distanceKm}km)',
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.location_on_rounded,
                                  color: AppTheme.danger,
                                  size: 34,
                                ),
                              ],
                            ),
                          ),
                        );
                      } else if (isTop3) {
                        return Marker(
                          point: LatLng(shop.latitude, shop.longitude),
                          width: 140,
                          height: 60,
                          child: GestureDetector(
                            onTap: () => _onShopTapped(shop),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surface.withOpacity(0.95),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: AppTheme.primary,
                                      width: 1.2,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black45,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '${shop.name.split('-').first.trim()} • ${shop.distanceKm}km',
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(
                                  Icons.location_on_rounded,
                                  color: AppTheme.primary,
                                  size: 26,
                                ),
                              ],
                            ),
                          ),
                        );
                      } else {
                        return Marker(
                          point: LatLng(shop.latitude, shop.longitude),
                          width: 32,
                          height: 32,
                          child: GestureDetector(
                            onTap: () => _onShopTapped(shop),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.primary,
                                  width: 1.8,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black45,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.sports_tennis_rounded,
                                  color: AppTheme.primary,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                    }(),
                  ],
                ],
              ),
            ],
          ),

          // 2. Dải Gợi Ý Các Cửa Hàng Cầu Lông Gần Vị Trí Của Bạn
          Positioned(
            top: 12,
            left: 14,
            right: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surface.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.my_location_rounded,
                            color: AppTheme.accent,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Vị trí của bạn: ${shopProvider.userAreaLabel}',
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${shops.length} shop',
                              style: const TextStyle(
                                color: AppTheme.primaryDark,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.radar_rounded,
                            color: AppTheme.primaryDark,
                            size: 15,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Bán kính:',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _radiusOptions.map((r) {
                                  final isSelectedRadius =
                                      _selectedRadiusKm == r;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: () {
                                        setState(() {
                                          _selectedRadiusKm = r;
                                          _currentZoom = _zoomForRadius(r);
                                        });
                                        if (shopProvider.selectedShop != null &&
                                            shopProvider
                                                    .selectedShop!.distanceKm >
                                                r) {
                                          shopProvider.clearSelection();
                                        }
                                        _mapController.move(
                                          userLocation,
                                          _currentZoom,
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelectedRadius
                                              ? AppTheme.primary
                                              : AppTheme.surfaceLight,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isSelectedRadius
                                                ? AppTheme.primaryDark
                                                : AppTheme.border,
                                          ),
                                        ),
                                        child: Text(
                                          '${r.toInt()} km',
                                          style: TextStyle(
                                            color: isSelectedRadius
                                                ? Colors.black
                                                : AppTheme.textSecondary,
                                            fontSize: 11.5,
                                            fontWeight: isSelectedRadius
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Thông báo khi không có shop trong bán kính
                if (shops.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surface.withOpacity(0.94),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Text(
                      'Chưa có cửa hàng nào trong bán kính ${_selectedRadiusKm.toInt()} km. Bạn có thể chọn bán kính lớn hơn ở trên.',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 54,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: shops.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (ctx, i) {
                        final shop = shops[i];
                        final isSelected = selectedShop?.id == shop.id;
                        return InkWell(
                          onTap: () => _onShopTapped(shop),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primary
                                  : AppTheme.surface.withOpacity(0.94),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primary
                                    : AppTheme.border,
                                width: isSelected ? 1.5 : 1.0,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black38,
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.storefront_rounded,
                                  size: 18,
                                  color: isSelected
                                      ? Colors.black
                                      : AppTheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${shop.name.split('-').first.trim()} • ${shop.distanceKm} km',
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.black
                                            : AppTheme.textPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.place_outlined,
                                          size: 11,
                                          color: isSelected
                                              ? Colors.black87
                                              : AppTheme.textSecondary,
                                        ),
                                        const SizedBox(width: 2),
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 170,
                                          ),
                                          child: Text(
                                            shop.address,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? Colors.black87
                                                  : AppTheme.textSecondary,
                                              fontSize: 10.5,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // 3. Cụm nút Zoom (+/-) bên phải bản đồ
          Positioned(
            right: 14,
            top: 158,
            child: Column(
              children: [
                _MapControlBtn(
                  icon: Icons.add_rounded,
                  onTap: () {
                    _currentZoom = (_mapController.camera.zoom + 1.0).clamp(
                      5.0,
                      18.5,
                    );
                    _mapController.move(
                      _mapController.camera.center,
                      _currentZoom,
                    );
                  },
                ),
                const SizedBox(height: 8),
                _MapControlBtn(
                  icon: Icons.remove_rounded,
                  onTap: () {
                    _currentZoom = (_mapController.camera.zoom - 1.0).clamp(
                      5.0,
                      18.5,
                    );
                    _mapController.move(
                      _mapController.camera.center,
                      _currentZoom,
                    );
                  },
                ),
              ],
            ),
          ),

          // 4. Phần giới thiệu cửa hàng: CHỈ HIỂN THỊ KHI CLICK VÀO CỬA HÀNG
          if (selectedShop != null)
            Positioned(
              bottom: 14,
              left: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface.withOpacity(0.97),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.primary.withOpacity(0.6),
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.storefront_rounded,
                            color: AppTheme.primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedShop.name,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${selectedShop.address} • Cách ${selectedShop.distanceKm} km',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: AppTheme.accent,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${selectedShop.rating}',
                                style: const TextStyle(
                                  color: AppTheme.accent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => shopProvider.clearSelection(),
                          borderRadius: BorderRadius.circular(20),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.close_rounded,
                              color: AppTheme.textMuted,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Machine Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.precision_manufacturing_rounded,
                            color: AppTheme.primary,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${selectedShop.machineModel} • ${selectedShop.openHours}',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ShopDetailScreen(shopId: selectedShop.id),
                                ),
                              );
                            },
                            child: const Text('Xem Dịch Vụ & Trưng Bày'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Mở bản đồ chỉ đường',
                          onPressed: () =>
                              _openMapDirections(selectedShop, userLocation),
                          icon: const Icon(
                            Icons.directions_rounded,
                            color: AppTheme.primary,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: AppTheme.surfaceLight,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: AppTheme.primary),
                            ),
                            padding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Nhắn tin với cửa hàng',
                          onPressed: () {
                            final chatProvider = context.read<ChatProvider>();
                            final thread = chatProvider.getOrCreateThreadForShop(
                              selectedShop.id,
                              selectedShop.name,
                              selectedShop.imageUrl,
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatConversationScreen(
                                  threadId: thread.id,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: AppTheme.primaryDark,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: AppTheme.surfaceLight,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: AppTheme.border),
                            ),
                            padding: const EdgeInsets.all(12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MapControlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapControlBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface.withOpacity(0.92),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Icon(icon, color: AppTheme.textPrimary, size: 22),
        ),
      ),
    );
  }
}