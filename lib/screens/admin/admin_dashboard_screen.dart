import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../models/shop_model.dart';
import '../../models/notification_model.dart';
import '../../models/chat_model.dart';
import '../../models/shop_report_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_provider.dart';
import '../../providers/shop_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/chat_provider.dart';
import '../../theme/app_theme.dart';
import '../profile/profile_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncAllData();
    });
  }

  Future<void> _syncAllData() async {
    if (!mounted) return;
    await Future.wait([
      context.read<AdminProvider>().refreshAdminData(),
      context.read<ShopProvider>().syncCatalogFromFirestore(),
      context.read<NotificationProvider>().syncSystemNotifications(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final authUser = context.watch<AuthProvider>().currentUser;
    final adminProvider = context.watch<AdminProvider>();

    final tabs = <Widget>[
      _AdminOverviewTab(
        onSwitchTab: (idx) => setState(() => _selectedIndex = idx),
      ),
      const _AdminUsersTab(),
      const _AdminShopsProductsTab(),
      const _AdminCommunityChatTab(),
      const _AdminBroadcastNotificationsTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                color: Colors.black,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'GEAR SPORTS ADMIN',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    'Quản trị hệ thống • ${authUser?.fullName ?? 'Admin'}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Đồng bộ dữ liệu Cloud Firestore',
            onPressed: adminProvider.isLoading ? null : _syncAllData,
            icon: adminProvider.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primary,
                    ),
                  )
                : const Icon(Icons.sync_rounded, color: AppTheme.primary),
          ),
          IconButton(
            tooltip: 'Hồ sơ Admin & Đăng xuất',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
            icon: const Icon(
              Icons.account_circle_outlined,
              color: AppTheme.accent,
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (idx) => setState(() => _selectedIndex = idx),
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppTheme.surface,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: AppTheme.textMuted,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined),
            activeIcon: Icon(Icons.analytics_rounded, color: AppTheme.primary),
            label: 'Tổng Quan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline_rounded),
            activeIcon: Icon(Icons.people_rounded, color: AppTheme.primary),
            label: 'Người Dùng',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront_outlined),
            activeIcon: Icon(Icons.storefront_rounded, color: AppTheme.primary),
            label: 'Shop',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_outlined),
            activeIcon: Icon(Icons.chat_rounded, color: AppTheme.primary),
            label: 'Tin Nhắn',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.campaign_outlined),
            activeIcon: Icon(Icons.campaign_rounded, color: AppTheme.primary),
            label: 'Thông Báo',
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TAB 1: TỔNG QUAN HỆ THỐNG
// ============================================================================
class _AdminOverviewTab extends StatelessWidget {
  final ValueChanged<int> onSwitchTab;

  const _AdminOverviewTab({required this.onSwitchTab});

  @override
  Widget build(BuildContext context) {
    final adminProv = context.watch<AdminProvider>();
    final shopProv = context.watch<ShopProvider>();
    final notifProv = context.watch<NotificationProvider>();

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {
        await Future.wait([
          context.read<AdminProvider>().refreshAdminData(),
          context.read<ShopProvider>().syncCatalogFromFirestore(),
          context.read<NotificationProvider>().syncSystemNotifications(),
        ]);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner trạng thái kết nối Cloud Firestore
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppTheme.cardGradient,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.primary.withOpacity(0.45)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cloud_done_rounded,
                      color: AppTheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trung Tâm Quản Trị Cloud Firestore',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Theo dõi số liệu hệ thống, quản lý khóa/xóa tài khoản, phê duyệt cửa hàng và phát thông báo toàn hệ thống.',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            const Text(
              'Số Liệu Thống Kê Thời Gian Thực',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Grid 4 chỉ số Tài khoản & Shop
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.42,
              children: [
                _AdminMetricCard(
                  title: 'Tổng Tài Khoản',
                  value: '${adminProv.totalUsersCount}',
                  subtitle:
                      '${adminProv.playerCount} Player • ${adminProv.stringerCount} Shop',
                  icon: Icons.people_alt_rounded,
                  color: AppTheme.primary,
                  onTap: () => onSwitchTab(1),
                ),
                _AdminMetricCard(
                  title: 'Tài Khoản Bị Khóa',
                  value: '${adminProv.blockedUsersCount}',
                  subtitle: '${adminProv.adminCount} Quản trị viên',
                  icon: Icons.block_rounded,
                  color: AppTheme.danger,
                  onTap: () => onSwitchTab(1),
                ),
                _AdminMetricCard(
                  title: 'Shop Được Phê Duyệt',
                  value: '${shopProv.verifiedShopsCount}',
                  subtitle:
                      '${shopProv.mapsShopsCount} Điểm Google Maps hoạt động',
                  icon: Icons.verified_user_rounded,
                  color: AppTheme.primary,
                  onTap: () => onSwitchTab(2),
                ),
                _AdminMetricCard(
                  title: 'Shop Chờ Phê Duyệt',
                  value: '${shopProv.pendingShopsCount}',
                  subtitle:
                      '${shopProv.disabledShopsCount} Shop đã vô hiệu hóa',
                  icon: Icons.pending_actions_rounded,
                  color: AppTheme.accent,
                  onTap: () => onSwitchTab(2),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Card Thông báo phát hành trải ngang cân đối bên dưới
            InkWell(
              onTap: () => onSwitchTab(3),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFAA00FF).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.campaign_rounded,
                        color: Color(0xFFAA00FF),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Thông Báo Phát Hành Hệ Thống',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Tổng số thông báo & khuyến mãi đã gửi tới người dùng',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${notifProv.notifications.length}',
                      style: const TextStyle(
                        color: Color(0xFFAA00FF),
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AdminMetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TAB 2: QUẢN LÝ NGƯỜI DÙNG (CLICK VÀO Ô USER ĐỂ XEM CHI TIẾT + DROPDOWN GỌN GÀNG)
// ============================================================================
class _AdminUsersTab extends StatefulWidget {
  const _AdminUsersTab();

  @override
  State<_AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<_AdminUsersTab> {
  String _searchQuery = '';
  String _roleFilter = 'all'; // all, player, stringer, admin
  final _dateFmt = DateFormat('dd/MM/yyyy');

  void _showUserDetailDialog(BuildContext context, UserModel user) {
    Color roleColor = AppTheme.primary;
    if (user.role == UserRole.stringer) {
      roleColor = AppTheme.primaryDark;
    } else if (user.role == UserRole.admin) {
      roleColor = AppTheme.accent;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: roleColor.withOpacity(0.15),
              child: Text(
                user.fullName.isNotEmpty
                    ? user.fullName.trim()[0].toUpperCase()
                    : 'U',
                style: TextStyle(
                  color: roleColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    user.role.displayName,
                    style: TextStyle(
                      color: roleColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(color: AppTheme.border),
            const SizedBox(height: 8),
            _detailRow(
              Icons.email_outlined,
              'Email đăng nhập',
              user.email,
            ),
            const SizedBox(height: 10),
            _detailRow(
              Icons.phone_outlined,
              'Số điện thoại',
              user.phone.isEmpty ? 'Chưa cập nhật' : user.phone,
            ),
            const SizedBox(height: 10),
            _detailRow(
              Icons.calendar_today_outlined,
              'Ngày tạo tài khoản',
              _dateFmt.format(user.createdAt),
            ),
            const SizedBox(height: 10),
            _detailRow(
              Icons.verified_user_outlined,
              'Trạng thái',
              user.isBlocked ? 'Đang bị khóa (Blocked)' : 'Đang hoạt động',
              valueColor: user.isBlocked ? AppTheme.danger : AppTheme.primary,
            ),
            if (user.shopName != null && user.shopName!.isNotEmpty) ...[
              const SizedBox(height: 10),
              _detailRow(
                Icons.storefront_rounded,
                'Cửa hàng quản lý',
                user.shopName!,
                valueColor: AppTheme.primaryDark,
              ),
            ],
            if (user.playStyle.isNotEmpty) ...[
              const SizedBox(height: 10),
              _detailRow(
                Icons.bolt_rounded,
                'Mô tả / Lối chơi',
                user.playStyle,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Đóng',
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: AppTheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? AppTheme.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmDeleteUser(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Xóa vĩnh viễn tài khoản?',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa tài khoản "${user.fullName}" (${user.email}) khỏi hệ thống Cloud Firestore không?',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Hủy',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AdminProvider>().deleteUserByAdmin(user);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã xóa tài khoản ${user.email}!'),
                    backgroundColor: AppTheme.danger,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa Tài Khoản'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adminProv = context.watch<AdminProvider>();
    final currentAdminUid = context.watch<AuthProvider>().currentUser?.uid;

    final filteredUsers = adminProv.users.where((u) {
      final matchesRole = _roleFilter == 'all' || u.role.name == _roleFilter;
      final q = _searchQuery.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          u.fullName.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          u.phone.toLowerCase().contains(q);
      return matchesRole && matchesSearch;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: const InputDecoration(
              hintText: 'Tìm theo tên, email hoặc số điện thoại...',
              prefixIcon: Icon(Icons.search_rounded, color: AppTheme.primary),
            ),
          ),
        ),
        // Dropdown lọc nhóm tài khoản (không có labelText)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: DropdownButtonFormField<String>(
            value: _roleFilter,
            isExpanded: true,
            dropdownColor: AppTheme.surface,
            decoration: const InputDecoration(
              prefixIcon: Icon(
                Icons.filter_list_rounded,
                color: AppTheme.primary,
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
            items: [
              DropdownMenuItem(
                value: 'all',
                child: Text(
                  'Tất cả tài khoản (${adminProv.totalUsersCount})',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: 'player',
                child: Text(
                  'Người chơi (${adminProv.playerCount})',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: 'stringer',
                child: Text(
                  'Chủ Shop (${adminProv.stringerCount})',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: 'admin',
                child: Text(
                  'Quản trị viên - Admin (${adminProv.adminCount})',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() => _roleFilter = val);
              }
            },
          ),
        ),
        Expanded(
          child: filteredUsers.isEmpty
              ? const Center(
                  child: Text(
                    'Không tìm thấy tài khoản người dùng nào.',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, idx) {
                    final u = filteredUsers[idx];
                    final isSelf = u.uid == currentAdminUid;
                    Color roleColor = AppTheme.primary;
                    if (u.role == UserRole.stringer) {
                      roleColor = AppTheme.primaryDark;
                    } else if (u.role == UserRole.admin) {
                      roleColor = AppTheme.accent;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: u.isBlocked
                              ? AppTheme.danger.withOpacity(0.6)
                              : AppTheme.border,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _showUserDetailDialog(context, u),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor:
                                        roleColor.withOpacity(0.15),
                                    child: Text(
                                      u.fullName.isNotEmpty
                                          ? u.fullName.trim()[0].toUpperCase()
                                          : 'U',
                                      style: TextStyle(
                                        color: roleColor,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          u.fullName,
                                          style: const TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15.5,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: roleColor.withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: roleColor.withOpacity(0.5),
                                            ),
                                          ),
                                          child: Text(
                                            u.role.shortLabel,
                                            style: TextStyle(
                                              color: roleColor,
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        if (u.isBlocked)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.danger
                                                  .withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'ĐÃ KHÓA',
                                              style: TextStyle(
                                                color: AppTheme.danger,
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppTheme.textMuted,
                                    size: 22,
                                  ),
                                ],
                              ),
                              if (!isSelf) ...[
                                const Divider(
                                  height: 22,
                                  color: AppTheme.border,
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () =>
                                            adminProv.toggleBlockUser(u),
                                        icon: Icon(
                                          u.isBlocked
                                              ? Icons.lock_open_rounded
                                              : Icons.block_rounded,
                                          size: 16,
                                          color: u.isBlocked
                                              ? AppTheme.primary
                                              : AppTheme.accent,
                                        ),
                                        label: Text(
                                          u.isBlocked
                                              ? 'Mở khóa'
                                              : 'Khóa tài khoản',
                                          style: TextStyle(
                                            color: u.isBlocked
                                                ? AppTheme.primary
                                                : AppTheme.accent,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                            horizontal: 8,
                                          ),
                                          side: BorderSide(
                                            color: (u.isBlocked
                                                    ? AppTheme.primary
                                                    : AppTheme.accent)
                                                .withOpacity(0.5),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () =>
                                            _confirmDeleteUser(context, u),
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: AppTheme.danger,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          'Xóa tài khoản',
                                          style: TextStyle(
                                            color: AppTheme.danger,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                            horizontal: 8,
                                          ),
                                          side: BorderSide(
                                            color: AppTheme.danger
                                                .withOpacity(0.5),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ============================================================================
// TAB 3: QUẢN LÝ SHOP (DROPDOWN KHÔNG LABEL + DÃN CÁCH THOÁNG ĐẸP)
// ============================================================================
class _AdminShopsProductsTab extends StatefulWidget {
  const _AdminShopsProductsTab();

  @override
  State<_AdminShopsProductsTab> createState() => _AdminShopsProductsTabState();
}

class _AdminShopsProductsTabState extends State<_AdminShopsProductsTab>
    with SingleTickerProviderStateMixin {
  late TabController _subTabController;
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  String _shopStatusFilter = 'all'; // all, verified, pending, approved, disabled
  String _selectedShopFilterId = 'all';
  String _productCategoryFilter = 'all'; // all, racket, service, string, grip, accessory

  String _shopSearchQuery = '';
  final _shopSearchController = TextEditingController();

  String _productSearchQuery = '';
  final _productSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _subTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _shopSearchController.dispose();
    _productSearchController.dispose();
    _subTabController.dispose();
    super.dispose();
  }

  void _inspectShopItems(String shopId) {
    setState(() {
      _selectedShopFilterId = shopId;
      _productSearchQuery = '';
      _productSearchController.clear();
    });
    _subTabController.animateTo(1);
  }

  Widget _buildProductThumbnail(String imageUrl, {bool isService = false, double size = 48}) {
    if (imageUrl.isNotEmpty) {
      if (imageUrl.startsWith('http')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            imageUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildFallbackIcon(isService, size),
          ),
        );
      } else {
        final f = File(imageUrl);
        if (f.existsSync()) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              f,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildFallbackIcon(isService, size),
            ),
          );
        }
      }
    }
    return _buildFallbackIcon(isService, size);
  }

  Widget _buildFallbackIcon(bool isService, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: (isService ? AppTheme.primary : AppTheme.primaryDark).withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        isService ? Icons.handyman_rounded : Icons.sports_tennis_rounded,
        color: isService ? AppTheme.primary : AppTheme.primaryDark,
        size: size * 0.45,
      ),
    );
  }

  void _showShopDetailDialog(BuildContext context, Shop s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.storefront_rounded, color: AppTheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                s.name,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(color: AppTheme.border),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: s.isVerifiedPartner
                      ? AppTheme.primary.withOpacity(0.12)
                      : (s.isPending
                          ? AppTheme.accent.withOpacity(0.12)
                          : (s.isDisabled ? AppTheme.danger.withOpacity(0.12) : AppTheme.surfaceLight)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      s.isVerifiedPartner
                          ? Icons.verified_rounded
                          : (s.isPending ? Icons.pending_rounded : (s.isDisabled ? Icons.block_rounded : Icons.map_rounded)),
                      size: 16,
                      color: s.isVerifiedPartner
                          ? AppTheme.primary
                          : (s.isPending ? AppTheme.accent : (s.isDisabled ? AppTheme.danger : AppTheme.textMuted)),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        s.isVerifiedPartner
                            ? 'Cửa hàng đối tác đã phê duyệt (Đăng bán vật phẩm & dịch vụ)'
                            : (s.isPending
                                ? 'Cửa hàng đang chờ Admin phê duyệt hồ sơ'
                                : (s.isDisabled
                                    ? 'Cửa hàng đã bị vô hiệu hóa'
                                    : 'Địa điểm Google Maps (Không có tài khoản chủ shop trên app)')),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: s.isVerifiedPartner
                              ? AppTheme.primary
                              : (s.isPending ? AppTheme.accent : (s.isDisabled ? AppTheme.danger : AppTheme.textSecondary)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (s.ownerName != null || s.ownerEmail != null) ...[
                Text(
                  '👤 Chủ shop: ${s.ownerName ?? "Chưa rõ"} (${s.ownerEmail ?? ""})',
                  style: const TextStyle(
                    color: AppTheme.primaryDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                '📍 Địa chỉ: ${s.address}, ${s.district}, ${s.city}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '⚙️ Máy đan: ${s.machineModel}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '🏅 Chứng chỉ: ${s.stringerCert}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '📞 SĐT: ${s.phone}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '🕒 Giờ mở cửa: ${s.openHours}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Đóng',
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteShop(BuildContext context, Shop shop) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Xóa cửa hàng khỏi hệ thống?',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa vĩnh viễn cửa hàng "${shop.name}" cùng TOÀN BỘ sản phẩm và dịch vụ của cửa hàng này khỏi Cloud Firestore không?',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Hủy',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<ShopProvider>().deleteShop(shop.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã xóa cửa hàng "${shop.name}"!'),
                    backgroundColor: AppTheme.danger,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa Cửa Hàng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shopProv = context.watch<ShopProvider>();
    final allShops = shopProv.allShopsForAdmin;
    final allProducts = shopProv.allProducts;
    final productShops = allShops
        .where((s) => s.isRegisteredOnApp || allProducts.any((p) => p.shopId == s.id))
        .toList();

    final filteredShops = allShops.where((s) {
      bool matchStatus;
      switch (_shopStatusFilter) {
        case 'verified':
          matchStatus = s.isVerifiedPartner;
          break;
        case 'pending':
          matchStatus = s.isPending;
          break;
        case 'approved':
          matchStatus = (!s.isRegisteredOnApp && s.isApproved);
          break;
        case 'disabled':
          matchStatus = s.isDisabled;
          break;
        case 'all':
        default:
          matchStatus = true;
          break;
      }
      final matchSearch = _shopSearchQuery.isEmpty ||
          s.name.toLowerCase().contains(_shopSearchQuery.toLowerCase()) ||
          s.address.toLowerCase().contains(_shopSearchQuery.toLowerCase());
      return matchStatus && matchSearch;
    }).toList();

    final filteredProducts = allProducts.where((p) {
      final matchShop = _selectedShopFilterId == 'all' ||
          p.shopId == _selectedShopFilterId ||
          p.shopId == 'all';
      final matchCat = _productCategoryFilter == 'all' ||
          p.category.name == _productCategoryFilter;
      final matchSearch = _selectedShopFilterId == 'all' ||
          _productSearchQuery.isEmpty ||
          p.name.toLowerCase().contains(_productSearchQuery.toLowerCase());
      return matchShop && matchCat && matchSearch;
    }).toList();

    return Column(
      children: [
        Container(
          color: AppTheme.surface,
          child: TabBar(
            controller: _subTabController,
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            tabs: [
              Tab(text: 'Duyệt & Quản Lý Shop (${allShops.length})'),
              Tab(text: 'Duyệt Vật Phẩm & Dịch Vụ (${allProducts.length})'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _subTabController,
            children: [
              // --------------------------------------------------------------
              // SUB-TAB 1: PHÊ DUYỆT, VÔ HIỆU HÓA & XÓA SHOP
              // --------------------------------------------------------------
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                    child: DropdownButtonFormField<String>(
                      value: _shopStatusFilter,
                      isExpanded: true,
                      dropdownColor: AppTheme.surface,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(
                          Icons.filter_list_rounded,
                          color: AppTheme.primary,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text(
                            'Tất cả cửa hàng (${allShops.length})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'verified',
                          child: Row(
                            children: [
                              const Icon(Icons.verified_rounded, size: 16, color: AppTheme.primary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Được phê duyệt (${shopProv.verifiedShopsCount})',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'pending',
                          child: Text(
                            'Chờ phê duyệt (${shopProv.pendingShopsCount})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'approved',
                          child: Text(
                            'Đang hoạt động - Google Maps (${shopProv.mapsShopsCount})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'disabled',
                          child: Text(
                            'Đã vô hiệu hóa (${shopProv.disabledShopsCount})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _shopStatusFilter = val);
                        }
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: TextField(
                      controller: _shopSearchController,
                      onChanged: (val) => setState(() => _shopSearchQuery = val.trim()),
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm cửa hàng theo tên hoặc địa chỉ...',
                        hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primary, size: 20),
                        suffixIcon: _shopSearchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18, color: AppTheme.textMuted),
                                onPressed: () {
                                  _shopSearchController.clear();
                                  setState(() => _shopSearchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppTheme.surface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.primary),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: filteredShops.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Không có cửa hàng nào trong mục này.\nKhi Chủ Shop đăng ký tài khoản, thông tin cửa hàng sẽ hiển thị tại đây để Admin phê duyệt.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppTheme.textMuted),
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 40),
                            itemCount: filteredShops.length,
                            itemBuilder: (context, idx) {
                              final s = filteredShops[idx];
                              final dupShop = shopProv.findDuplicateShopByLocation(
                                s.latitude,
                                s.longitude,
                                excludeShopId: s.id,
                              );
                              Color statusColor = AppTheme.primary;
                              if (s.isVerifiedPartner) {
                                statusColor = AppTheme.primary;
                              } else if (s.isPending) {
                                statusColor = AppTheme.accent;
                              } else if (s.isDisabled) {
                                statusColor = AppTheme.danger;
                              } else {
                                statusColor = AppTheme.primaryDark;
                              }

                              final shopItemCount = allProducts
                                  .where((p) => p.shopId == s.id)
                                  .length;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: s.isPending
                                        ? AppTheme.accent.withOpacity(0.6)
                                        : (s.isDisabled
                                            ? AppTheme.danger.withOpacity(0.5)
                                            : (s.isVerifiedPartner
                                                ? AppTheme.primary.withOpacity(0.5)
                                                : AppTheme.border)),
                                  ),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () =>
                                      _showShopDetailDialog(context, s),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.storefront_rounded,
                                              color: AppTheme.primary,
                                              size: 22,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                s.name,
                                                style: const TextStyle(
                                                  color: AppTheme.textPrimary,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15.5,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: statusColor
                                                    .withOpacity(0.16),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: statusColor
                                                      .withOpacity(0.5),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (s.isVerifiedPartner) ...[
                                                    const Icon(
                                                      Icons.verified_rounded,
                                                      size: 13,
                                                      color: AppTheme.primary,
                                                    ),
                                                    const SizedBox(width: 3),
                                                  ],
                                                  Text(
                                                    s.statusDisplayName,
                                                    style: TextStyle(
                                                      color: statusColor,
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(
                                              Icons.chevron_right_rounded,
                                              color: AppTheme.textMuted,
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        if (s.isRegisteredOnApp)
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.person_outline_rounded,
                                                size: 14,
                                                color: AppTheme.primary,
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  'Chủ shop: ${s.ownerName ?? "Thợ đan"}${s.ownerEmail != null ? " (${s.ownerEmail})" : ""}',
                                                  style: const TextStyle(
                                                    color: AppTheme.primary,
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          )
                                        else
                                          const Row(
                                            children: [
                                              Icon(
                                                Icons.map_outlined,
                                                size: 14,
                                                color: AppTheme.textMuted,
                                              ),
                                              SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  'Địa điểm Google Maps • Chưa có chủ gian hàng',
                                                  style: TextStyle(
                                                    color: AppTheme.textMuted,
                                                    fontSize: 11.5,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${s.address}, ${s.district}',
                                          style: const TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (dupShop != null) ...[
                                          const SizedBox(height: 10),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.danger.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: AppTheme.danger.withOpacity(0.4),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.warning_amber_rounded,
                                                  color: AppTheme.danger,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    'Cảnh báo: Trùng vị trí với "${dupShop.name}" (${s.latitude.toStringAsFixed(4)}, ${s.longitude.toStringAsFixed(4)})',
                                                    style: const TextStyle(
                                                      color: AppTheme.danger,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 12),
                                        if (s.isVerifiedPartner)
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton.icon(
                                              onPressed: () =>
                                                  _inspectShopItems(s.id),
                                              icon: const Icon(
                                                Icons.fact_check_outlined,
                                                size: 16,
                                                color: Colors.black,
                                              ),
                                              label: Text(
                                                'Xem vật phẩm & dịch vụ đăng bán ($shopItemCount)',
                                                style: const TextStyle(
                                                  color: Colors.black,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppTheme.primary,
                                                foregroundColor: Colors.black,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  vertical: 10,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                            ),
                                          )
                                        else if (s.isPending)
                                          SizedBox(
                                            width: double.infinity,
                                            child: OutlinedButton.icon(
                                              onPressed: () =>
                                                  _inspectShopItems(s.id),
                                              icon: const Icon(
                                                Icons.fact_check_outlined,
                                                size: 16,
                                                color: AppTheme.accent,
                                              ),
                                              label: Text(
                                                'Xem vật phẩm & dịch vụ chờ duyệt ($shopItemCount)',
                                                style: const TextStyle(
                                                  color: AppTheme.accent,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  vertical: 10,
                                                ),
                                                side: BorderSide(
                                                  color: AppTheme.accent
                                                      .withOpacity(0.6),
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                            ),
                                          )
                                        else
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 9,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.surfaceLight,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: AppTheme.border,
                                              ),
                                            ),
                                            child: const Row(
                                              children: [
                                                Icon(
                                                  Icons.info_outline_rounded,
                                                  size: 15,
                                                  color: AppTheme.textMuted,
                                                ),
                                                SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    'Địa điểm Google Maps (không có chủ shop đăng bán vật phẩm & dịch vụ)',
                                                    style: TextStyle(
                                                      color: AppTheme.textMuted,
                                                      fontSize: 11.5,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            if (s.isPending ||
                                                s.isDisabled) ...[
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  onPressed: () async {
                                                    await shopProv
                                                        .updateShopStatus(
                                                      s,
                                                      'approved',
                                                    );
                                                    if (context.mounted) {
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            'Đã phê duyệt cửa hàng "${s.name}" hoạt động!',
                                                          ),
                                                          backgroundColor:
                                                              AppTheme
                                                                  .primaryDark,
                                                        ),
                                                      );
                                                    }
                                                  },
                                                  icon: const Icon(
                                                    Icons.check_circle_outline,
                                                    size: 16,
                                                  ),
                                                  label: Text(
                                                    s.isPending
                                                        ? 'Phê duyệt'
                                                        : 'Kích hoạt lại',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      vertical: 10,
                                                      horizontal: 8,
                                                    ),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        10,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                            ],
                                            if (!s.isDisabled) ...[
                                              Expanded(
                                                child: OutlinedButton.icon(
                                                  onPressed: () async {
                                                    await shopProv
                                                        .updateShopStatus(
                                                      s,
                                                      'disabled',
                                                    );
                                                    if (context.mounted) {
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            'Đã vô hiệu hóa cửa hàng "${s.name}"!',
                                                          ),
                                                          backgroundColor:
                                                              AppTheme.danger,
                                                        ),
                                                      );
                                                    }
                                                  },
                                                  icon: const Icon(
                                                    Icons.block_rounded,
                                                    size: 15,
                                                    color: AppTheme.accent,
                                                  ),
                                                  label: const Text(
                                                    'Vô hiệu hóa',
                                                    style: TextStyle(
                                                      color: AppTheme.accent,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      vertical: 10,
                                                      horizontal: 8,
                                                    ),
                                                    side: BorderSide(
                                                      color: AppTheme.accent
                                                          .withOpacity(0.6),
                                                    ),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        10,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                            ],
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                onPressed: () =>
                                                    _confirmDeleteShop(
                                                  context,
                                                  s,
                                                ),
                                                icon: const Icon(
                                                  Icons.delete_outline_rounded,
                                                  size: 16,
                                                  color: AppTheme.danger,
                                                ),
                                                label: const Text(
                                                  'Xóa cửa hàng',
                                                  style: TextStyle(
                                                    color: AppTheme.danger,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                style: OutlinedButton.styleFrom(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    vertical: 10,
                                                    horizontal: 8,
                                                  ),
                                                  side: BorderSide(
                                                    color: AppTheme.danger
                                                        .withOpacity(0.5),
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      10,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),

              // --------------------------------------------------------------
              // SUB-TAB 2: KIỂM DUYỆT VẬT PHẨM & DỊCH VỤ CHỦ SHOP ĐĂNG BÁN
              // --------------------------------------------------------------
              Column(
                children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                        child: DropdownButtonFormField<String>(
                          value: (productShops.any((s) => s.id == _selectedShopFilterId) || allShops.any((s) => s.id == _selectedShopFilterId))
                              ? _selectedShopFilterId
                              : 'all',
                          isExpanded: true,
                          dropdownColor: AppTheme.surface,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(
                              Icons.store_rounded,
                              color: AppTheme.primary,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'all',
                              child: Text(
                                'Tất cả cửa hàng đối tác đăng bán',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            ...productShops.map(
                              (s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(
                                  '${s.name}${s.isVerifiedPartner ? " (✓ Được phê duyệt)" : ""}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedShopFilterId = val;
                                if (val == 'all') {
                                  _productSearchQuery = '';
                                  _productSearchController.clear();
                                }
                              });
                            }
                          },
                        ),
                      ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: DropdownButtonFormField<String>(
                      value: _productCategoryFilter,
                      isExpanded: true,
                      dropdownColor: AppTheme.surface,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(
                          Icons.category_outlined,
                          color: AppTheme.primary,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('Tất cả danh mục'),
                        ),
                        DropdownMenuItem(
                          value: 'racket',
                          child: Text('Vợt cầu lông đăng bán'),
                        ),
                        DropdownMenuItem(
                          value: 'service',
                          child: Text('Dịch vụ đan vợt'),
                        ),
                        DropdownMenuItem(
                          value: 'string',
                          child: Text('Cước căng vợt'),
                        ),
                        DropdownMenuItem(
                          value: 'grip',
                          child: Text('Quấn cán vợt'),
                        ),
                        DropdownMenuItem(
                          value: 'accessory',
                          child: Text('Phụ kiện khác'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _productCategoryFilter = val);
                        }
                      },
                    ),
                  ),
                  // Thanh tìm kiếm bằng tên: CHỈ HIỂN THỊ SAU KHI ĐÃ CHỌN 1 CỬA HÀNG CỤ THỂ
                  if (_selectedShopFilterId != 'all')
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: TextField(
                        controller: _productSearchController,
                        onChanged: (val) =>
                            setState(() => _productSearchQuery = val.trim()),
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13.5,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Tìm kiếm vật phẩm / dịch vụ của shop...',
                          hintStyle: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 13,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppTheme.primary,
                            size: 20,
                          ),
                          suffixIcon: _productSearchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    size: 18,
                                    color: AppTheme.textMuted,
                                  ),
                                  onPressed: () {
                                    _productSearchController.clear();
                                    setState(
                                      () => _productSearchQuery = '',
                                    );
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: AppTheme.surface,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppTheme.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppTheme.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppTheme.primary),
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: filteredProducts.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Chưa có vật phẩm hay dịch vụ nào được Chủ Shop đăng bán trong danh mục này.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppTheme.textMuted),
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 40),
                            itemCount: filteredProducts.length,
                            itemBuilder: (context, idx) {
                              final p = filteredProducts[idx];
                              final ownerShop = shopProv.getShopById(p.shopId);
                              final isOwnerDisabled = ownerShop != null && ownerShop.isDisabled;
                              final baseShopLabel = p.shopName ??
                                  ownerShop?.name ??
                                  (p.shopId == 'all'
                                      ? 'Danh mục chung hệ thống'
                                      : 'Shop ID: ${p.shopId}');
                              final shopLabel = isOwnerDisabled
                                  ? '$baseShopLabel (Shop đã bị vô hiệu hóa ⚠️)'
                                  : baseShopLabel;

                              Color stColor = AppTheme.primary;
                              if (p.isPending) {
                                stColor = AppTheme.accent;
                              } else if (p.isRejected) {
                                stColor = AppTheme.danger;
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: p.isRejected
                                        ? AppTheme.danger.withOpacity(0.5)
                                        : AppTheme.border,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        _buildProductThumbnail(
                                          p.imageUrl,
                                          isService: p.isService,
                                          size: 46,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                p.name,
                                                style: const TextStyle(
                                                  color: AppTheme.textPrimary,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '🏪 $shopLabel',
                                                style: const TextStyle(
                                                  color: AppTheme.primaryDark,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: stColor.withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            p.statusDisplayName,
                                            style: TextStyle(
                                              color: stColor,
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      '${p.categoryName} • ${_currencyFormat.format(p.price)}',
                                      style: const TextStyle(
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      p.description,
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                    const Divider(
                                      height: 20,
                                      color: AppTheme.border,
                                    ),
                                    Row(
                                      children: [
                                        if (!p.isApproved) ...[
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () =>
                                                  shopProv.updateProductStatus(
                                                p,
                                                'approved',
                                              ),
                                              icon: const Icon(
                                                Icons.verified_rounded,
                                                size: 15,
                                              ),
                                              label: const Text(
                                                'Duyệt hợp lệ',
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  vertical: 10,
                                                  horizontal: 6,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        if (!p.isRejected) ...[
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () =>
                                                  shopProv.updateProductStatus(
                                                p,
                                                'rejected',
                                              ),
                                              icon: const Icon(
                                                Icons.report_problem_outlined,
                                                size: 15,
                                                color: AppTheme.accent,
                                              ),
                                              label: const Text(
                                                'Không hợp lệ',
                                                style: TextStyle(
                                                  color: AppTheme.accent,
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  vertical: 10,
                                                  horizontal: 6,
                                                ),
                                                side: BorderSide(
                                                  color: AppTheme.accent
                                                      .withOpacity(0.5),
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () =>
                                                shopProv.deleteProduct(p.id),
                                            icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              size: 15,
                                              color: AppTheme.danger,
                                            ),
                                            label: const Text(
                                              'Xóa bỏ',
                                              style: TextStyle(
                                                color: AppTheme.danger,
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                vertical: 10,
                                                horizontal: 6,
                                              ),
                                              side: BorderSide(
                                                color: AppTheme.danger
                                                    .withOpacity(0.5),
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// TAB 4: PHÁT THÔNG BÁO TOÀN HỆ THỐNG
// ============================================================================
class _AdminBroadcastNotificationsTab extends StatefulWidget {
  const _AdminBroadcastNotificationsTab();

  @override
  State<_AdminBroadcastNotificationsTab> createState() =>
      _AdminBroadcastNotificationsTabState();
}

class _AdminBroadcastNotificationsTabState
    extends State<_AdminBroadcastNotificationsTab> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  NotificationType _selectedType = NotificationType.promo;
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void dispose() {
    _titleCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendBroadcast() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await context.read<NotificationProvider>().broadcastSystemNotification(
          title: _titleCtrl.text,
          message: _msgCtrl.text,
          type: _selectedType,
        );
    _titleCtrl.clear();
    _msgCtrl.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Đã phát thông báo lên Cloud Firestore cho toàn bộ người dùng!',
        ),
        backgroundColor: AppTheme.primaryDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifProv = context.watch<NotificationProvider>();
    final notifs = notifProv.notifications;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.campaign_rounded,
                      color: AppTheme.primary,
                      size: 22,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tạo & Phát Thông Báo Hệ Thống',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<NotificationType>(
                  value: _selectedType,
                  isExpanded: true,
                  dropdownColor: AppTheme.surface,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(
                      Icons.category_outlined,
                      color: AppTheme.primary,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: NotificationType.promo,
                      child: Text(
                        '🎉 Khuyến mãi / Tin tức cộng đồng',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: NotificationType.tensionAlert,
                      child: Text(
                        '⚠️ Cảnh báo kỹ thuật & bảo dưỡng vợt',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: NotificationType.orderStatus,
                      child: Text(
                        '🏸 Thông báo dịch vụ & hệ thống',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedType = v);
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tiêu đề thông báo *',
                    hintText: 'VD: Ưu đãi đan cước cuối tuần giảm 20%',
                    prefixIcon: Icon(
                      Icons.title_rounded,
                      color: AppTheme.primary,
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Vui lòng nhập tiêu đề'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _msgCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Nội dung chi tiết *',
                    hintText: 'Nhập nội dung gửi tới toàn bộ người dùng...',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Vui lòng nhập nội dung'
                      : null,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _sendBroadcast,
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text(
                      'Phát Thông Báo Lên Cloud Firestore',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Lịch Sử Thông Báo Đã Phát (${notifs.length})',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (notifs.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Center(
              child: Text(
                'Chưa có thông báo hệ thống nào được phát hành.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted),
              ),
            ),
          )
        else
          for (final n in notifs)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.notifications_active_rounded,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              n.title,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _dateFormat.format(n.timestamp),
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Xóa thông báo',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppTheme.danger,
                          size: 20,
                        ),
                        onPressed: () =>
                            notifProv.deleteSystemNotification(n.id),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    n.message,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

// ==========================================
// TAB 4: GIÁM SÁT TIN NHẮN & TIÊU CHUẨN CỘNG ĐỒNG
// ==========================================
class _AdminCommunityChatTab extends StatefulWidget {
  const _AdminCommunityChatTab();

  @override
  State<_AdminCommunityChatTab> createState() => _AdminCommunityChatTabState();
}

class _AdminCommunityChatTabState extends State<_AdminCommunityChatTab> {
  final _searchController = TextEditingController();
  final _timeFormat = DateFormat('dd/MM HH:mm');
  String _searchQuery = '';
  int _activeSubTab = 0; // 0: Cuộc trò chuyện, 1: Đơn báo cáo vi phạm

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showChatTranscriptDialog(BuildContext context, ChatThread thread) {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final chatProv = dialogCtx.watch<ChatProvider>();
            final currentThread = chatProv.getThread(thread.id);
            if (currentThread == null) {
              return AlertDialog(
                backgroundColor: AppTheme.surface,
                title: const Text('Cuộc trò chuyện không tồn tại hoặc đã bị xóa'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text('Đóng'),
                  ),
                ],
              );
            }

            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.security_rounded, color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kiểm duyệt: ${currentThread.shopName}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Mã luồng: ${currentThread.id} • ${currentThread.messages.length} tin nhắn',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 440,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.policy_rounded, color: AppTheme.accent, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Admin có quyền xóa tin nhắn ngôn từ thù địch, quấy rối hoặc giao dịch gian lận.',
                              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: currentThread.messages.isEmpty
                          ? const Center(
                              child: Text(
                                'Cuộc hội thoại chưa có tin nhắn nào.',
                                style: TextStyle(color: AppTheme.textMuted),
                              ),
                            )
                          : ListView.builder(
                              itemCount: currentThread.messages.length,
                              itemBuilder: (c, idx) {
                                final msg = currentThread.messages[idx];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: msg.isFromUser
                                        ? AppTheme.surfaceLight
                                        : AppTheme.primary.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: msg.isFromUser
                                          ? AppTheme.border
                                          : AppTheme.primary.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                msg.isFromUser
                                                    ? Icons.person_rounded
                                                    : Icons.storefront_rounded,
                                                size: 14,
                                                color: msg.isFromUser
                                                    ? AppTheme.accent
                                                    : AppTheme.primary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                msg.isFromUser
                                                    ? 'Khách hàng'
                                                    : 'Shop (${currentThread.shopName})',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                  color: msg.isFromUser
                                                      ? AppTheme.accent
                                                      : AppTheme.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Text(
                                                _timeFormat.format(msg.timestamp),
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: AppTheme.textMuted,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              IconButton(
                                                tooltip: 'Xóa tin nhắn vi phạm này',
                                                constraints: const BoxConstraints(),
                                                padding: EdgeInsets.zero,
                                                icon: const Icon(
                                                  Icons.delete_outline_rounded,
                                                  color: AppTheme.danger,
                                                  size: 16,
                                                ),
                                                onPressed: () {
                                                  chatProv.deleteMessage(currentThread.id, msg.id);
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        msg.text,
                                        style: const TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                      if (msg.attachedRacketName != null) ...[
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppTheme.background,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppTheme.border),
                                          ),
                                          child: Text(
                                            '🏸 Vợt: ${msg.attachedRacketName} (${msg.attachedTension ?? "Chưa rõ"} kg)',
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              color: AppTheme.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton.icon(
                  onPressed: () async {
                    final notifProv = dialogCtx.read<NotificationProvider>();
                    await notifProv.broadcastSystemNotification(
                      title: 'Cảnh báo tiêu chuẩn cộng đồng',
                      message: 'Hệ thống nhắc nhở các bên liên quan tuân thủ văn hóa ứng xử và bảo mật trong trao đổi tin nhắn.',
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã phát hành cảnh báo tiêu chuẩn cộng đồng đến hệ thống!'),
                          backgroundColor: AppTheme.accent,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.warning_amber_rounded, size: 16, color: AppTheme.accent),
                  label: const Text('Phát cảnh báo', style: TextStyle(color: AppTheme.accent, fontSize: 12)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Đóng', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteThread(BuildContext context, ChatThread thread) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Xóa toàn bộ cuộc trò chuyện?',
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa vĩnh viễn đoạn chat giữa người dùng và "${thread.shopName}" do vi phạm tiêu chuẩn cộng đồng không?',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<ChatProvider>().deleteThread(thread.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã xóa cuộc hội thoại khỏi hệ thống!'),
                  backgroundColor: AppTheme.danger,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Xác nhận xóa', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatProv = context.watch<ChatProvider>();
    final allThreads = chatProv.threads;

    final filteredThreads = allThreads.where((t) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return t.shopName.toLowerCase().contains(q) ||
          t.lastMessage.toLowerCase().contains(q) ||
          t.messages.any((m) => m.text.toLowerCase().contains(q));
    }).toList();

    final totalMessages = allThreads.fold(0, (sum, t) => sum + t.messages.length);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.mark_chat_unread_rounded, color: AppTheme.primary, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Giám sát Tin nhắn & Tiêu chuẩn',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Kiểm duyệt đoạn chat giữa khách hàng & tiệm đan vợt',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Thống kê nhanh
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Hội thoại', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    const SizedBox(height: 4),
                    Text(
                      '${allThreads.length}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tin nhắn', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    const SizedBox(height: 4),
                    Text(
                      '$totalMessages',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.accent),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: chatProv.pendingReportsCount > 0 ? AppTheme.danger : AppTheme.border,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Đơn báo cáo', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${chatProv.reports.length}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: chatProv.pendingReportsCount > 0 ? AppTheme.danger : AppTheme.textPrimary,
                          ),
                        ),
                        if (chatProv.pendingReportsCount > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.danger,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${chatProv.pendingReportsCount} mới',
                              style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Subtabs: Cuộc trò chuyện vs Đơn Báo Cáo
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _activeSubTab = 0),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _activeSubTab == 0 ? AppTheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        'Cuộc trò chuyện (${filteredThreads.length})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _activeSubTab == 0 ? Colors.black : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _activeSubTab = 1),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _activeSubTab == 1 ? AppTheme.danger : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.gavel_rounded,
                            size: 14,
                            color: _activeSubTab == 1 ? Colors.white : AppTheme.danger,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Đơn Báo Cáo (${chatProv.reports.length})',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _activeSubTab == 1 ? Colors.white : AppTheme.danger,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (_activeSubTab == 0) ...[
          // Ô tìm kiếm cuộc trò chuyện
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'Tìm theo tên shop, nội dung trao đổi...',
              hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textMuted, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18, color: AppTheme.textMuted),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppTheme.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.primary),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Danh sách các luồng chat
          if (filteredThreads.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Center(
                child: Text(
                  'Không tìm thấy cuộc trò chuyện nào phù hợp.',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
              ),
            )
          else
            ...filteredThreads.map((thread) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
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
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppTheme.primaryDark.withOpacity(0.2),
                          child: Text(
                            thread.shopName.isNotEmpty ? thread.shopName[0].toUpperCase() : 'S',
                            style: const TextStyle(
                              color: AppTheme.primaryDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                thread.shopName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.5,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${thread.messages.length} tin nhắn • Cập nhật: ${_timeFormat.format(thread.lastMessageTime)}',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Hoạt động',
                            style: TextStyle(
                              color: AppTheme.accent,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Text(
                        '💬 Tin gần nhất: "${thread.lastMessage}"',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showChatTranscriptDialog(context, thread),
                            icon: const Icon(Icons.visibility_rounded, size: 16),
                            label: const Text('Xem & Kiểm duyệt', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Xóa toàn bộ cuộc trò chuyện',
                          icon: const Icon(Icons.delete_forever_rounded, color: AppTheme.danger, size: 22),
                          onPressed: () => _confirmDeleteThread(context, thread),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ] else ...[
          // ================= TAB ĐƠN BÁO CÁO VI PHẠM TỪ NGƯỜI CHƠI =================
          if (chatProv.reports.isEmpty)
            Container(
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Column(
                children: [
                  Icon(Icons.verified_rounded, size: 40, color: AppTheme.primary),
                  SizedBox(height: 10),
                  Text(
                    'Không có đơn báo cáo vi phạm nào',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tất cả các cuộc trò chuyện và giao dịch đan vợt hiện đều tuân thủ tiêu chuẩn cộng đồng.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
            )
          else
            ...chatProv.reports.map((ShopReport report) {
              final shopProv = context.read<ShopProvider>();

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: report.isPending ? AppTheme.danger.withOpacity(0.5) : AppTheme.border,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Shop name & status badge
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: report.isPending
                                ? AppTheme.danger.withOpacity(0.15)
                                : AppTheme.primary.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            report.isPending ? Icons.warning_rounded : Icons.check_circle_rounded,
                            color: report.isPending ? AppTheme.danger : AppTheme.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Shop bị báo cáo: ${report.shopName}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.5,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                'Thời gian: ${_timeFormat.format(report.createdAt)}',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: report.isPending
                                ? AppTheme.danger.withOpacity(0.15)
                                : AppTheme.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            report.statusDisplayName,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: report.isPending ? AppTheme.danger : AppTheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20, color: AppTheme.border),

                    // Reporter details
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, size: 15, color: AppTheme.textMuted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Người khiếu nại: ${report.reporterName} (${report.reporterEmail})',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Violation Reason tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.danger.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.gavel_rounded, color: AppTheme.danger, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Hành vi: ${report.reason}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.danger,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Description text
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nội dung phản ánh chi tiết:',
                            style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            report.description,
                            style: const TextStyle(fontSize: 12.5, color: AppTheme.textPrimary, height: 1.4),
                          ),
                        ],
                      ),
                    ),

                    // Evidence if available
                    if (report.chatEvidence != null && report.chatEvidence!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.chat_bubble_outline_rounded, size: 14, color: AppTheme.accent),
                                SizedBox(width: 6),
                                Text(
                                  'Bằng chứng đoạn chat đính kèm:',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.accent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              report.chatEvidence!,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppTheme.textSecondary,
                                fontStyle: FontStyle.italic,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Admin Action Buttons
                    Row(
                      children: [
                        if (report.isPending) ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (dlgCtx) => AlertDialog(
                                    backgroundColor: AppTheme.surface,
                                    title: const Text('Đình chỉ cửa hàng vi phạm?'),
                                    content: Text(
                                      'Bạn có chắc chắn muốn đình chỉ/vô hiệu hóa "${report.shopName}" ngay lập tức do có hành vi gian dối theo đơn báo cáo này?',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dlgCtx),
                                        child: const Text('Hủy'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () async {
                                          Navigator.pop(dlgCtx);
                                          // Disable the shop
                                          await shopProv.approveShop(report.shopId, true);
                                          // Resolve the report
                                          await chatProv.resolveReport(
                                            report.id,
                                            adminNote: 'Admin đã đình chỉ hoạt động cửa hàng',
                                          );
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Đã đình chỉ hoạt động của shop "${report.shopName}"!',
                                                ),
                                                backgroundColor: AppTheme.danger,
                                              ),
                                            );
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
                                        child: const Text('Đình chỉ shop'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              icon: const Icon(Icons.block_rounded, size: 15),
                              label: const Text('Đình chỉ Shop', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.danger,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await chatProv.resolveReport(report.id, adminNote: 'Admin đã xác minh và xử lý thỏa đáng');
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Đã đánh dấu đơn báo cáo là Đã giải quyết!'),
                                      backgroundColor: AppTheme.primary,
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.check_circle_outline_rounded, size: 15, color: AppTheme.primary),
                              label: const Text('Đã giải quyết', style: TextStyle(fontSize: 11.5, color: AppTheme.primary)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppTheme.primary),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ] else ...[
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Text(
                                  '✓ Hồ sơ khiếu nại này đã được xử lý',
                                  style: TextStyle(fontSize: 12, color: AppTheme.primary),
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Xóa đơn báo cáo này',
                          icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.textMuted, size: 20),
                          onPressed: () async {
                            await chatProv.deleteReport(report.id);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ],
    );
  }
}
