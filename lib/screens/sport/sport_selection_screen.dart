import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../main_navigation_screen.dart';
import '../profile/profile_screen.dart';

class SportCategoryItem {
  final String id;
  final String name;
  final String imageUrl;
  final IconData icon;
  final Color accentColor;
  final bool isAvailable;

  const SportCategoryItem({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.icon,
    required this.accentColor,
    required this.isAvailable,
  });
}

class SportSelectionScreen extends StatelessWidget {
  const SportSelectionScreen({super.key});

  static const List<SportCategoryItem> _sports = [
    SportCategoryItem(
      id: 'badminton',
      name: 'Cầu Lông',
      imageUrl:
          'https://images.unsplash.com/photo-1626224583764-f87db24ac4ea?auto=format&fit=crop&w=800&q=80',
      icon: Icons.sports_tennis_rounded,
      accentColor: AppTheme.primary,
      isAvailable: true,
    ),
    SportCategoryItem(
      id: 'pickleball',
      name: 'Pickleball',
      imageUrl:
          'https://images.unsplash.com/photo-1554068865-24cecd4e34b8?auto=format&fit=crop&w=800&q=80',
      icon: Icons.sports_cricket_rounded,
      accentColor: Color(0xFF00E5FF),
      isAvailable: false,
    ),
    SportCategoryItem(
      id: 'basketball',
      name: 'Bóng Rổ',
      imageUrl:
          'https://images.unsplash.com/photo-1546519638-68e109498ffc?auto=format&fit=crop&w=800&q=80',
      icon: Icons.sports_basketball_rounded,
      accentColor: Color(0xFFFF9100),
      isAvailable: false,
    ),
    SportCategoryItem(
      id: 'football',
      name: 'Bóng Đá',
      imageUrl:
          'https://images.unsplash.com/photo-1579952363873-27f3bade9f55?auto=format&fit=crop&w=800&q=80',
      icon: Icons.sports_soccer_rounded,
      accentColor: Color(0xFFAA00FF),
      isAvailable: false,
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
              child: Icon(sport.icon, color: sport.accentColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                sport.name,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Bộ môn ${sport.name} đang được phát triển và sẽ sớm ra mắt.',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
            ),
            child: const Text('Đóng'),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Xin chào, ${user?.fullName ?? 'Người chơi'}! 👋',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Chọn Bộ Môn Thể Thao',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: GridView.builder(
                  itemCount: _sports.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.85,
                  ),
                  itemBuilder: (context, index) {
                    final sport = _sports[index];
                    return _SportSelectionCard(
                      sport: sport,
                      onTap: () => _handleSportTap(context, sport),
                    );
                  },
                ),
              ),
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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isReady ? AppTheme.primary : AppTheme.border,
            width: isReady ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isReady
                  ? AppTheme.primary.withOpacity(0.18)
                  : Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Ảnh đại diện bộ môn
              Image.network(
                sport.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.surfaceLight,
                        sport.accentColor.withOpacity(0.3),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      sport.icon,
                      size: 56,
                      color: sport.accentColor,
                    ),
                  ),
                ),
              ),

              // Lớp phủ tối dần để nổi bật tên bộ môn
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(isReady ? 0.1 : 0.45),
                      Colors.black.withOpacity(0.85),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),

              // Biểu tượng nhỏ góc trên
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: sport.accentColor.withOpacity(0.6),
                    ),
                  ),
                  child: Icon(
                    sport.icon,
                    color: sport.accentColor,
                    size: 18,
                  ),
                ),
              ),

              // Tên bộ môn
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Text(
                  sport.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
