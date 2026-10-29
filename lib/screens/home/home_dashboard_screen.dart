import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/shop_model.dart';
import '../../providers/racket_provider.dart';
import '../../providers/shop_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/injury_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/racket_card.dart';
import '../../widgets/shop_card.dart';
import '../gear/gear_detail_screen.dart';
import '../gear/add_edit_racket_screen.dart';
import '../shop/shop_detail_screen.dart';
import '../chat/chat_screen.dart';
import '../profile/profile_screen.dart';
import '../sport/sport_selection_screen.dart';
import '../injury/injury_assessment_screen.dart';
import '../injury/injury_history_screen.dart';
import '../auth/login_register_screen.dart';

class HomeDashboardScreen extends StatelessWidget {
  final Function(int)? onNavigateTab;

  const HomeDashboardScreen({super.key, this.onNavigateTab});

  Future<void> _openShopGoogleMaps(BuildContext context, Shop shop) async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${shop.latitude},${shop.longitude}',
    );
    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tọa độ ${shop.name}: ${shop.latitude}, ${shop.longitude}'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tọa độ ${shop.name}: ${shop.latitude}, ${shop.longitude}'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final racketProvider = context.watch<RacketProvider>();
    final shopProvider = context.watch<ShopProvider>();
    final notifProvider = context.watch<NotificationProvider>();
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.currentUser;

    final rackets = racketProvider.allRackets;
    final alertRackets = racketProvider.racketsNeedingRestring;
    // Trang chủ chỉ hiển thị mặc định các tiệm đan vợt trong bán kính 2 km
    final shops = shopProvider.shops
        .where((s) => s.distanceKm <= 2.0)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const SportSelectionScreen()),
            );
          },
          borderRadius: BorderRadius.circular(10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.sports_tennis_rounded,
                  color: Colors.black,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GEAR SPORTS',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Text(
                    '🏸 Cầu Lông • Đổi bộ môn ▾',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          // Notification bell
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded),
                onPressed: () {
                  onNavigateTab?.call(4); // Switch to Notifications Tab
                },
              ),
              if (notifProvider.unreadCount > 0)
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
                      '${notifProvider.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // User Profile & Logout button
          IconButton(
            tooltip: 'Hồ sơ & Đăng xuất',
            icon: const Icon(
              Icons.account_circle_outlined,
              color: AppTheme.primary,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome & Player Status Card (Click để mở Hồ sơ cá nhân & Đăng xuất)
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppTheme.cardGradient,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppTheme.surfaceLight,
                      child: Text(
                        (currentUser?.fullName.isNotEmpty == true)
                            ? currentUser!.fullName.trim()[0].toUpperCase()
                            : 'C',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Chào bạn, ${currentUser?.fullName ?? 'Người chơi'}!',
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppTheme.primary.withOpacity(0.5),
                                  ),
                                ),
                                child: Text(
                                  currentUser?.role.shortLabel ?? 'Người chơi',
                                  style: const TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentUser?.playStyle ??
                                'Lối chơi: Thiên công 4U • Sẵn sàng ra sân 🏸',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.textMuted,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Card Theo Dõi Thể Lực / Chấn Thương Thể Thao
            _buildInjuryCard(context),

            // Emergency Restring Alert Banner (Theo Luồng Sơ Đồ Home -> Notifications / Gear Detail)
            if (alertRackets.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.danger.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: AppTheme.danger,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Cảnh báo: Có ${alertRackets.length} cây vợt cần thay cước gấp!',
                            style: const TextStyle(
                              color: AppTheme.danger,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cây ${alertRackets.first.brand} ${alertRackets.first.modelName} cước đã chùng -${alertRackets.first.tensionLossPercent}%. Hãy đan lại để phòng tránh chấn thương cổ tay!',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GearDetailScreen(
                                  racketId: alertRackets.first.id,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.danger,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          child: const Text('Xem Vợt Này'),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: () =>
                              onNavigateTab?.call(2), // Switch to Shop Map
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textPrimary,
                            side: const BorderSide(color: AppTheme.border),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                          child: const Text('Tìm Tiệm Đan Gần Nhất'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Quick Shortcut Actions
            Row(
              children: [
                _shortcutButton(
                  icon: Icons.flash_on_rounded,
                  label: 'Đan Vợt Ngay',
                  color: AppTheme.primary,
                  onTap: () => onNavigateTab?.call(2), // Shop Map
                ),
                const SizedBox(width: 8),
                _shortcutButton(
                  icon: Icons.add_rounded,
                  label: 'Thêm Vợt',
                  color: AppTheme.primaryDark,
                  onTap: () {
                    final authProv = context.read<AuthProvider>();
                    final racketProv = context.read<RacketProvider>();
                    if (authProv.isGuest && racketProv.allRackets.length >= 3) {
                      _openFeatureOrPromptLogin(
                        context,
                        screen: const SizedBox(),
                        featureName: 'Thêm hơn 3 cây vợt vào Gara',
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddEditRacketScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                _shortcutButton(
                  icon: Icons.healing_rounded,
                  label: 'Bác Sĩ Thể Thao',
                  color: AppTheme.accent,
                  onTap: () {
                    _openFeatureOrPromptLogin(
                      context,
                      screen: const InjuryAssessmentScreen(),
                      featureName: 'Bác sĩ thể thao & Chuẩn đoán chấn thương',
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Section: Gara Vợt Nhanh (Top Rackets)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Gara Vợt Của Tôi',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () => onNavigateTab?.call(1), // Gear List tab
                  child: const Text(
                    'Xem tất cả ➔',
                    style: TextStyle(color: AppTheme.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // List of top 2-3 rackets
            if (rackets.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.sports_tennis_rounded,
                      color: AppTheme.textMuted,
                      size: 40,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Gara vợt của bạn đang trống',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddEditRacketScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Thêm Vợt Đầu Tiên'),
                    ),
                  ],
                ),
              )
            else
              for (var r in rackets.take(3))
                RacketCard(
                  racket: r,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GearDetailScreen(racketId: r.id),
                      ),
                    );
                  },
                ),
            const SizedBox(height: 18),

            // Section: Cửa Hàng Gợi Ý Gần Bạn (Bán kính 2 km)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Flexible(
                        child: Text(
                          'Tiệm Đan Vợt Uy Tín Gần Bạn',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.primary.withOpacity(0.4),
                          ),
                        ),
                        child: const Text(
                          '≤ 2 km',
                          style: TextStyle(
                            color: AppTheme.primaryDark,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => onNavigateTab?.call(2), // Shop Map tab
                  child: const Text(
                    'Xem bản đồ ➔',
                    style: TextStyle(color: AppTheme.primaryDark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (shops.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Text(
                  'Chưa tìm thấy cửa hàng nào trong bán kính 2 km gần vị trí hiện tại.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              )
            else
              for (var s in shops)
                ShopCard(
                  shop: s,
                  onTap: () {
                    if (s.isVerifiedPartner) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ShopDetailScreen(shopId: s.id),
                        ),
                      );
                    } else {
                      _openShopGoogleMaps(context, s);
                    }
                  },
                  onChatTap: () {
                    if (!s.isVerifiedPartner) return;
                    final authProv = context.read<AuthProvider>();
                    if (authProv.isGuest) {
                      _openFeatureOrPromptLogin(
                        context,
                        screen: const SizedBox(),
                        featureName: 'Tin nhắn trao đổi với Shop',
                      );
                      return;
                    }
                    final chatProvider = context.read<ChatProvider>();
                    final thread = chatProvider.getOrCreateThreadForShop(
                      s.id,
                      s.name,
                      s.imageUrl,
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ChatConversationScreen(threadId: thread.id),
                      ),
                    );
                  },
                ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _openFeatureOrPromptLogin(
    BuildContext context, {
    required Widget screen,
    required String featureName,
  }) {
    final authProv = context.read<AuthProvider>();
    if (authProv.isGuest) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.lock_outline_rounded, color: AppTheme.accent),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Yêu Cầu Đăng Nhập',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Chức năng $featureName chỉ dành cho người dùng đã đăng nhập tài khoản. Vui lòng đăng nhập hoặc tạo tài khoản để sử dụng!',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Để sau', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginRegisterScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
              ),
              child: const Text('Đăng nhập ngay'),
            ),
          ],
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Widget _buildInjuryCard(BuildContext context) {
    final injuryProv = context.watch<InjuryProvider>();
    final activeInjury = injuryProv.activeInjury;

    if (activeInjury != null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: activeInjury.status.color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: activeInjury.status.color.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  activeInjury.bodyPart.icon,
                  color: activeInjury.status.color,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đang theo dõi: ${activeInjury.injuryNameVi}',
                    style: TextStyle(
                      color: activeInjury.status.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: activeInjury.status.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    activeInjury.status.label,
                    style: TextStyle(
                      color: activeInjury.status.color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Điểm đau: ${activeInjury.painScore}/10 • Vùng: ${activeInjury.bodyPart.shortLabel}. Nhấn để xem lộ trình phục hồi hoặc cập nhật trạng thái.',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    _openFeatureOrPromptLogin(
                      context,
                      screen: const InjuryHistoryScreen(),
                      featureName: 'Sổ tay chấn thương',
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: activeInjury.status.color,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  child: const Text('Xem Sổ Tay'),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () {
                    _openFeatureOrPromptLogin(
                      context,
                      screen: InjuryAssessmentScreen(
                        initialBodyPart: activeInjury.bodyPart,
                      ),
                      featureName: 'Bác sĩ thể thao & Tái khám chấn thương',
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: const BorderSide(color: AppTheme.border),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: const Text('Tái Khám'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Nếu chưa có chấn thương đang theo dõi, hiển thị card gợi ý
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryDark.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.healing_rounded,
              color: AppTheme.primaryDark,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bác Sĩ Thể Thao & Đau Mỏi 🩺',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Tự kiểm tra khớp cổ tay, khuỷu tay và tương quan lực căng vợt.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              _openFeatureOrPromptLogin(
                context,
                screen: const InjuryAssessmentScreen(),
                featureName: 'Bác sĩ thể thao & Chuẩn đoán chấn thương',
              );
            },
            child: const Text(
              'Khám ngay',
              style: TextStyle(
                color: AppTheme.primaryDark,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shortcutButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
