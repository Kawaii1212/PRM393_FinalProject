import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../main_navigation_screen.dart';
import '../profile/profile_screen.dart';

class SportCategoryItem {
  final String id;
  final String name;
  final String englishName;
  final String description;
  final String phaseBadge;
  final IconData icon;
  final Color accentColor;
  final bool isAvailable;
  final List<String> features;

  const SportCategoryItem({
    required this.id,
    required this.name,
    required this.englishName,
    required this.description,
    required this.phaseBadge,
    required this.icon,
    required this.accentColor,
    required this.isAvailable,
    required this.features,
  });
}

class SportSelectionScreen extends StatelessWidget {
  const SportSelectionScreen({super.key});

  static const List<SportCategoryItem> _sports = [
    SportCategoryItem(
      id: 'badminton',
      name: 'Cầu Lông',
      englishName: 'Badminton',
      description:
          'Số hóa Gara vợt, cảnh báo độ chùng cước, nhật ký đan vợt & đặt lịch tiệm đan gần nhất.',
      phaseBadge: 'Sẵn sàng • Phase 1',
      icon: Icons.sports_tennis_rounded,
      accentColor: AppTheme.primary,
      isAvailable: true,
      features: [
        'Gara Vợt & Thông số vật lý',
        'Dự báo hao mòn cước',
        'Đặt lịch đan vợt & Bản đồ Shop',
      ],
    ),
    SportCategoryItem(
      id: 'pickleball',
      name: 'Pickleball',
      englishName: 'Pickleball',
      description:
          'Theo dõi độ nhám mặt vợt Carbon/Fiberglass, tình trạng lõi tổ ong & phụ kiện viền vợt.',
      phaseBadge: 'Đang phát triển',
      icon: Icons.sports_cricket_rounded,
      accentColor: Color(0xFF00E5FF),
      isAvailable: false,
      features: [
        'Đo độ mòn mặt nhám Spin',
        'Quản lý Paddle & Bóng thi đấu',
      ],
    ),
    SportCategoryItem(
      id: 'basketball',
      name: 'Bóng Rổ',
      englishName: 'Basketball',
      description:
          'Quản lý độ mòn đế giày (Indoor/Outdoor), độ bám sân (Traction) & áp suất bóng tiêu chuẩn.',
      phaseBadge: 'Đang phát triển',
      icon: Icons.sports_basketball_rounded,
      accentColor: Color(0xFFFF9100),
      isAvailable: false,
      features: [
        'Theo dõi khấu hao đế giày',
        'Bảo dưỡng bóng & Phụ kiện bảo hộ',
      ],
    ),
    SportCategoryItem(
      id: 'football',
      name: 'Bóng Đá',
      englishName: 'Football / Soccer',
      description:
          'Quản lý vòng đời giày đinh (TF/FG/AG), độ mòn đinh đế, găng tay thủ môn & phụ kiện sân cỏ.',
      phaseBadge: 'Đang phát triển',
      icon: Icons.sports_soccer_rounded,
      accentColor: Color(0xFFAA00FF),
      isAvailable: false,
      features: [
        'Theo dõi giày đinh cỏ nhân tạo/tự nhiên',
        'Kết nối dịch vụ khâu đế & dán keo',
      ],
    ),
  ];

  void _handleSportTap(BuildContext context, SportCategoryItem sport) {
    if (sport.isAvailable) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      );
      return;
    }

    // Hiển thị thông báo tính năng đang phát triển cho các bộ môn khác
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.border),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: sport.accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(sport.icon, color: sport.accentColor, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bộ môn ${sport.name}',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tính năng đang phát triển',
                    style: TextStyle(
                      color: sport.accentColor,
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
            Text(
              'Phân hệ trợ lý trang thiết bị cho bộ môn ${sport.name} (${sport.englishName}) hiện đang trong quá trình phát triển và sẽ sớm ra mắt ở phiên bản tiếp theo.',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppTheme.primary,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Hiện tại Gear Sports (Phase 1) đang tập trung hỗ trợ đầy đủ nhất cho bộ môn Cầu Lông 🏸.',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Đóng',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const MainNavigationScreen(),
                ),
              );
            },
            icon: const Icon(Icons.sports_tennis_rounded, size: 18),
            label: const Text('Vào Cầu Lông Ngay'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.sports_tennis_rounded,
                color: Colors.black,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'GEAR SPORTS',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Hồ sơ tài khoản',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
            icon: const Icon(
              Icons.account_circle_outlined,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppTheme.cardGradient,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppTheme.surfaceLight,
                      child: Text(
                        (user?.fullName.isNotEmpty == true)
                            ? user!.fullName.trim()[0].toUpperCase()
                            : 'G',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Xin chào, ${user?.fullName ?? 'Người chơi'}! 👋',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Hãy chọn bộ môn thể thao bạn muốn quản lý thiết bị hôm nay',
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
              const SizedBox(height: 22),

              const Text(
                'Chọn Bộ Môn Thể Thao',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Hệ sinh thái số hóa trang bị thể thao chuyên sâu của Gear Sports',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 16),

              // Danh sách các bộ môn
              for (final sport in _sports) ...[
                _SportSelectionCard(
                  sport: sport,
                  onTap: () => _handleSportTap(context, sport),
                ),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SportSelectionCard extends StatelessWidget {
  final SportCategoryItem sport;
  final VoidCallback onTap;

  const _SportSelectionCard({
    required this.sport,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isReady = sport.isAvailable;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isReady
              ? AppTheme.surface
              : AppTheme.surface.withOpacity(0.75),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isReady ? AppTheme.primary : AppTheme.border,
            width: isReady ? 1.8 : 1.0,
          ),
          boxShadow: isReady
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: sport.accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: sport.accentColor.withOpacity(0.4),
                    ),
                  ),
                  child: Icon(
                    sport.icon,
                    color: sport.accentColor,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            sport.name,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '(${sport.englishName})',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isReady
                              ? AppTheme.primary.withOpacity(0.18)
                              : AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isReady
                                ? AppTheme.primary
                                : AppTheme.border,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isReady
                                  ? Icons.check_circle_rounded
                                  : Icons.construction_rounded,
                              size: 12,
                              color: isReady
                                  ? AppTheme.primary
                                  : AppTheme.accent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              sport.phaseBadge,
                              style: TextStyle(
                                color: isReady
                                    ? AppTheme.primary
                                    : AppTheme.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isReady
                      ? Icons.arrow_forward_ios_rounded
                      : Icons.lock_clock_outlined,
                  color: isReady ? AppTheme.primary : AppTheme.textMuted,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              sport.description,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: sport.features
                  .map(
                    (f) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '• $f',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
