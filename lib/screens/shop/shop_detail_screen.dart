import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/product_model.dart';
import '../../models/racket_model.dart';
import '../../providers/shop_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/racket_provider.dart';
import '../../providers/chat_provider.dart';
import '../../theme/app_theme.dart';
import '../cart/cart_screen.dart';
import '../chat/chat_screen.dart';

class ShopDetailScreen extends StatefulWidget {
  final String shopId;

  const ShopDetailScreen({super.key, required this.shopId});

  @override
  State<ShopDetailScreen> createState() => _ShopDetailScreenState();
}

class _ShopDetailScreenState extends State<ShopDetailScreen> with SingleTickerProviderStateMixin {
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

  void _showBookServiceModal(BuildContext context, Product service) {
    final racketProvider = context.read<RacketProvider>();
    final userRackets = racketProvider.allRackets;

    Racket? selectedRacket = userRackets.isNotEmpty ? userRackets.first : null;
    double requestedTension = selectedRacket != null ? selectedRacket.initialTensionLbs : 25.5;
    if (requestedTension <= 0) requestedTension = 25.0;
    String selectedTechnique = '4 nút chuẩn Yonex';
    final notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final paddingBottom = MediaQuery.of(context).viewInsets.bottom;
            final isExceeded = selectedRacket != null && selectedRacket!.isTensionExceeded(requestedTension);

            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, paddingBottom + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            service.name,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppTheme.textMuted),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    Text(
                      'Giá dịch vụ: ${_currencyFormat.format(service.price)}',
                      style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    // Step 1: Chọn cây vợt từ Gara để đan
                    const Text(
                      '1. Chọn Cây Vợt Trong Gara Của Bạn Để Đan:',
                      style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    if (userRackets.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Bạn chưa có cây vợt nào trong Gara. Hãy thêm vợt trước để theo dõi vòng đời!',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      )
                    else
                      DropdownButtonFormField<Racket>(
                        value: selectedRacket,
                        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                        items: userRackets.map((r) {
                          return DropdownMenuItem<Racket>(
                            value: r,
                            child: Text(
                              '${r.brand} ${r.modelName} (Max: ${r.maxTensionLbs.toInt()} lbs)',
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: (r) {
                          setSheetState(() {
                            selectedRacket = r;
                          });
                        },
                      ),
                    const SizedBox(height: 16),

                    // Step 2: Mức căng yêu cầu (lbs)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '2. Mức Căng Yêu Cầu (lbs):',
                          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        Text(
                          '$requestedTension lbs',
                          style: TextStyle(
                            color: isExceeded ? AppTheme.danger : AppTheme.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: requestedTension,
                      min: 20.0,
                      max: 33.0,
                      divisions: 26,
                      activeColor: isExceeded ? AppTheme.danger : AppTheme.primary,
                      inactiveColor: AppTheme.surfaceLight,
                      onChanged: (val) {
                        setSheetState(() {
                          requestedTension = double.parse(val.toStringAsFixed(1));
                        });
                      },
                    ),

                    if (isExceeded)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.danger.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.danger.withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Cảnh báo: Khung vợt ${selectedRacket?.modelName} chỉ chịu tối đa ${selectedRacket?.maxTensionLbs} lbs!',
                                style: const TextStyle(color: AppTheme.danger, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Step 3: Kỹ thuật đan
                    const Text(
                      '3. Kỹ Thuật Đan:',
                      style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('4 Nút Yonex Chuẩn'),
                            selected: selectedTechnique == '4 nút chuẩn Yonex',
                            onSelected: (_) => setSheetState(() => selectedTechnique = '4 nút chuẩn Yonex'),
                            selectedColor: AppTheme.primary,
                            labelStyle: TextStyle(
                              color: selectedTechnique == '4 nút chuẩn Yonex' ? Colors.black : AppTheme.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('2 Nút Li-Ning'),
                            selected: selectedTechnique == '2 nút Li-Ning',
                            onSelected: (_) => setSheetState(() => selectedTechnique = '2 nút Li-Ning'),
                            selectedColor: AppTheme.primary,
                            labelStyle: TextStyle(
                              color: selectedTechnique == '2 nút Li-Ning' ? Colors.black : AppTheme.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Ghi chú cho thợ
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Ghi chú cho thợ đan (ví dụ: kéo chùng dây dọc 0.5 lbs)',
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Add to cart button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          context.read<CartProvider>().addToCart(
                            service,
                            targetRacket: selectedRacket,
                            requestedTensionLbs: requestedTension,
                            stringingTechnique: selectedTechnique,
                            specialNotes: notesController.text.trim(),
                          );
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Đã thêm ${service.name} vào Giỏ hàng!'),
                              action: SnackBarAction(
                                label: 'Xem Giỏ Hàng',
                                textColor: AppTheme.primary,
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const CartScreen()),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                        child: const Text('Thêm Vào Giỏ Hàng'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final shopProvider = context.watch<ShopProvider>();
    final cartProvider = context.watch<CartProvider>();
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

    final services = shopProvider.getServicesForShop(shop.id);
    final accessories = shopProvider.getAccessoriesForShop(shop.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(shop.name),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_bag_outlined),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CartScreen()),
                  );
                },
              ),
              if (cartProvider.itemCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppTheme.danger,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${cartProvider.itemCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
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
                                    '${shop.distanceKm} km',
                                    style: const TextStyle(color: AppTheme.primaryDark, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

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

                    // Chat with stringer button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
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
                        icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.primary),
                        label: const Text('Nhắn Tin Trực Tiếp Với Thợ Đan Cước'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.primary),
                          foregroundColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
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
                    Tab(icon: Icon(Icons.sports_baseball_rounded), text: 'Cước & Phụ Kiện'),
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
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.flash_on_rounded, color: AppTheme.primary, size: 28),
                            ),
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
                                  const SizedBox(height: 4),
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
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () => _showBookServiceModal(context, srv),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                              child: const Text('Đặt Đan', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

            // Accessories list
            accessories.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Cửa hàng này hiện chưa cập nhật danh sách cước & phụ kiện.',
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
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.sports_tennis_rounded, color: AppTheme.primaryDark, size: 28),
                            ),
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
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    prod.description,
                                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
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
                            const SizedBox(width: 10),
                            IconButton(
                              icon: const Icon(Icons.add_shopping_cart_rounded, color: AppTheme.primary),
                              style: IconButton.styleFrom(
                                backgroundColor: AppTheme.surfaceLight,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                context.read<CartProvider>().addToCart(prod);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Đã thêm ${prod.name} vào giỏ!'),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
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
