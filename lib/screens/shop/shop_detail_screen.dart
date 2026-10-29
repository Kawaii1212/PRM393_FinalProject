import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/product_model.dart';
import '../../models/shop_model.dart';
import '../../providers/shop_provider.dart';
import '../../providers/chat_provider.dart';
import '../../theme/app_theme.dart';
import '../chat/chat_screen.dart';

class ShopDetailScreen extends StatefulWidget {
  final String shopId;

  const ShopDetailScreen({super.key, required this.shopId});

  @override
  State<ShopDetailScreen> createState() => _ShopDetailScreenState();
}

class _ShopDetailScreenState extends State<ShopDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openChatWithInquiry(Shop shop, Product item) {
    if (!shop.isVerifiedPartner) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            shop.isRegisteredOnApp
                ? 'Cửa hàng này đang chờ Admin phê duyệt nên chưa thể nhận tin nhắn!'
                : 'Cửa hàng này là địa điểm Google Maps chưa đăng ký tài khoản trên app. Chỉ có thể nhắn tin với Shop đối tác đã được Admin phê duyệt.',
          ),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }
    final chatProvider = context.read<ChatProvider>();
    final thread = chatProvider.getOrCreateThreadForShop(
      shop.id,
      shop.name,
      shop.imageUrl,
    );

    // Gửi tự động tin nhắn hỏi về sản phẩm trưng bày
    chatProvider.sendMessage(
      thread.id,
      'Chào shop, em đang quan tâm đến "${item.name}" (giá ${_currencyFormat.format(item.price)}). Shop tư vấn thêm giúp em nhé!',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatConversationScreen(
          threadId: thread.id,
          shopId: shop.id,
        ),
      ),
    );
  }

  Future<void> _openDirections(Shop shop) async {
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${shop.latitude},${shop.longitude}&travelmode=driving',
    );
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Widget _buildProductThumbnail(String imageUrl, {bool isService = false, double size = 52}) {
    if (imageUrl.trim().isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Icon(
          isService ? Icons.flash_on_rounded : Icons.sports_tennis_rounded,
          color: AppTheme.primary,
          size: 26,
        ),
      );
    }

    final trimmed = imageUrl.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          trimmed,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            width: size,
            height: size,
            color: AppTheme.surfaceLight,
            child: const Icon(Icons.broken_image_rounded, color: AppTheme.textMuted, size: 22),
          ),
        ),
      );
    }

    final file = File(trimmed);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        file,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: size,
          height: size,
          color: AppTheme.surfaceLight,
          child: const Icon(Icons.image_not_supported_rounded, color: AppTheme.textMuted, size: 22),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shopProvider = context.watch<ShopProvider>();
    final shop = shopProvider.getShopById(widget.shopId) ??
        (shopProvider.shops.isNotEmpty ? shopProvider.shops.first : null);

    if (shop == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi Tiết Cửa Hàng')),
        body: const Center(
          child: Text('Không tìm thấy thông tin cửa hàng này.'),
        ),
      );
    }

    // Với các shop có sẵn trên database (chưa đăng ký trên app), chỉ có nút mở Google Maps
    if (!shop.isVerifiedPartner) {
      return Scaffold(
        appBar: AppBar(title: Text(shop.name)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.map_rounded, size: 54, color: AppTheme.primary),
                ),
                const SizedBox(height: 18),
                Text(
                  shop.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '${shop.address} • Cách bạn ${shop.distanceKm} km',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: const Text(
                    'Đây là địa điểm tham khảo được ghi nhận từ dữ liệu Google Maps. Cửa hàng chưa có chủ shop đăng ký gian hàng trên ứng dụng nên chưa thể xem sản phẩm và dịch vụ trực tuyến.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted, height: 1.4),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openDirections(shop),
                    icon: const Icon(Icons.directions_rounded, color: Colors.black),
                    label: const Text('Dẫn Đường Trực Tiếp Sang Google Maps 🗺️', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final services = shopProvider.getServicesForShop(shop.id);
    final accessories = shopProvider.getAccessoriesForShop(shop.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(shop.name),
        actions: [
          IconButton(
            tooltip: 'Nhắn tin với shop',
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.primary),
            onPressed: () {
              if (!shop.isVerifiedPartner) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      shop.isRegisteredOnApp
                          ? 'Cửa hàng này đang chờ Admin phê duyệt nên chưa thể nhận tin nhắn!'
                          : 'Cửa hàng này là địa điểm Google Maps chưa đăng ký tài khoản trên app. Chỉ có thể nhắn tin với Shop đối tác đã được Admin phê duyệt.',
                    ),
                    backgroundColor: AppTheme.danger,
                  ),
                );
                return;
              }
              final chatProvider = context.read<ChatProvider>();
              final thread = chatProvider.getOrCreateThreadForShop(
                shop.id,
                shop.name,
                shop.imageUrl,
              );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatConversationScreen(
                    threadId: thread.id,
                    shopId: shop.id,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(16),
                color: AppTheme.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Shop
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
                          ),
                          child: const Icon(Icons.storefront_rounded, color: AppTheme.primary, size: 32),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                shop.name,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.star_rounded, color: AppTheme.accent, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${shop.rating} (${shop.reviewCount} đánh giá)',
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.location_on, color: AppTheme.primaryDark, size: 14),
                                  Text(
                                    'Cách ${shop.distanceKm} km',
                                    style: const TextStyle(
                                      color: AppTheme.primaryDark,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Địa chỉ & Giờ mở cửa
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.place_outlined, size: 15, color: AppTheme.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${shop.address}, ${shop.district}, ${shop.city}',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded, size: 15, color: AppTheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Giờ mở cửa: ${shop.openHours}',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Machine & Stringer info banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.precision_manufacturing_rounded, color: AppTheme.primary, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  shop.machineModel,
                                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.verified_rounded, color: AppTheme.primaryDark, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  shop.stringerCert,
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Cụm nút liên hệ: Nhắn tin + Gọi hotline + Chỉ đường
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final chatProvider = context.read<ChatProvider>();
                              final thread = chatProvider.getOrCreateThreadForShop(
                                shop.id,
                                shop.name,
                                shop.imageUrl,
                              );
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatConversationScreen(threadId: thread.id),
                                ),
                              );
                            },
                            icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                            label: const Text('Nhắn Tin Tư Vấn', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (shop.phone.isNotEmpty && shop.phone != 'Chưa cập nhật') ...[
                          IconButton(
                            tooltip: 'Gọi hotline',
                            onPressed: () => launchUrl(Uri.parse('tel:${shop.phone}')),
                            icon: const Icon(Icons.phone_rounded, color: AppTheme.primary),
                            style: IconButton.styleFrom(
                              backgroundColor: AppTheme.surfaceLight,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: AppTheme.border),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        IconButton(
                          tooltip: 'Chỉ đường đến shop',
                          onPressed: () => _openDirections(shop),
                          icon: const Icon(Icons.directions_rounded, color: AppTheme.primaryDark),
                          style: IconButton.styleFrom(
                            backgroundColor: AppTheme.surfaceLight,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: AppTheme.border),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Ghi chú hình thức trưng bày
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.primary),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Shop trưng bày sản phẩm & bảng giá. Vui lòng nhắn tin hoặc ghé shop để được phục vụ.',
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: AppTheme.primary,
                  labelColor: AppTheme.primary,
                  unselectedLabelColor: AppTheme.textMuted,
                  tabs: const [
                    Tab(icon: Icon(Icons.handyman_rounded), text: 'Dịch Vụ Đan Cước'),
                    Tab(icon: Icon(Icons.sports_tennis_rounded), text: 'Vật Phẩm Trưng Bày'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            // Services list
            services.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Cửa hàng này hiện chưa cập nhật danh sách dịch vụ đan cước.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: services.length,
                    itemBuilder: (context, idx) {
                      final srv = services[idx];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildProductThumbnail(srv.imageUrl, isService: true),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    srv.name,
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    srv.description,
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _currencyFormat.format(srv.price),
                                    style: const TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => _openChatWithInquiry(shop, srv),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                              ),
                              child: const Text('Hỏi Shop 💬'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

            // Accessories & Rackets list
            accessories.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Cửa hàng này hiện chưa cập nhật danh sách vật phẩm trưng bày.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: accessories.length,
                    itemBuilder: (context, idx) {
                      final prod = accessories[idx];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildProductThumbnail(prod.imageUrl, isService: false),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    prod.name,
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    prod.categoryName,
                                    style: const TextStyle(color: AppTheme.primaryDark, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    prod.description,
                                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _currencyFormat.format(prod.price),
                                    style: const TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => _openChatWithInquiry(shop, prod),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                              ),
                              child: const Text('Hỏi Shop 💬'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppTheme.surface,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
