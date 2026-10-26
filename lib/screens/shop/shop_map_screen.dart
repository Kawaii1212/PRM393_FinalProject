import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/shop_provider.dart';
import '../../providers/chat_provider.dart';
import '../../theme/app_theme.dart';
import 'shop_detail_screen.dart';
import '../chat/chat_screen.dart';

class ShopMapScreen extends StatefulWidget {
  const ShopMapScreen({super.key});

  @override
  State<ShopMapScreen> createState() => _ShopMapScreenState();
}

class _ShopMapScreenState extends State<ShopMapScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedShopIndex = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shopProvider = context.watch<ShopProvider>();
    final shops = shopProvider.shops;
    final currentShop = shops.isNotEmpty ? shops[_selectedShopIndex.clamp(0, shops.length - 1)] : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bản Đồ Điểm Đan Vợt'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location_rounded, color: AppTheme.primary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đang định vị xung quanh vị trí của bạn...')),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Simulated Interactive Map Canvas
          Container(
            color: const Color(0xFF0F1E36),
            child: Stack(
              children: [
                // Stylized map roads and grid lines
                CustomPaint(
                  size: Size.infinite,
                  painter: _MapCanvasPainter(),
                ),

                // Map Markers for shops
                for (int i = 0; i < shops.length; i++)
                  Positioned(
                    top: 140.0 + (i * 110.0),
                    left: 60.0 + ((i % 2) * 160.0),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedShopIndex = i);
                        shopProvider.selectShop(shops[i]);
                      },
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _selectedShopIndex == i ? AppTheme.primary : AppTheme.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _selectedShopIndex == i ? Colors.white : AppTheme.border,
                                width: 1.5,
                              ),
                              boxShadow: const [
                                BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 3)),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.store_rounded,
                                  color: _selectedShopIndex == i ? Colors.black : AppTheme.primary,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  shops[i].name.split('-').first.trim(),
                                  style: TextStyle(
                                    color: _selectedShopIndex == i ? Colors.black : AppTheme.textPrimary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.location_on_rounded,
                            color: _selectedShopIndex == i ? AppTheme.primary : AppTheme.primaryDark,
                            size: 34,
                          ),
                        ],
                      ),
                    ),
                  ),

                // Current user GPS marker
                Positioned(
                  top: 280,
                  left: 170,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.accent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Bạn ở đây',
                          style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withOpacity(0.3),
                          shape: BoxShape.circle,
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
              ],
            ),
          ),

          // Search Bar on Top
          Positioned(
            top: 14,
            left: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surface.withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
                boxShadow: const [
                  BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: AppTheme.textPrimary),
                onChanged: (val) => shopProvider.searchShops(val),
                decoration: InputDecoration(
                  hintText: 'Tìm tiệm đan cước, quận, thợ đan...',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppTheme.textMuted),
                          onPressed: () {
                            _searchController.clear();
                            shopProvider.searchShops('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),

          // Selected Shop Bottom Preview Card
          if (currentShop != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.5), width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 6)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.storefront_rounded, color: AppTheme.primary, size: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentShop.name,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${currentShop.address} • Cách ${currentShop.distanceKm} km',
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star_rounded, color: AppTheme.accent, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '${currentShop.rating}',
                                style: const TextStyle(
                                  color: AppTheme.accent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Machine Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.precision_manufacturing_rounded, color: AppTheme.primary, size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              currentShop.machineModel,
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ShopDetailScreen(shopId: currentShop.id),
                                ),
                              );
                            },
                            child: const Text('Xem Dịch Vụ & Đặt Lịch'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          onPressed: () {
                            final chatProvider = context.read<ChatProvider>();
                            final thread = chatProvider.getOrCreateThreadForShop(
                              currentShop.id,
                              currentShop.name,
                              currentShop.imageUrl,
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatConversationScreen(threadId: thread.id),
                              ),
                            );
                          },
                          icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.primaryDark),
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

class _MapCanvasPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = const Color(0xFF1E314F)
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke;

    final roadCenterPaint = Paint()
      ..color = const Color(0xFF2E4870)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw main boulevard
    final path1 = Path()
      ..moveTo(0, size.height * 0.3)
      ..quadraticBezierTo(size.width * 0.4, size.height * 0.35, size.width, size.height * 0.2);
    canvas.drawPath(path1, roadPaint);
    canvas.drawPath(path1, roadCenterPaint);

    final path2 = Path()
      ..moveTo(size.width * 0.2, 0)
      ..quadraticBezierTo(size.width * 0.3, size.height * 0.5, size.width * 0.8, size.height);
    canvas.drawPath(path2, roadPaint);
    canvas.drawPath(path2, roadCenterPaint);

    final path3 = Path()
      ..moveTo(0, size.height * 0.7)
      ..lineTo(size.width, size.height * 0.65);
    canvas.drawPath(path3, roadPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
