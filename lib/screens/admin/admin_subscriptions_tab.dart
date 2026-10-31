import '../../services/sepay_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../models/shop_model.dart';
import '../../providers/admin_provider.dart';
import '../../providers/shop_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../theme/app_theme.dart';

class AdminSubscriptionsTab extends StatefulWidget {
  const AdminSubscriptionsTab({super.key});

  @override
  State<AdminSubscriptionsTab> createState() => _AdminSubscriptionsTabState();
}

class _AdminSubscriptionsTabState extends State<AdminSubscriptionsTab> {
  String _filterType = 'all'; // 'all', 'player', 'shop'
  String _searchQuery = '';
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
  final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  Widget build(BuildContext context) {
    final subProv = context.watch<SubscriptionProvider>();
    final adminProv = context.watch<AdminProvider>();
    final shopProv = context.watch<ShopProvider>();

    final allUsers = adminProv.allUsers;
    final players = allUsers.where((u) => u.role == UserRole.player).toList();
    final vipPlayersCount = players.where((u) => u.isVipActive).length;

    final appShops = shopProv.allShopsForAdmin.where((s) => s.isRegisteredOnApp).toList();
    final trialShopsCount = appShops.where((s) => s.isTrialActive && !s.isPaidActive).length;
    final paidShopsCount = appShops.where((s) => s.isPaidActive).length;
    final expiredShopsCount = appShops.where((s) => !s.isSubscriptionActive).length;

    // Filter transactions
    final filteredTransactions = subProv.transactions.where((t) {
      if (_filterType == 'player' && !t.planId.startsWith('player_') && !t.planId.contains('vip')) {
        return false;
      }
      if (_filterType == 'shop' && !t.planId.startsWith('shop_')) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchUser = t.userName.toLowerCase().contains(q);
        final matchEmail = t.userEmail.toLowerCase().contains(q);
        final matchCode = t.bankTransferCode.toLowerCase().contains(q);
        final matchPlan = t.planTitle.toLowerCase().contains(q);
        return matchUser || matchEmail || matchCode || matchPlan;
      }
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: () async {
        await adminProv.refreshAdminData();
        await shopProv.syncCatalogFromFirestore();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section Title
          const Row(
            children: [
              Icon(Icons.monetization_on_rounded, color: AppTheme.primary, size: 22),
              SizedBox(width: 8),
              Text(
                'Quản Lý Gói Đăng Ký & Doanh Thu',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 4 Revenue Metric Cards (2x2 Grid)
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  title: 'Tổng Doanh Thu',
                  value: currencyFormat.format(subProv.totalRevenueVnd),
                  subtitle: '${subProv.totalTransactionsCount} lượt giao dịch',
                  icon: Icons.account_balance_wallet_rounded,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricCard(
                  title: 'Doanh Thu VIP Player',
                  value: currencyFormat.format(subProv.playerVipRevenueVnd),
                  subtitle: '$vipPlayersCount / ${players.length} người chơi VIP',
                  icon: Icons.workspace_premium_rounded,
                  color: const Color(0xFFFFD700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  title: 'Doanh Thu Phí Shop',
                  value: currencyFormat.format(subProv.shopSubscriptionRevenueVnd),
                  subtitle: '$paidShopsCount shop đã đóng phí',
                  icon: Icons.storefront_rounded,
                  color: const Color(0xFF38EF7D),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricCard(
                  title: 'Giao Dịch Thành Công',
                  value: '${subProv.completedTransactionsCount} GD',
                  subtitle: 'VietQR Napas 24/7',
                  icon: Icons.check_circle_rounded,
                  color: AppTheme.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Shop Subscription Status Summary Bar
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.store_rounded, color: AppTheme.primary, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Tình trạng gói dịch vụ cửa hàng',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _statusItem(
                        label: 'Dùng thử 1 tháng',
                        count: trialShopsCount,
                        color: AppTheme.primary,
                        icon: Icons.card_giftcard_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _statusItem(
                        label: 'Đã đóng phí',
                        count: paidShopsCount,
                        color: const Color(0xFF38EF7D),
                        icon: Icons.verified_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _statusItem(
                        label: 'Đã hết hạn',
                        count: expiredShopsCount,
                        color: AppTheme.danger,
                        icon: Icons.timer_off_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // SePAY Open Banking Auto-detection Banner
          FutureBuilder<bool>(
            future: SepayService.hasConfiguredToken(),
            builder: (context, snapshot) {
              final hasToken = snapshot.data == true;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: hasToken ? const Color(0xFF0F2B1D) : const Color(0xFF2B210F),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: hasToken ? const Color(0xFF38EF7D) : const Color(0xFFFFB300),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      hasToken ? Icons.verified_rounded : Icons.key_off_rounded,
                      color: hasToken ? const Color(0xFF38EF7D) : const Color(0xFFFFB300),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasToken
                                ? 'Cổng SePAY Auto-detect: Đã Kết Nối MBBank'
                                : 'Cổng SePAY Auto-detect: Chưa Thiết Lập Token',
                            style: TextStyle(
                              color: hasToken ? const Color(0xFF38EF7D) : const Color(0xFFFFB300),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasToken
                                ? 'Tự động duyệt giao dịch 24/7 khi có tiền vào STK 0949614588.'
                                : 'Người dùng chuyển tiền thật sẽ tự động được kích hoạt ngay khi nhập Token.',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _showAdminSepayConfigModal(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        backgroundColor: (hasToken ? const Color(0xFF38EF7D) : const Color(0xFFFFB300)).withOpacity(0.2),
                      ),
                      child: Text(
                        hasToken ? 'Cấu hình' : 'Nhập Token',
                        style: TextStyle(
                          color: hasToken ? const Color(0xFF38EF7D) : const Color(0xFFFFB300),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 14),

          // Admin Action Buttons: Cấp VIP thủ công & Gia hạn Shop thủ công
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showGrantVipModal(context, players),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.star_rounded, size: 18),
                  label: const Text(
                    'Cấp VIP Player',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showGrantShopModal(context, appShops),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38EF7D),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.add_business_rounded, size: 18),
                  label: const Text(
                    'Gia Hạn Shop',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Transaction Ledger Header & Search
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'LỊCH SỬ GIAO DỊCH VIETQR:',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '${filteredTransactions.length} giao dịch',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip(label: 'Tất cả', value: 'all'),
                const SizedBox(width: 8),
                _filterChip(label: 'Gói VIP Player', value: 'player'),
                const SizedBox(width: 8),
                _filterChip(label: 'Phí Duy Trì Shop', value: 'shop'),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Search Field
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
            decoration: InputDecoration(
              hintText: 'Tìm theo tên, email, mã CK...',
              prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primary, size: 20),
              filled: true,
              fillColor: AppTheme.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Transaction list
          if (filteredTransactions.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  const Icon(Icons.receipt_long_outlined, size: 40, color: AppTheme.textMuted),
                  const SizedBox(height: 8),
                  Text(
                    _searchQuery.isNotEmpty ? 'Không tìm thấy giao dịch phù hợp' : 'Chưa có giao dịch nào được ghi nhận',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredTransactions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (ctx, index) {
                final tx = filteredTransactions[index];
                final isPlayer = tx.planId.startsWith('player_') || tx.planId.contains('vip');

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
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: isPlayer
                                      ? const Color(0xFFFFD700).withOpacity(0.15)
                                      : const Color(0xFF38EF7D).withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isPlayer ? Icons.workspace_premium_rounded : Icons.storefront_rounded,
                                  color: isPlayer ? const Color(0xFFFFD700) : const Color(0xFF38EF7D),
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                tx.planTitle,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            tx.amount > 0 ? currencyFormat.format(tx.amount) : 'Miễn phí',
                            style: TextStyle(
                              color: tx.amount > 0 ? AppTheme.primary : const Color(0xFFFFD700),
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Người dùng: ${tx.userName} • ${tx.userEmail}',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                      if (tx.shopName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Cửa hàng: ${tx.shopName}',
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Mã CK: ${tx.bankTransferCode}',
                              style: const TextStyle(
                                color: AppTheme.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.primary),
                              const SizedBox(width: 4),
                              Text(
                                dateFormat.format(tx.createdAt),
                                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _statusItem({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            '$count shop',
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _filterChip({required String label, required String value}) {
    final isSelected = _filterType == value;
    return GestureDetector(
      onTap: () => setState(() => _filterType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // Modal cấp VIP thủ công cho Player
  void _showGrantVipModal(BuildContext context, List<UserModel> players) {
    UserModel? selectedUser = players.isNotEmpty ? players.first : null;
    int selectedDays = 30;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD700), size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Cấp Đặc Quyền VIP Cho Player',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text('Chọn Người Chơi:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 6),
              DropdownButtonFormField<UserModel>(
                value: selectedUser,
                isExpanded: true,
                dropdownColor: AppTheme.cardBackground,
                items: players.map((u) {
                  return DropdownMenuItem(
                    value: u,
                    child: Text(
                      '${u.fullName} (${u.email}) ${u.isVipActive ? "👑" : ""}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  );
                }).toList(),
                onChanged: (val) => setModalState(() => selectedUser = val),
              ),
              const SizedBox(height: 14),
              const Text('Thời hạn cấp VIP:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('30 Ngày (1 Tháng)')),
                      selected: selectedDays == 30,
                      onSelected: (s) {
                        if (s) setModalState(() => selectedDays = 30);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('90 Ngày (3 Tháng)')),
                      selected: selectedDays == 90,
                      onSelected: (s) {
                        if (s) setModalState(() => selectedDays = 90);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: selectedUser == null
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          final subProv = context.read<SubscriptionProvider>();
                          final ok = await subProv.adminGrantVip(
                            context: context,
                            user: selectedUser!,
                            days: selectedDays,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ok
                                    ? 'Đã cấp thành công $selectedDays ngày VIP cho ${selectedUser!.fullName}!'
                                    : 'Cấp VIP thất bại'),
                                backgroundColor: ok ? AppTheme.primary : AppTheme.danger,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Xác Nhận Kích Hoạt VIP Ngay', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Modal gia hạn Shop thủ công
  void _showGrantShopModal(BuildContext context, List<Shop> shops) {
    Shop? selectedShop = shops.isNotEmpty ? shops.first : null;
    int selectedDays = 30;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.add_business_rounded, color: Color(0xFF38EF7D), size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Gia Hạn Dịch Vụ Cửa Hàng (Admin)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text('Chọn Cửa Hàng:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 6),
              DropdownButtonFormField<Shop>(
                value: selectedShop,
                isExpanded: true,
                dropdownColor: AppTheme.cardBackground,
                items: shops.map((s) {
                  return DropdownMenuItem(
                    value: s,
                    child: Text(
                      '${s.name} (${s.subscriptionStatusLabel})',
                      style: const TextStyle(fontSize: 13),
                    ),
                  );
                }).toList(),
                onChanged: (val) => setModalState(() => selectedShop = val),
              ),
              const SizedBox(height: 14),
              const Text('Thời hạn gia hạn:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('30 Ngày (1 Tháng)')),
                      selected: selectedDays == 30,
                      onSelected: (s) {
                        if (s) setModalState(() => selectedDays = 30);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('90 Ngày (3 Tháng)')),
                      selected: selectedDays == 90,
                      onSelected: (s) {
                        if (s) setModalState(() => selectedDays = 90);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: selectedShop == null
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          final subProv = context.read<SubscriptionProvider>();
                          final ok = await subProv.adminGrantShopSubscription(
                            context: context,
                            shop: selectedShop!,
                            days: selectedDays,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ok
                                    ? 'Đã gia hạn thành công $selectedDays ngày cho ${selectedShop!.name}!'
                                    : 'Gia hạn thất bại'),
                                backgroundColor: ok ? const Color(0xFF38EF7D) : AppTheme.danger,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38EF7D),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Xác Nhận Gia Hạn Cửa Hàng', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAdminSepayConfigModal(BuildContext context) async {
    final currentToken = await SepayService.getApiToken();
    final textController = TextEditingController(text: currentToken);

    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.vpn_key_rounded, color: AppTheme.primary, size: 22),
            SizedBox(width: 8),
            Text(
              'Cấu hình SePAY API Token',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nhập SePAY API Token lấy từ https://my.sepay.vn để hệ thống tự động xác nhận khi có tiền vào MBBank (0949614588):',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              decoration: InputDecoration(
                hintText: 'Dán mã API Token tại đây...',
                hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.surfaceLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final token = textController.text.trim();
              if (token.isNotEmpty) {
                await SepayService.saveApiToken(token);
              } else {
                await SepayService.clearApiToken();
              }
              if (ctx.mounted) Navigator.pop(ctx);
              setState(() {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
            ),
            child: const Text('Lưu Token', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
