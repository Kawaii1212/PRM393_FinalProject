import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/racket_provider.dart';
import '../../theme/app_theme.dart';
import '../auth/login_register_screen.dart';
import '../shop_owner/shop_owner_dashboard_screen.dart';
import '../injury/injury_history_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _playStyleController;
  late TextEditingController _shopNameController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    _nameController = TextEditingController(text: user?.fullName ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _playStyleController = TextEditingController(text: user?.playStyle ?? '');
    _shopNameController = TextEditingController(text: user?.shopName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _playStyleController.dispose();
    _shopNameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    final ok = await authProvider.updateProfile(
      fullName: _nameController.text,
      phone: _phoneController.text,
      playStyle: _playStyleController.text,
      shopName: user?.role == UserRole.stringer
          ? _shopNameController.text
          : null,
    );

    if (!mounted) return;
    if (ok) {
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã lưu thông tin hồ sơ lên Cloud Firestore!'),
          backgroundColor: AppTheme.primaryDark,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            authProvider.errorMessage ?? 'Không thể cập nhật hồ sơ',
          ),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Đăng xuất tài khoản?',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi phiên làm việc hiện tại không?',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Hủy',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginRegisterScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final racketProvider = context.watch<RacketProvider>();
    final user = authProvider.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ Sơ Tài Khoản'),
        actions: [
          if (!_isEditing)
            TextButton.icon(
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(
                Icons.edit_outlined,
                size: 18,
                color: AppTheme.primary,
              ),
              label: const Text(
                'Chỉnh sửa',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            TextButton(
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _nameController.text = user.fullName;
                  _phoneController.text = user.phone;
                  _playStyleController.text = user.playStyle;
                  _shopNameController.text = user.shopName ?? '';
                });
              },
              child: const Text(
                'Hủy',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Profile Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppTheme.cardGradient,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withOpacity(0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          user.fullName.isNotEmpty
                              ? user.fullName.trim()[0].toUpperCase()
                              : 'G',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user.fullName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.primary),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.lock_outline_rounded,
                                size: 12,
                                color: AppTheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                user.role.displayName,
                                style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppTheme.accent.withOpacity(0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.cloud_done_rounded,
                                size: 13,
                                color: AppTheme.accent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                authProvider.isFirebaseAvailable
                                    ? 'Firestore Synced'
                                    : 'Local Session',
                                style: const TextStyle(
                                  color: AppTheme.accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (user.role == UserRole.stringer) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ShopOwnerDashboardScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.storefront_rounded),
                  label: const Text('Kênh Quản Trị Cửa Hàng (Chủ Shop)'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Quick Stats Row (Chỉ hiển thị cho Người chơi & Chủ Shop)
              if (user.role != UserRole.admin) ...[
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        label: 'Vợt sở hữu',
                        value: '${racketProvider.allRackets.length} cây',
                        icon: Icons.sports_tennis_rounded,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatTile(
                        label: 'Cần đan lại',
                        value:
                            '${racketProvider.racketsNeedingRestring.length} cây',
                        icon: Icons.warning_amber_rounded,
                        color: racketProvider.racketsNeedingRestring.isNotEmpty
                            ? AppTheme.danger
                            : AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // Form Thông tin cá nhân
              const Text(
                'Thông tin chi tiết (Cloud Firestore: users)',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 12),

              // Vai trò hệ thống (KHÓA CỨNG - KHÔNG CHO PHÉP CHỈNH SỬA)
              TextFormField(
                initialValue: user.role.displayName,
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Vai trò tài khoản (Cố định)',
                  helperText: 'Vai trò gắn liền với giao diện hệ thống và không thể thay đổi',
                  helperStyle: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  prefixIcon: Icon(
                    Icons.badge_outlined,
                    color: AppTheme.textMuted,
                  ),
                  suffixIcon: Icon(
                    Icons.lock_outline_rounded,
                    color: AppTheme.textMuted,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Email (KHÓA CỨNG)
              TextFormField(
                initialValue: user.email,
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Email đăng nhập (Cố định)',
                  prefixIcon: Icon(
                    Icons.email_outlined,
                    color: AppTheme.textMuted,
                  ),
                  suffixIcon: Icon(
                    Icons.lock_outline_rounded,
                    color: AppTheme.textMuted,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _nameController,
                enabled: _isEditing,
                decoration: const InputDecoration(
                  labelText: 'Họ và tên',
                  prefixIcon: Icon(
                    Icons.person_outline_rounded,
                    color: AppTheme.primary,
                  ),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Không được để trống họ tên'
                    : null,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _phoneController,
                enabled: _isEditing,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Số điện thoại',
                  prefixIcon: Icon(
                    Icons.phone_outlined,
                    color: AppTheme.primary,
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Không được để trống số điện thoại';
                  }
                  final clean = v.trim();
                  if (!RegExp(r'^0\d{9}$').hasMatch(clean)) {
                    return 'Số điện thoại phải bắt đầu bằng số 0 và có đủ 10 chữ số';
                  }
                  return null;
                },
              ),
              if (user.role == UserRole.player) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _playStyleController,
                  enabled: _isEditing,
                  decoration: const InputDecoration(
                    labelText: 'Lối chơi sở trường',
                    prefixIcon: Icon(
                      Icons.bolt_rounded,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],

              if (user.role == UserRole.stringer) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _shopNameController,
                  enabled: _isEditing,
                  decoration: const InputDecoration(
                    labelText: 'Tên cửa hàng cầu lông quản lý',
                    prefixIcon: Icon(
                      Icons.storefront_rounded,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 22),

              if (_isEditing) ...[
                ElevatedButton.icon(
                  onPressed: authProvider.isLoading ? null : _saveProfile,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                    authProvider.isLoading
                        ? 'Đang lưu...'
                        : 'Lưu Thay Đổi Hồ Sơ',
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Sổ tay chấn thương & Phục hồi chức năng (Dành cho Player đã đăng nhập)
              if (user.role == UserRole.player) ...[
                OutlinedButton.icon(
                  onPressed: () {
                    final isGuest = context.read<AuthProvider>().isGuest;
                    if (isGuest) {
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
                          content: const Text(
                            'Chức năng Sổ tay chấn thương & Phục hồi chỉ dành cho người dùng đã đăng nhập tài khoản. Vui lòng đăng nhập hoặc tạo tài khoản để sử dụng!',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
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
                      MaterialPageRoute(
                        builder: (_) => const InjuryHistoryScreen(),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.healing_rounded,
                    color: AppTheme.primary,
                  ),
                  label: const Text(
                    'Sổ Tay Chấn Thương & Phục Hồi',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppTheme.primary, width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Nút Đăng xuất (FR-01: Logout)
              OutlinedButton.icon(
                onPressed: _confirmLogout,
                icon: const Icon(
                  Icons.logout_rounded,
                  color: AppTheme.danger,
                ),
                label: const Text(
                  'Đăng Xuất Tài Khoản (Logout)',
                  style: TextStyle(
                    color: AppTheme.danger,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  side: const BorderSide(color: AppTheme.danger, width: 1.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
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

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
