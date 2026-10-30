import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/chat_model.dart';
import '../../models/shop_model.dart';
import '../../providers/chat_provider.dart';
import '../../providers/shop_provider.dart';
import '../../theme/app_theme.dart';
import 'shop_report_sheet.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openVerifiedShopPicker(BuildContext context, List<Shop> approvedShops) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String modalSearch = '';
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            // LỌC CHẶT CHẼ: CHỈ LẤY SHOP ĐỐI TÁC THỰC TẾ ĐÃ ĐƯỢC ADMIN DUYỆT (isVerifiedPartner)
            final approvedOnly = approvedShops.where((s) => s.isVerifiedPartner).toList();
            final filtered = approvedOnly.where((s) {
              if (modalSearch.isEmpty) return true;
              final q = modalSearch.toLowerCase();
              return s.name.toLowerCase().contains(q) ||
                  s.address.toLowerCase().contains(q) ||
                  s.district.toLowerCase().contains(q);
            }).toList();

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.verified_rounded, color: AppTheme.primary, size: 22),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Shop Đối Tác Xác Thực',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Chỉ các shop đã được Admin phê duyệt hoạt động',
                                  style: TextStyle(fontSize: 11, color: AppTheme.primary),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                            onPressed: () => Navigator.pop(modalCtx),
                          ),
                        ],
                      ),
                    ),
                    // Search bar in modal
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: TextField(
                        style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Tìm shop theo tên, quận, địa chỉ...',
                          hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppTheme.primary),
                          filled: true,
                          fillColor: AppTheme.surfaceLight,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (val) {
                          setModalState(() {
                            modalSearch = val;
                          });
                        },
                      ),
                    ),
                    const Divider(height: 12, color: AppTheme.border),
                    // List of approved shops
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text(
                                'Không tìm thấy shop phù hợp',
                                style: TextStyle(color: AppTheme.textMuted),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              itemCount: filtered.length,
                              itemBuilder: (c, idx) {
                                final shop = filtered[idx];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceLight,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppTheme.border),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Avatar
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: AppTheme.background,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: AppTheme.border),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: shop.imageUrl.isNotEmpty
                                              ? Image.network(
                                                  shop.imageUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) => const Icon(
                                                    Icons.storefront_rounded,
                                                    color: AppTheme.primary,
                                                    size: 26,
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.storefront_rounded,
                                                  color: AppTheme.primary,
                                                  size: 26,
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    shop.name,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13.5,
                                                      color: AppTheme.textPrimary,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const Icon(
                                                  Icons.verified_rounded,
                                                  color: AppTheme.primary,
                                                  size: 16,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              shop.address,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.textMuted,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              '🛠️ ${shop.machineModel}',
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                color: AppTheme.accent,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '🏆 ${shop.stringerCert}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: AppTheme.textSecondary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Action button
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.pop(modalCtx);
                                          final authUser = context.read<AuthProvider>().currentUser;
                                          final chatProv = context.read<ChatProvider>();
                                          final thread = chatProv.getOrCreateThreadForShop(
                                            shop.id,
                                            shop.name,
                                            shop.imageUrl,
                                            shopOwnerUid: shop.ownerUid,
                                            userName: authUser?.fullName,
                                            userEmail: authUser?.email,
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
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.primary,
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.chat_rounded, size: 13),
                                            SizedBox(width: 4),
                                            Text(
                                              'Nhắn tin',
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
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
    final chatProvider = context.watch<ChatProvider>();
    final shopProvider = context.watch<ShopProvider>();

    // CHỈ LẤY SHOP ĐỐI TÁC THỰC TẾ ĐÃ ĐƯỢC ADMIN PHÊ DUYỆT (isVerifiedPartner)
    final approvedShops = shopProvider.approvedShops;
    final allThreads = chatProvider.threads;
    final timeFormat = DateFormat('HH:mm');

    // Filter threads by search query
    final filteredThreads = allThreads.where((t) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return t.shopName.toLowerCase().contains(q) || t.lastMessage.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tin Nhắn & Tư Vấn Thợ Đan'),
        actions: [
          IconButton(
            tooltip: 'Chọn Shop đã xác thực để nhắn tin',
            icon: const Icon(Icons.add_comment_rounded, color: AppTheme.primary),
            onPressed: () => _openVerifiedShopPicker(context, approvedShops),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openVerifiedShopPicker(context, approvedShops),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.mark_chat_unread_rounded),
        label: const Text(
          'Nhắn tin Shop xác thực',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // Search Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm cuộc hội thoại, cửa hàng...',
                  hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primary, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppTheme.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val.trim());
                },
              ),
            ),
          ),

          // Horizontal Carousel of Admin-Verified Partner Shops
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user_rounded, size: 16, color: AppTheme.primary),
                      const SizedBox(width: 6),
                      const Text(
                        'Shop Đã Xác Thực',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${approvedShops.length}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (approvedShops.length > 2)
                        TextButton(
                          onPressed: () => _openVerifiedShopPicker(context, approvedShops),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Xem tất cả ▾',
                            style: TextStyle(fontSize: 11.5, color: AppTheme.primary),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 106,
                  child: approvedShops.isEmpty
                      ? const Center(
                          child: Text(
                            'Chưa có shop nào được duyệt',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                          ),
                        )
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: approvedShops.length > 10 ? 10 : approvedShops.length,
                          itemBuilder: (ctx, idx) {
                            final shop = approvedShops[idx];
                            return InkWell(
                              onTap: () {
                                final authUser = context.read<AuthProvider>().currentUser;
                                final thread = chatProvider.getOrCreateThreadForShop(
                                  shop.id,
                                  shop.name,
                                  shop.imageUrl,
                                  shopOwnerUid: shop.ownerUid,
                                  userName: authUser?.fullName,
                                  userEmail: authUser?.email,
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
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: 155,
                                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: AppTheme.surfaceLight,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.storefront_rounded,
                                            size: 16,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Expanded(
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.verified_rounded,
                                                color: AppTheme.primary,
                                                size: 13,
                                              ),
                                              SizedBox(width: 2),
                                              Flexible(
                                                child: Text(
                                                  'Đã duyệt',
                                                  style: TextStyle(
                                                    fontSize: 9.5,
                                                    color: AppTheme.primary,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      shop.name,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${shop.district.isNotEmpty ? shop.district : "TP.HCM"} • ${shop.distanceKm} km',
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        color: AppTheme.textMuted,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),

          // Header for Active Threads
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded, size: 15, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  const Text(
                    'Cuộc Trò Chuyện Của Bạn',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  if (chatProvider.unreadMessagesCount > 0)
                    Text(
                      '${chatProvider.unreadMessagesCount} chưa đọc',
                      style: const TextStyle(fontSize: 11, color: AppTheme.primary),
                    ),
                ],
              ),
            ),
          ),

          // Thread List or Empty View
          if (filteredThreads.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: const Icon(
                          Icons.chat_outlined,
                          size: 40,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Chưa có cuộc trò chuyện nào',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Hãy chọn một cửa hàng đã được Admin xác nhận ở trên để nhắn tin tư vấn chọn cước và đặt lịch đan vợt nhé!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _openVerifiedShopPicker(context, approvedShops),
                        icon: const Icon(Icons.storefront_rounded, size: 16),
                        label: const Text('Chọn Shop Đã Xác Thực Ngay'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, idx) {
                    final thread = filteredThreads[idx];
                    final shop = shopProvider.getShopById(thread.shopId);
                    final bool isShopApproved = (shop != null && shop.isVerifiedPartner);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: thread.unreadCount > 0
                              ? AppTheme.primary.withOpacity(0.5)
                              : AppTheme.border,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        onTap: () {
                          chatProvider.markThreadAsRead(thread.id);
                          final authUser = context.read<AuthProvider>().currentUser;
                          final bool isOwner = authUser?.role == UserRole.stringer ||
                              (authUser != null && (thread.shopOwnerUid == authUser.uid || thread.shopId == authUser.uid));
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatConversationScreen(
                                threadId: thread.id,
                                shopId: thread.shopId,
                                isShopOwner: isOwner,
                              ),
                            ),
                          );
                        },
                        leading: Stack(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceLight,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isShopApproved ? AppTheme.primaryDark : AppTheme.danger,
                                ),
                              ),
                              child: const Icon(
                                Icons.storefront_rounded,
                                color: AppTheme.primary,
                                size: 24,
                              ),
                            ),
                            if (isShopApproved)
                              const Positioned(
                                right: 0,
                                bottom: 0,
                                child: Icon(
                                  Icons.verified_rounded,
                                  color: AppTheme.primary,
                                  size: 16,
                                ),
                              ),
                          ],
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                thread.shopName,
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: thread.unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                                  fontSize: 14.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              timeFormat.format(thread.lastMessageTime),
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isShopApproved
                                        ? AppTheme.primary.withOpacity(0.12)
                                        : AppTheme.danger.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isShopApproved
                                        ? '✓ Shop đã xác thực'
                                        : '⚠️ Chưa xác thực tài khoản',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      color: isShopApproved ? AppTheme.primary : AppTheme.danger,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              thread.lastMessage,
                              style: TextStyle(
                                color: thread.unreadCount > 0
                                    ? AppTheme.primary
                                    : (thread.lastMessage.startsWith('🛡️')
                                        ? AppTheme.accent
                                        : AppTheme.textSecondary),
                                fontSize: 12.5,
                                fontWeight: thread.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                                fontStyle: thread.lastMessage.startsWith('🛡️') ? FontStyle.italic : FontStyle.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppTheme.textMuted),
                          color: AppTheme.surfaceLight,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          onSelected: (val) {
                            if (val == 'report') {
                              ShopReportSheet.show(
                                context,
                                shopId: thread.shopId,
                                shopName: thread.shopName,
                                threadId: thread.id,
                              );
                            } else if (val == 'delete') {
                              chatProvider.deleteThread(thread.id);
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'report',
                              child: Row(
                                children: [
                                  Icon(Icons.flag_rounded, color: AppTheme.danger, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Báo cáo shop vi phạm',
                                    style: TextStyle(color: AppTheme.danger, fontSize: 12.5),
                                  ),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline_rounded, color: AppTheme.textMuted, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Xóa cuộc trò chuyện',
                                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12.5),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: filteredThreads.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ChatConversationScreen extends StatefulWidget {
  final String threadId;
  final String? shopId;
  final bool isShopOwner;

  const ChatConversationScreen({
    super.key,
    required this.threadId,
    this.shopId,
    this.isShopOwner = false,
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _timeFormat = DateFormat('HH:mm');

  List<String> get _quickReplies => widget.isShopOwner
      ? [
          'Vợt của bạn đã đan xong rồi nhé! Bạn có thể ghé shop lấy.',
          'Shop đang tiến hành đan cước cho bạn ạ.',
          'Dạ shop còn cước BG66 Ultimax và Exbolt 65 ạ.',
          'Bạn cần đặt lịch vào khung giờ nào ạ?',
        ]
      : [
          'Vợt thân cứng nên đan Exbolt 65 hay BG66UM?',
          'Shop có nhận đan lấy liền trong 20 phút không?',
          'Em muốn căng 4 nút kẹp đôi chuẩn Yonex ạ.',
          'Shop cam kết cước chính hãng 100% không ạ?',
        ];

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage({String? quickText}) {
    final text = quickText ?? _msgController.text.trim();
    if (text.isEmpty) return;

    final shopProv = context.read<ShopProvider>();
    final chatProv = context.read<ChatProvider>();
    final authUser = context.read<AuthProvider>().currentUser;
    final thread = chatProv.getThread(widget.threadId);
    final targetShopId = widget.shopId ?? thread?.shopId ?? '';
    final shop = shopProv.getShopById(targetShopId);

    final bool isShop = widget.isShopOwner ||
        authUser?.role == UserRole.stringer ||
        (authUser != null && (thread?.shopOwnerUid == authUser.uid || thread?.shopId == authUser.uid));

    // BẮT BUỘC: CHỈ CHO PHÉP NHẮN VỚI SHOP ĐỐI TÁC ĐÃ ĐƯỢC ADMIN PHÊ DUYỆT TRÊN APP (isVerifiedPartner)
    if (!isShop && authUser?.role != UserRole.admin && (shop == null || !shop.isVerifiedPartner)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không thể gửi tin nhắn! Cửa hàng này chưa được Admin phê duyệt tài khoản đối tác trên ứng dụng.',
          ),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    if (authUser?.role == UserRole.admin) {
      chatProv.sendSystemMessage(widget.threadId, '[Admin]: $text');
    } else if (isShop) {
      chatProv.sendMessageAsShop(widget.threadId, text);
    } else {
      chatProv.sendMessage(widget.threadId, text);
    }
    if (quickText == null) _msgController.clear();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showShopCredentialsDialog(BuildContext context, Shop? shop, String shopName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_user_rounded, color: AppTheme.primary, size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                shopName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 16),
                      const SizedBox(width: 6),
                      const Text(
                        'Chứng nhận bởi Admin GearSports',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '📍 Địa chỉ: ${shop?.address ?? "TP. Hồ Chí Minh"}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '🛠️ Máy đan: ${shop?.machineModel ?? "Máy đan điện tử chuẩn thi đấu"}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '🏆 Thợ đan: ${shop?.stringerCert ?? "Chứng chỉ đan vợt Yonex Standard"}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '📞 Hotline: ${shop?.phone ?? "Liên hệ trong ứng dụng"}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Người chơi được đảm bảo quyền lợi khi giao dịch với cửa hàng đã xác thực. Nếu phát hiện sai phạm hoặc gian dối, bạn có thể lập đơn báo cáo để Admin xử lý.',
              style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final shopProvider = context.watch<ShopProvider>();
    final thread = chatProvider.getThread(widget.threadId);

    if (thread == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cuộc trò chuyện')),
        body: const Center(child: Text('Không tìm thấy cuộc trò chuyện')),
      );
    }

    final targetShopId = widget.shopId ?? thread.shopId;
    final shop = shopProvider.getShopById(targetShopId);
    // BẮT BUỘC: CHỈ ĐƯỢC COI LÀ HỢP LỆ KHI ĐƯỢC XÁC THỰC LÀ SHOP ĐỐI TÁC TRÊN APP (isVerifiedPartner)
    final bool isShopApproved = (shop != null && shop.isVerifiedPartner);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: () => _showShopCredentialsDialog(context, shop, thread.shopName),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        widget.isShopOwner ? 'Tư Vấn: ${thread.userName ?? "Khách Hàng"}' : thread.shopName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (isShopApproved)
                      const Icon(
                        Icons.verified_rounded,
                        color: AppTheme.primary,
                        size: 15,
                      ),
                  ],
                ),
                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      color: isShopApproved ? AppTheme.primary : AppTheme.danger,
                      size: 7,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.isShopOwner
                            ? 'Khách hàng quan tâm đan vợt'
                            : (isShopApproved
                                ? '✓ Đã xác thực • Thợ đan GearSports'
                                : '⚠️ Cửa hàng chưa xác thực tài khoản'),
                        style: TextStyle(
                          color: isShopApproved ? AppTheme.primary : AppTheme.danger,
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
          ),
        ),
        actions: [
          // NÚT BÁO CÁO SHOP VI PHẠM / GIAN DỐI DÀNH CHO PLAYER
          if (!widget.isShopOwner)
            IconButton(
              tooltip: 'Làm đơn báo cáo shop vi phạm / gian dối',
              icon: const Icon(Icons.flag_rounded, color: AppTheme.danger),
              onPressed: () {
                ShopReportSheet.show(
                  context,
                  shopId: targetShopId,
                  shopName: thread.shopName,
                  threadId: thread.id,
                );
              },
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            color: AppTheme.surfaceLight,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (val) {
              if (val == 'report') {
                ShopReportSheet.show(
                  context,
                  shopId: targetShopId,
                  shopName: thread.shopName,
                  threadId: thread.id,
                );
              } else if (val == 'info') {
                _showShopCredentialsDialog(context, shop, thread.shopName);
              } else if (val == 'clear') {
                chatProvider.deleteThread(thread.id);
                Navigator.pop(context);
              }
            },
            itemBuilder: (ctx) => [
              if (!widget.isShopOwner)
                const PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(Icons.flag_rounded, color: AppTheme.danger, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Làm đơn báo cáo vi phạm',
                        style: TextStyle(color: AppTheme.danger, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppTheme.primary, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Thông tin kiểm duyệt Shop',
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, color: AppTheme.textMuted, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Xóa cuộc trò chuyện',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Trust Verification Banner / Warning Banner
          if (isShopApproved)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                border: const Border(
                  bottom: BorderSide(color: AppTheme.border),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: AppTheme.primary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Shop đối tác chính thức • ${shop.machineModel}. Nếu phát hiện gian dối, hãy bấm 🚩 để báo cáo Admin.',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      ShopReportSheet.show(
                        context,
                        shopId: targetShopId,
                        shopName: thread.shopName,
                        threadId: thread.id,
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        'Báo cáo',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.danger,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: AppTheme.danger.withOpacity(0.12),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Khóa tin nhắn: Cửa hàng chưa được Admin phê duyệt hoạt động. Bạn chỉ có thể trò chuyện với các shop đối tác chính thức.',
                      style: TextStyle(fontSize: 11, color: AppTheme.danger, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

          // Message List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: thread.messages.length,
              itemBuilder: (context, idx) {
                final msg = thread.messages[idx];
                return _buildMessageBubble(msg);
              },
            ),
          ),

          // Quick Prompt Suggestions (only if shop is approved)
          if (isShopApproved)
            Container(
              height: 38,
              margin: const EdgeInsets.only(bottom: 6),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _quickReplies.length,
                itemBuilder: (context, idx) {
                  final prompt = _quickReplies[idx];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(
                        prompt,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      backgroundColor: AppTheme.surfaceLight,
                      side: const BorderSide(color: AppTheme.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      onPressed: () => _sendMessage(quickText: prompt),
                    ),
                  );
                },
              ),
            ),

          // Message Input Field
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: SafeArea(
              child: isShopApproved
                  ? Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _msgController,
                            style: const TextStyle(color: AppTheme.textPrimary),
                            decoration: InputDecoration(
                              hintText: widget.isShopOwner
                                  ? 'Nhập tin nhắn phản hồi cho khách hàng...'
                                  : 'Nhắn tin hỏi kỹ thuật viên về mức căng, dây cước...',
                              hintStyle: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 13,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              filled: true,
                              fillColor: AppTheme.surfaceLight,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _sendMessage(),
                          icon: const Icon(Icons.send_rounded, color: AppTheme.primary),
                          style: IconButton.styleFrom(
                            backgroundColor: AppTheme.surfaceLight,
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(12),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'Khóa nhắn tin: Cửa hàng này chưa được phê duyệt hoạt động trên ứng dụng.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.danger, fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    // If it is an official system notice (e.g. Report filed)
    if (msg.isSystemNotice) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.danger.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.gavel_rounded, color: AppTheme.danger, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.text,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textPrimary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _timeFormat.format(msg.timestamp),
                    style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final authUser = context.read<AuthProvider>().currentUser;
    final thread = context.read<ChatProvider>().getThread(widget.threadId);
    final bool isShop = widget.isShopOwner ||
        authUser?.role == UserRole.stringer ||
        (authUser != null && (thread?.shopOwnerUid == authUser.uid || thread?.shopId == authUser.uid));
    final isMe = isShop ? !msg.isFromUser : msg.isFromUser;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: Border.all(
            color: isMe ? AppTheme.primary : AppTheme.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (msg.attachedRacketName != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.sports_tennis_rounded,
                      size: 12,
                      color: Colors.black,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${msg.attachedRacketName} (${msg.attachedTension})',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Text(
              msg.text,
              style: TextStyle(
                color: isMe ? Colors.black : AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: isMe ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _timeFormat.format(msg.timestamp),
              style: TextStyle(
                color: isMe ? Colors.black54 : AppTheme.textMuted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
