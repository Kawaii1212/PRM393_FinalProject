import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/shop_model.dart';
import '../../models/product_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shop_provider.dart';
import '../../providers/chat_provider.dart';
import '../../theme/app_theme.dart';
import '../chat/chat_screen.dart';
import '../auth/login_register_screen.dart';
import '../subscription/shop_subscription_dialog.dart';

class ShopOwnerDashboardScreen extends StatefulWidget {
  const ShopOwnerDashboardScreen({super.key});

  @override
  State<ShopOwnerDashboardScreen> createState() => _ShopOwnerDashboardScreenState();
}

class _ShopOwnerDashboardScreenState extends State<ShopOwnerDashboardScreen> {
  int _currentTabIndex = 0;
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  // Filters for Products/Services tab
  ProductCategory? _selectedCategoryFilter;
  String _productSearchQuery = '';

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final shopProvider = context.watch<ShopProvider>();
    final chatProvider = context.watch<ChatProvider>();
    final currentUser = authProvider.currentUser;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final myShop = shopProvider.getShopForOwner(currentUser.uid);
    final shopThreads = myShop != null ? chatProvider.getThreadsForShop(myShop.id) : chatProvider.threads;

    final tabs = [
      _buildOverviewTab(context, currentUser, myShop, shopThreads.length),
      _buildProductsTab(context, myShop),
      _buildChatTab(context, myShop, shopThreads),
      _buildAccountTab(context, currentUser, myShop),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.storefront_rounded, color: Colors.black, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    myShop?.name ?? 'Kênh Quản Trị Chủ Shop',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    myShop != null
                        ? 'Trạng thái: ${myShop.statusDisplayName}'
                        : 'Chủ shop: ${currentUser.fullName}',
                    style: TextStyle(
                      fontSize: 11,
                      color: myShop?.isApproved == true ? AppTheme.primary : AppTheme.accent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới dữ liệu',
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primary),
            onPressed: () async {
              await shopProvider.syncCatalogFromFirestore();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã đồng bộ dữ liệu mới nhất từ hệ thống!'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout_rounded, color: AppTheme.textSecondary),
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: myShop == null
          ? _buildNoShopState(context, currentUser)
          : IndexedStack(
              index: _currentTabIndex,
              children: tabs,
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (idx) => setState(() => _currentTabIndex = idx),
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppTheme.surface,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: AppTheme.textMuted,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Tổng quan',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_rounded),
            label: 'Vật phẩm',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.chat_bubble_rounded),
                if (chatProvider.unreadMessagesCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${chatProvider.unreadMessagesCount}',
                        style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Tin nhắn',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Tài khoản',
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: TỔNG QUAN CỬA HÀNG (OVERVIEW)
  // (Đã loại bỏ doanh thu, đơn chờ xử lý & lịch hẹn)
  // ==========================================
  Widget _buildOverviewTab(
    BuildContext context,
    UserModel currentUser,
    Shop? shop,
    int chatCount,
  ) {
    if (shop == null) return const SizedBox.shrink();

    final shopProvider = context.watch<ShopProvider>();
    final myProducts = shopProvider.getDirectProductsForShop(shop.id);
    final approvedProductsCount = myProducts.where((p) => p.isApproved).length;
    final pendingProductsCount = myProducts.where((p) => p.isPending).length;

    return RefreshIndicator(
      onRefresh: () async {
        await shopProvider.syncCatalogFromFirestore();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Thẻ Trạng Thái Gói Dịch Vụ / Dùng Thử Miễn Phí
          _buildShopSubscriptionCard(context, shop),
          const SizedBox(height: 14),

          // Banner trạng thái kiểm duyệt bởi Admin
          _buildShopStatusBanner(shop),
          const SizedBox(height: 16),

          // Card Hồ sơ Shop & Nút Chỉnh sửa thông tin
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppTheme.cardGradient,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        shop.name,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _showEditShopModal(context, shop),
                      icon: const Icon(Icons.edit_outlined, size: 15, color: AppTheme.primary),
                      label: const Text('Sửa hồ sơ', style: TextStyle(color: AppTheme.primary, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.primary),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _infoRow(Icons.location_on_outlined, '${shop.address}, ${shop.district}, ${shop.city}'),
                _infoRow(Icons.phone_outlined, 'Hotline: ${shop.phone}'),
                _infoRow(Icons.precision_manufacturing_rounded, 'Máy đan: ${shop.machineModel}'),
                _infoRow(Icons.workspace_premium_rounded, 'Chứng chỉ thợ: ${shop.stringerCert}'),
                _infoRow(Icons.schedule_rounded, 'Giờ hoạt động: ${shop.openHours}'),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Thống kê nhanh về Sản phẩm & Tương tác
          const Text(
            'Chỉ Số Trưng Bày & Hoạt Động',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  title: 'Vật phẩm & Dịch vụ',
                  value: '${myProducts.length} mục',
                  subtitle: '$approvedProductsCount đã duyệt • $pendingProductsCount chờ duyệt',
                  icon: Icons.inventory_2_rounded,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricCard(
                  title: 'Đánh giá uy tín',
                  value: '⭐ ${shop.rating}',
                  subtitle: '${shop.reviewCount} lượt đánh giá',
                  icon: Icons.star_rounded,
                  color: AppTheme.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Hướng dẫn mô hình trưng bày & tư vấn trực tiếp
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.info_outline_rounded, color: AppTheme.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Mô Hình Trưng Bày & Tư Vấn Trực Tiếp',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Cửa hàng là nơi trưng bày thông tin sản phẩm, cước căng và bảng giá dịch vụ để người chơi tham khảo.\n'
                  '• Người chơi không thanh toán online mà sẽ liên hệ trực tiếp với bạn qua chức năng Tin Nhắn hoặc ghé trực tiếp địa chỉ shop.\n'
                  '• Admin sẽ kiểm duyệt hình ảnh và mô tả sản phẩm cũng như nội dung tin nhắn để đảm bảo tiêu chuẩn cộng đồng.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5, height: 1.45),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() => _currentTabIndex = 2), // Chuyển sang tab Tin nhắn
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                    label: Text('Mở Hộp Thư Tin Nhắn ($chatCount cuộc trò chuyện)'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopSubscriptionCard(BuildContext context, Shop shop) {
    final isPaid = shop.isPaidActive;
    final isExpired = !shop.isSubscriptionActive;

    Color cardBorder;
    Color iconColor;
    IconData iconData;
    String title;
    String desc;
    String btnText;

    if (isExpired) {
      cardBorder = AppTheme.danger;
      iconColor = AppTheme.danger;
      iconData = Icons.warning_rounded;
      title = 'Gói Dịch Vụ Đã Hết Hạn ⚠️';
      desc = 'Thời gian dùng thử 1 tháng đã kết thúc. Vui lòng đóng phí duy trì (20k/tháng hoặc 40k/3 tháng) để tiếp tục đón khách!';
      btnText = 'Gia hạn ngay';
    } else if (isPaid) {
      cardBorder = const Color(0xFF38EF7D);
      iconColor = const Color(0xFF38EF7D);
      iconData = Icons.verified_rounded;
      title = 'Gói Dịch Vụ Hoạt Động (${shop.daysRemaining} ngày) ✨';
      desc = 'Cửa hàng của bạn đang được duy trì hiển thị đầy đủ trên Bản đồ cầu lông và Danh bạ đối tác.';
      btnText = 'Gia hạn thêm';
    } else {
      cardBorder = AppTheme.primary;
      iconColor = AppTheme.primary;
      iconData = Icons.card_giftcard_rounded;
      title = 'Dùng Thử Miễn Phí (Còn ${shop.daysRemaining} ngày) 🎁';
      desc = 'Bạn được miễn phí 1 tháng đầu tiên kể từ khi mở shop. Sau 1 tháng, phí duy trì chỉ từ 20k/tháng.';
      btnText = 'Gia hạn trước';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isExpired ? AppTheme.danger : AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () => ShopSubscriptionDialog.show(context, shop: shop),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isExpired ? AppTheme.danger : AppTheme.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  icon: const Icon(Icons.qr_code_rounded, size: 16),
                  label: Text(btnText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopStatusBanner(Shop shop) {
    if (shop.isApproved) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
        ),
        child: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Cửa hàng đã được Admin phê duyệt & đang hiển thị trên bản đồ người chơi.',
                style: TextStyle(color: AppTheme.primaryDark, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    } else if (shop.isPending) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.accent.withOpacity(0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.accent.withOpacity(0.5)),
        ),
        child: Row(
          children: const [
            Icon(Icons.hourglass_top_rounded, color: AppTheme.accent, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Hồ sơ cửa hàng đang chờ Admin kiểm duyệt. Bạn vẫn có thể đăng sản phẩm trưng bày và chỉnh sửa thông tin.',
                style: TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.danger.withOpacity(0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.danger.withOpacity(0.5)),
        ),
        child: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Cửa hàng đang tạm thời bị vô hiệu hóa bởi Admin do cần bổ sung thông tin hoặc kiểm tra.',
                style: TextStyle(color: AppTheme.danger, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: QUẢN LÝ DỊCH VỤ & VẬT PHẨM TRƯNG BÀY
  // (Kèm hỗ trợ chọn ảnh chụp hoặc gắn link ảnh mạng)
  // ==========================================
  Widget _buildProductsTab(BuildContext context, Shop? shop) {
    if (shop == null) return const SizedBox.shrink();

    final shopProvider = context.watch<ShopProvider>();
    final allItems = shopProvider.getDirectProductsForShop(shop.id);

    final filteredItems = allItems.where((p) {
      if (_selectedCategoryFilter != null && p.category != _selectedCategoryFilter) {
        return false;
      }
      if (_productSearchQuery.isNotEmpty) {
        final q = _productSearchQuery.toLowerCase();
        return p.name.toLowerCase().contains(q) || p.description.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (!shop.isSubscriptionActive) {
            ShopSubscriptionDialog.show(context, shop: shop);
            return;
          }
          _showAddEditItemModal(context, shop);
        },
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_photo_alternate_rounded),
        label: const Text('Thêm Sản Phẩm', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          if (!shop.isSubscriptionActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: AppTheme.danger.withOpacity(0.18),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Gói dịch vụ đã hết hạn. Hãy gia hạn (20k/tháng) để tiếp tục đăng thêm sản phẩm!',
                      style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    onPressed: () => ShopSubscriptionDialog.show(context, shop: shop),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('Gia hạn ➔', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),

          // Search & Filter controls
          Container(
            padding: const EdgeInsets.all(12),
            color: AppTheme.surface,
            child: Column(
              children: [
                TextField(
                  onChanged: (v) => setState(() => _productSearchQuery = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm vật phẩm, cước, dịch vụ đan...',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primary),
                    filled: true,
                    fillColor: AppTheme.surfaceLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _catFilterChip('Tất cả danh mục', null),
                      _catFilterChip('Dịch vụ đan', ProductCategory.service),
                      _catFilterChip('Vợt cầu lông', ProductCategory.racket),
                      _catFilterChip('Dây cước', ProductCategory.string),
                      _catFilterChip('Quấn cán', ProductCategory.grip),
                      _catFilterChip('Phụ kiện khác', ProductCategory.accessory),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: filteredItems.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.inventory_2_outlined, size: 54, color: AppTheme.textMuted),
                          SizedBox(height: 12),
                          Text(
                            'Chưa có vật phẩm hay dịch vụ nào phù hợp.\nBấm "Thêm Sản Phẩm" góc dưới để đăng ảnh và thông số!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
                    itemCount: filteredItems.length,
                    itemBuilder: (ctx, idx) {
                      final item = filteredItems[idx];
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
                            // Thumbnail ảnh sản phẩm
                            _buildProductThumbnail(item.imageUrl, isService: item.isService),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.name,
                                          style: const TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14.5,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: (item.isApproved
                                                  ? AppTheme.primary
                                                  : (item.isPending ? AppTheme.accent : AppTheme.danger))
                                              .withOpacity(0.16),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          item.statusDisplayName,
                                          style: TextStyle(
                                            color: item.isApproved
                                                ? AppTheme.primary
                                                : (item.isPending ? AppTheme.accent : AppTheme.danger),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.categoryName} • ${_currencyFormat.format(item.price)}',
                                    style: const TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.description,
                                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Chỉnh sửa',
                              icon: const Icon(Icons.edit_outlined, color: AppTheme.primary, size: 18),
                              onPressed: () => _showAddEditItemModal(context, shop, existing: item),
                            ),
                            IconButton(
                              tooltip: 'Xóa vật phẩm',
                              icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger, size: 18),
                              onPressed: () => _confirmDeleteItem(context, item, shopProvider),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _catFilterChip(String label, ProductCategory? category) {
    final isSelected = _selectedCategoryFilter == category;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.black : AppTheme.textPrimary)),
        selected: isSelected,
        selectedColor: AppTheme.primary,
        backgroundColor: AppTheme.surfaceLight,
        onSelected: (_) => setState(() => _selectedCategoryFilter = category),
      ),
    );
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
          size: 24,
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

    // Local file path
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

  void _confirmDeleteItem(BuildContext context, Product item, ShopProvider shopProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Xóa vật phẩm / dịch vụ?'),
        content: Text('Bạn có chắc chắn muốn xóa "${item.name}" khỏi cửa hàng?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await shopProvider.deleteProduct(item.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: TIN NHẮN TƯ VẤN KHÁCH HÀNG (CHAT)
  // ==========================================
  Widget _buildChatTab(BuildContext context, Shop? shop, List<dynamic> threads) {
    final chatProvider = context.watch<ChatProvider>();
    final timeFormat = DateFormat('HH:mm');

    return Scaffold(
      body: threads.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.chat_bubble_outline_rounded, size: 54, color: AppTheme.textMuted),
                  SizedBox(height: 12),
                  Text(
                    'Chưa có khách hàng nào gửi tin nhắn tới shop.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: threads.length,
              itemBuilder: (ctx, idx) {
                final t = threads[idx];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: InkWell(
                    onTap: () {
                      chatProvider.markThreadAsRead(t.id);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatConversationScreen(
                            threadId: t.id,
                            isShopOwner: true,
                          ),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppTheme.surfaceLight,
                          child: const Icon(Icons.person_rounded, color: AppTheme.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Khách hàng quan tâm sản phẩm',
                                    style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    timeFormat.format(t.lastMessageTime),
                                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                t.lastMessage,
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  // ==========================================
  // TAB 4: TÀI KHOẢN & CÀI ĐẶT (ACCOUNT)
  // ==========================================
  Widget _buildAccountTab(BuildContext context, UserModel user, Shop? shop) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // User profile header
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: AppTheme.primary.withOpacity(0.18),
                child: const Icon(Icons.storefront_rounded, size: 40, color: AppTheme.primary),
              ),
              const SizedBox(height: 12),
              Text(
                user.fullName,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(user.email, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  user.role.displayName,
                  style: const TextStyle(color: AppTheme.primaryDark, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Cài đặt & Thông tin
        _settingTile(
          icon: Icons.workspace_premium_rounded,
          title: 'Gói Dịch Vụ Cửa Hàng',
          subtitle: shop != null ? shop.subscriptionStatusLabel : 'Chưa đăng ký',
          onTap: () => shop != null ? ShopSubscriptionDialog.show(context, shop: shop) : null,
        ),
        _settingTile(
          icon: Icons.storefront_rounded,
          title: 'Hồ sơ Cửa Hàng',
          subtitle: shop != null ? shop.name : 'Chưa thiết lập',
          onTap: () => shop != null ? _showEditShopModal(context, shop) : null,
        ),
        _settingTile(
          icon: Icons.cloud_sync_rounded,
          title: 'Đồng bộ Cloud Firestore',
          subtitle: 'Lưu trữ tự động các sản phẩm & dịch vụ lên Firebase',
          onTap: () async {
            final shopProv = context.read<ShopProvider>();
            await shopProv.syncCatalogFromFirestore();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã đồng bộ toàn bộ dữ liệu lên Cloud Firestore!')),
              );
            }
          },
        ),
        _settingTile(
          icon: Icons.help_outline_rounded,
          title: 'Quy Trình & Tiêu Chuẩn Hoạt Động',
          subtitle: 'Quy định trưng bày sản phẩm & tiêu chuẩn cộng đồng',
          onTap: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppTheme.surface,
                title: const Text('Quy Trình & Tiêu Chuẩn'),
                content: const Text(
                  '1. Cửa hàng đăng sản phẩm trưng bày kèm ảnh thực tế hoặc link ảnh rõ nét.\n\n'
                  '2. Không bán hoặc thu tiền online: Người chơi sẽ liên hệ qua tin nhắn hoặc tới trực tiếp shop.\n\n'
                  '3. Admin sẽ kiểm duyệt sản phẩm đăng bán (tên, giá, ảnh, phân loại) để đảm bảo không vi phạm tiêu chuẩn.\n\n'
                  '4. Tin nhắn tư vấn giữa shop và người chơi cũng được kiểm duyệt để đảm bảo văn minh, lịch sự.',
                  style: TextStyle(fontSize: 13, height: 1.45),
                ),
                actions: [
                  ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đã hiểu')),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _confirmLogout(context),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Đăng Xuất Tài Khoản'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11.5)),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
        onTap: onTap,
      ),
    );
  }

  // ==========================================
  // MODALS & DIALOGS
  // ==========================================
  void _showEditShopModal(BuildContext context, Shop shop) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: shop.name);
    final phoneCtrl = TextEditingController(text: shop.phone);
    final addressCtrl = TextEditingController(text: shop.address);
    final districtCtrl = TextEditingController(text: shop.district);
    final cityCtrl = TextEditingController(text: shop.city);
    final machineCtrl = TextEditingController(text: shop.machineModel);
    final certCtrl = TextEditingController(text: shop.stringerCert);
    final hoursCtrl = TextEditingController(text: shop.openHours);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chỉnh Sửa Hồ Sơ Cửa Hàng',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Tên cửa hàng *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên cửa hàng' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Số điện thoại hotline *'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Vui lòng nhập số điện thoại';
                      }
                      if (!RegExp(r'^0\d{9}$').hasMatch(v.trim())) {
                        return 'Số điện thoại phải bắt đầu bằng số 0 và có đủ 10 chữ số';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: addressCtrl,
                    decoration: const InputDecoration(labelText: 'Địa chỉ cửa hàng *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập địa chỉ' : null,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: districtCtrl,
                          decoration: const InputDecoration(labelText: 'Quận / Huyện'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: cityCtrl,
                          decoration: const InputDecoration(labelText: 'Tỉnh / TP'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: machineCtrl,
                    decoration: const InputDecoration(labelText: 'Dòng máy đan vợt (VD: Victor C-7032 Pro)'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: certCtrl,
                    decoration: const InputDecoration(labelText: 'Chứng chỉ thợ đan (VD: Yonex Stringing Team)'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: hoursCtrl,
                    decoration: const InputDecoration(labelText: 'Giờ mở cửa (VD: 08:00 - 21:30)'),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final updated = shop.copyWith(
                          name: nameCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          address: addressCtrl.text.trim(),
                          district: districtCtrl.text.trim().isEmpty ? shop.district : districtCtrl.text.trim(),
                          city: cityCtrl.text.trim().isEmpty ? shop.city : cityCtrl.text.trim(),
                          machineModel: machineCtrl.text.trim().isEmpty ? shop.machineModel : machineCtrl.text.trim(),
                          stringerCert: certCtrl.text.trim().isEmpty ? shop.stringerCert : certCtrl.text.trim(),
                          openHours: hoursCtrl.text.trim().isEmpty ? shop.openHours : hoursCtrl.text.trim(),
                        );
                        Navigator.pop(ctx);
                        await context.read<ShopProvider>().upsertShop(updated);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã cập nhật hồ sơ cửa hàng lên hệ thống!'),
                              backgroundColor: AppTheme.primaryDark,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Lưu Thông Tin Cửa Hàng'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAddEditItemModal(BuildContext context, Shop shop, {Product? existing}) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(
      text: existing != null ? existing.price.toInt().toString() : '',
    );
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final imageCtrl = TextEditingController(text: existing?.imageUrl ?? '');
    ProductCategory selectedCat = existing?.category ?? ProductCategory.service;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        existing != null
                            ? 'Chỉnh Sửa Vật Phẩm / Dịch Vụ'
                            : 'Đăng Trưng Bày Vật Phẩm / Dịch Vụ Mới',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Cửa hàng: ${shop.name}', style: const TextStyle(color: AppTheme.primary, fontSize: 12.5)),
                      const SizedBox(height: 14),

                      // MỤC ẢNH SẢN PHẨM (CHỤP ẢNH HOẶC GẮN LINK)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Hình Ảnh Sản Phẩm / Dịch Vụ',
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                if (imageCtrl.text.isNotEmpty)
                                  InkWell(
                                    onTap: () {
                                      setSheetState(() => imageCtrl.clear());
                                    },
                                    child: const Text(
                                      'Xóa ảnh',
                                      style: TextStyle(color: AppTheme.danger, fontSize: 11),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Preview ảnh nếu có
                            if (imageCtrl.text.isNotEmpty) ...[
                              Center(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: imageCtrl.text.startsWith('http')
                                      ? Image.network(
                                          imageCtrl.text,
                                          height: 120,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => Container(
                                            height: 80,
                                            color: AppTheme.surface,
                                            alignment: Alignment.center,
                                            child: const Text('Link ảnh không hợp lệ', style: TextStyle(color: AppTheme.danger)),
                                          ),
                                        )
                                      : Image.file(
                                          File(imageCtrl.text),
                                          height: 120,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => Container(
                                            height: 80,
                                            color: AppTheme.surface,
                                            alignment: Alignment.center,
                                            child: const Text('Không mở được tệp ảnh', style: TextStyle(color: AppTheme.danger)),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],

                            // Nút chọn từ Camera / Thư viện
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final picker = ImagePicker();
                                      final picked = await picker.pickImage(source: ImageSource.camera, maxWidth: 1024, maxHeight: 1024);
                                      if (picked != null) {
                                        setSheetState(() => imageCtrl.text = picked.path);
                                      }
                                    },
                                    icon: const Icon(Icons.camera_alt_outlined, size: 16),
                                    label: const Text('Chụp ảnh', style: TextStyle(fontSize: 12)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.primary,
                                      side: const BorderSide(color: AppTheme.primary),
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final picker = ImagePicker();
                                      final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024);
                                      if (picked != null) {
                                        setSheetState(() => imageCtrl.text = picked.path);
                                      }
                                    },
                                    icon: const Icon(Icons.photo_library_outlined, size: 16),
                                    label: const Text('Thư viện', style: TextStyle(fontSize: 12)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.primaryDark,
                                      side: const BorderSide(color: AppTheme.primaryDark),
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Hoặc dán link ảnh từ mạng
                            TextFormField(
                              controller: imageCtrl,
                              onChanged: (_) => setSheetState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Hoặc gắn link ảnh từ trên mạng (URL)',
                                hintText: 'https://example.com/anh-san-pham.jpg',
                                prefixIcon: Icon(Icons.link_rounded, color: AppTheme.primary),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<ProductCategory>(
                        value: selectedCat,
                        decoration: const InputDecoration(
                          labelText: 'Phân loại danh mục',
                          prefixIcon: Icon(Icons.category_outlined, color: AppTheme.primary),
                        ),
                        items: const [
                          DropdownMenuItem(value: ProductCategory.service, child: Text('Dịch vụ đan vợt')),
                          DropdownMenuItem(value: ProductCategory.racket, child: Text('Vợt cầu lông')),
                          DropdownMenuItem(value: ProductCategory.string, child: Text('Cước cầu lông')),
                          DropdownMenuItem(value: ProductCategory.grip, child: Text('Quấn cán')),
                          DropdownMenuItem(value: ProductCategory.accessory, child: Text('Phụ kiện khác')),
                        ],
                        onChanged: (v) {
                          if (v != null) setSheetState(() => selectedCat = v);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Tên vật phẩm / dịch vụ *',
                          hintText: 'VD: Công đan 4 nút Yonex, Vợt 88D Pro...',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Giá niêm yết (VNĐ) *',
                          suffixText: 'đ',
                        ),
                        validator: (v) {
                          final val = double.tryParse(v?.trim() ?? '');
                          if (val == null || val < 0) return 'Vui lòng nhập giá hợp lệ';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Mô tả thông số chi tiết'),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final item = Product(
                              id: existing?.id ?? 'prod_${DateTime.now().millisecondsSinceEpoch}',
                              shopId: shop.id,
                              shopName: shop.name,
                              name: nameCtrl.text.trim(),
                              category: selectedCat,
                              price: double.parse(priceCtrl.text.trim()),
                              description: descCtrl.text.trim().isEmpty
                                  ? 'Trưng bày chính hãng tại ${shop.name}'
                                  : descCtrl.text.trim(),
                              imageUrl: imageCtrl.text.trim(),
                              isService: selectedCat == ProductCategory.service,
                              status: existing?.status ?? 'pending',
                            );
                            Navigator.pop(ctx);
                            await context.read<ShopProvider>().upsertProduct(item);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Đã lưu "${item.name}" lên danh mục trưng bày!'),
                                  backgroundColor: AppTheme.primaryDark,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.cloud_upload_outlined),
                          label: const Text('Lưu Trưng Bày Lên Shop'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNoShopState(BuildContext context, UserModel currentUser) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.storefront_outlined, size: 64, color: AppTheme.accent),
            const SizedBox(height: 16),
            const Text(
              'Chưa tìm thấy hồ sơ cửa hàng',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tài khoản của bạn đã có quyền Chủ Shop nhưng chưa liên kết với cửa hàng nào.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _showCreateShopDialog(context, currentUser),
              icon: const Icon(Icons.add_business_rounded),
              label: const Text('Tạo Hồ Sơ Cửa Hàng Ngay'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateShopDialog(BuildContext context, UserModel user) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: user.shopName ?? 'Cửa Hàng Cầu Lông ${user.fullName}');
    final phoneCtrl = TextEditingController(text: user.phone);
    final addressCtrl = TextEditingController();
    final machineCtrl = TextEditingController(text: 'Máy đan điện tử Victor / Yonex');
    final certCtrl = TextEditingController(text: 'Chứng chỉ thợ đan chuyên nghiệp');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Khởi Tạo Hồ Sơ Cửa Hàng Mới', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Tên shop *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên shop' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Hotline *'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Vui lòng nhập số Hotline shop';
                      }
                      if (!RegExp(r'^0\d{9}$').hasMatch(v.trim())) {
                        return 'Số điện thoại phải bắt đầu bằng số 0 và có đủ 10 chữ số';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: addressCtrl,
                    decoration: const InputDecoration(labelText: 'Địa chỉ shop *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập địa chỉ shop' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(controller: machineCtrl, decoration: const InputDecoration(labelText: 'Dòng máy đan')),
                  const SizedBox(height: 10),
                  TextFormField(controller: certCtrl, decoration: const InputDecoration(labelText: 'Chứng chỉ thợ đan')),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final shopProvider = context.read<ShopProvider>();
                        final newShop = Shop(
                          id: 'shop_${DateTime.now().millisecondsSinceEpoch}',
                          name: nameCtrl.text.trim().isEmpty ? 'Cửa Hàng Cầu Lông' : nameCtrl.text.trim(),
                          address: addressCtrl.text.trim().isEmpty ? 'Hà Nội' : addressCtrl.text.trim(),
                          district: 'Khu vực lân cận',
                          city: 'Việt Nam',
                          latitude: shopProvider.userLocation.latitude,
                          longitude: shopProvider.userLocation.longitude,
                          rating: 5.0,
                          reviewCount: 0,
                          machineModel: machineCtrl.text.trim(),
                          stringerCert: certCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          openHours: '08:00 - 21:30',
                          imageUrl: '',
                          ownerUid: user.uid,
                          ownerName: user.fullName,
                          ownerEmail: user.email,
                          status: 'pending',
                        );
                        Navigator.pop(ctx);
                        await shopProvider.upsertShop(newShop);
                      },
                      child: const Text('Tạo Cửa Hàng & Gửi Phê Duyệt'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi tài khoản Chủ Shop?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<AuthProvider>().logout();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginRegisterScreen()),
        (route) => false,
      );
    }
  }
}
