import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../models/shop_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shop_provider.dart';
import '../../providers/admin_provider.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_dashboard_screen.dart';
import '../shop_owner/shop_owner_dashboard_screen.dart';
import '../sport/sport_selection_screen.dart';

class LoginRegisterScreen extends StatefulWidget {
  const LoginRegisterScreen({super.key});

  @override
  State<LoginRegisterScreen> createState() => _LoginRegisterScreenState();
}

class _LoginRegisterScreenState extends State<LoginRegisterScreen> {
  bool _isLogin = true;
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _playStyleController = TextEditingController();

  // Thông tin đầy đủ của Shop khi Chủ Shop đăng ký tài khoản
  final _shopNameController = TextEditingController();
  final _shopAddressController = TextEditingController();
  final _shopDistrictController = TextEditingController();
  final _shopCityController = TextEditingController(text: 'TP. Hồ Chí Minh');
  final _shopMachineController = TextEditingController();
  final _shopCertController = TextEditingController();
  final _shopOpenHoursController = TextEditingController(text: '08:00 - 21:30');

  UserRole _selectedRole = UserRole.player;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _playStyleController.dispose();
    _shopNameController.dispose();
    _shopAddressController.dispose();
    _shopDistrictController.dispose();
    _shopCityController.dispose();
    _shopMachineController.dispose();
    _shopCertController.dispose();
    _shopOpenHoursController.dispose();
    super.dispose();
  }

  void _switchAuthMode(bool isLogin) {
    context.read<AuthProvider>().clearError();
    setState(() {
      _isLogin = isLogin;
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final shopProvider = context.read<ShopProvider>();
    final adminProvider = context.read<AdminProvider>();
    bool success = false;

    if (_isLogin) {
      success = await authProvider.login(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } else {
      success = await authProvider.register(
        fullName: _nameController.text,
        phone: _phoneController.text,
        email: _emailController.text,
        password: _passwordController.text,
        role: _selectedRole,
        playStyle: _selectedRole == UserRole.admin
            ? 'Quản trị viên hệ thống Gear Sports 🛡️'
            : _selectedRole == UserRole.player
                ? _playStyleController.text
                : 'Chủ cửa hàng ${_shopNameController.text.trim()}',
        shopName: _selectedRole == UserRole.stringer
            ? _shopNameController.text.trim()
            : null,
      );

      // Nếu đăng ký tài khoản Chủ Shop -> Tự động tạo hồ sơ Shop chờ Admin phê duyệt
      if (success && _selectedRole == UserRole.stringer) {
        final registeredUser = authProvider.currentUser;
        if (registeredUser != null) {
          final currentLoc = shopProvider.userLocation;
          final newShop = Shop(
            id: 'shop_${registeredUser.uid}',
            name: _shopNameController.text.trim(),
            address: _shopAddressController.text.trim(),
            district: _shopDistrictController.text.trim(),
            city: _shopCityController.text.trim(),
            latitude: currentLoc.latitude,
            longitude: currentLoc.longitude,
            rating: 5.0,
            reviewCount: 0,
            machineModel: _shopMachineController.text.trim(),
            stringerCert: _shopCertController.text.trim(),
            phone: _phoneController.text.trim(),
            openHours: _shopOpenHoursController.text.trim().isEmpty
                ? '08:00 - 21:30'
                : _shopOpenHoursController.text.trim(),
            imageUrl: '',
            ownerUid: registeredUser.uid,
            ownerName: registeredUser.fullName,
            ownerEmail: registeredUser.email,
            status: 'pending', // Chờ Admin phê duyệt
          );
          await shopProvider.upsertShop(newShop);
        }
      }
      await adminProvider.refreshAdminData();
    }

    if (!mounted) return;

    if (success) {
      final user = authProvider.currentUser;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isLogin
                ? 'Đăng nhập thành công! Chào mừng ${user?.fullName ?? ''}'
                : (user?.role == UserRole.stringer
                    ? 'Đăng ký thành công! Hồ sơ cửa hàng đã được gửi chờ Admin phê duyệt.'
                    : 'Đăng ký tài khoản thành công! Chào mừng ${user?.fullName ?? ''}'),
          ),
          backgroundColor: AppTheme.primaryDark,
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => user?.role == UserRole.admin
              ? const AdminDashboardScreen()
              : (user?.role == UserRole.stringer
                  ? const ShopOwnerDashboardScreen()
                  : const SportSelectionScreen()),
        ),
      );
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signInWithGoogle();
    if (!mounted) return;
    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SportSelectionScreen()),
      );
    }
  }

  Future<void> _handleGuestSignIn() async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.signInAsGuest();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SportSelectionScreen()),
    );
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(
      text: _emailController.text,
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Khôi phục mật khẩu',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nhập địa chỉ Email đã đăng ký để nhận đường dẫn đặt lại mật khẩu qua Firebase Authentication:',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email của bạn',
                prefixIcon: Icon(
                  Icons.email_outlined,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ],
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
              final email = resetEmailController.text.trim();
              final authProv = context.read<AuthProvider>();
              Navigator.pop(ctx);
              final ok = await authProv.resetPassword(email);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? 'Đã gửi yêu cầu đặt lại mật khẩu tới $email'
                        : (authProv.errorMessage ?? 'Không thể gửi yêu cầu.'),
                  ),
                  backgroundColor: ok ? AppTheme.primaryDark : AppTheme.danger,
                ),
              );
            },
            child: const Text('Gửi yêu cầu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Brand Logo & Name
                  Center(
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.sports_tennis_rounded,
                        size: 44,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'GEAR SPORTS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Trợ lý Số Hóa Vợt & Đặt Lịch Đan Cước Cầu Lông',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Firebase Status Badge
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.primary.withOpacity(0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            authProvider.isFirebaseAvailable
                                ? Icons.cloud_done_rounded
                                : Icons.storage_rounded,
                            size: 14,
                            color: AppTheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            authProvider.isFirebaseAvailable
                                ? 'Firebase Auth & Firestore Connected'
                                : 'Local Storage & Firebase Ready',
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Tab switch: Đăng nhập / Đăng ký
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _switchAuthMode(true),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _isLogin
                                    ? AppTheme.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Đăng Nhập',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _isLogin
                                      ? Colors.black
                                      : AppTheme.textSecondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => _switchAuthMode(false),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !_isLogin
                                    ? AppTheme.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Đăng Ký Mới',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: !_isLogin
                                      ? Colors.black
                                      : AppTheme.textSecondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Error Banner nếu có lỗi xác thực
                  if (authProvider.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.danger.withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppTheme.danger,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              authProvider.errorMessage!,
                              style: const TextStyle(
                                color: AppTheme.danger,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  if (!_isLogin) ...[
                    // Chọn Vai trò đăng ký (Người chơi / Chủ Shop)
                    const Text(
                      'Chọn loại tài khoản đăng ký:',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _RoleOptionCard(
                            icon: Icons.sports_tennis_rounded,
                            title: 'Người chơi',
                            subtitle: 'Quản lý Gara vợt',
                            isSelected: _selectedRole == UserRole.player,
                            onTap: () => setState(
                              () => _selectedRole = UserRole.player,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _RoleOptionCard(
                            icon: Icons.storefront_rounded,
                            title: 'Chủ Shop',
                            subtitle: 'Tiệm đan & Phụ kiện',
                            isSelected: _selectedRole == UserRole.stringer,
                            onTap: () => setState(
                              () => _selectedRole = UserRole.stringer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Tên người chơi / Chủ shop
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: _selectedRole == UserRole.stringer
                            ? 'Họ và tên Chủ Shop'
                            : 'Họ và tên người chơi',
                        prefixIcon: const Icon(
                          Icons.person_outline_rounded,
                          color: AppTheme.primary,
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Vui lòng nhập họ và tên'
                          : null,
                    ),
                    const SizedBox(height: 14),

                    // SĐT
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Số điện thoại liên hệ',
                        prefixIcon: Icon(
                          Icons.phone_outlined,
                          color: AppTheme.primary,
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Vui lòng nhập số điện thoại';
                        }
                        if (v.trim().length < 9) {
                          return 'Số điện thoại không hợp lệ';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Trường bổ sung theo Role
                    if (_selectedRole == UserRole.player) ...[
                      TextFormField(
                        controller: _playStyleController,
                        decoration: const InputDecoration(
                          labelText: 'Lối chơi sở trường (VD: Thiên công 4U)',
                          prefixIcon: Icon(
                            Icons.bolt_rounded,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ] else if (_selectedRole == UserRole.stringer) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppTheme.primary.withOpacity(0.45),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.storefront_rounded,
                                  color: AppTheme.primary,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Thông Tin Đăng Ký Cửa Hàng Cầu Lông (Chờ Admin Duyệt)',
                                    style: TextStyle(
                                      color: AppTheme.primary,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _shopNameController,
                              decoration: const InputDecoration(
                                labelText: 'Tên cửa hàng cầu lông *',
                                prefixIcon: Icon(
                                  Icons.store_mall_directory_outlined,
                                  color: AppTheme.primary,
                                ),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Vui lòng nhập tên cửa hàng'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _shopAddressController,
                              decoration: const InputDecoration(
                                labelText: 'Địa chỉ chi tiết (Số nhà, đường) *',
                                prefixIcon: Icon(
                                  Icons.place_outlined,
                                  color: AppTheme.primary,
                                ),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Vui lòng nhập địa chỉ cửa hàng'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _shopDistrictController,
                                    decoration: const InputDecoration(
                                      labelText: 'Quận / Huyện *',
                                    ),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? 'Nhập Quận/Huyện'
                                            : null,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: _shopCityController,
                                    decoration: const InputDecoration(
                                      labelText: 'Tỉnh / Thành phố *',
                                    ),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? 'Nhập Tỉnh/TP'
                                            : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _shopMachineController,
                              decoration: const InputDecoration(
                                labelText: 'Dòng máy đan cước sử dụng *',
                                hintText:
                                    'VD: Máy điện tử Yonex Precision 9.0',
                                prefixIcon: Icon(
                                  Icons.precision_manufacturing_rounded,
                                  color: AppTheme.primary,
                                ),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Vui lòng nhập dòng máy đan cước'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _shopCertController,
                              decoration: const InputDecoration(
                                labelText:
                                    'Chứng chỉ / Kinh nghiệm thợ đan *',
                                hintText:
                                    'VD: Thợ đan 4 nút chuẩn Yonex 5 năm KN',
                                prefixIcon: Icon(
                                  Icons.verified_outlined,
                                  color: AppTheme.primary,
                                ),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Vui lòng nhập chứng chỉ/kinh nghiệm'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _shopOpenHoursController,
                              decoration: const InputDecoration(
                                labelText: 'Giờ mở cửa hoạt động *',
                                hintText: 'VD: 08:00 - 21:30',
                                prefixIcon: Icon(
                                  Icons.access_time_rounded,
                                  color: AppTheme.primary,
                                ),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Vui lòng nhập giờ mở cửa'
                                  : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ],

                  // Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        color: AppTheme.primary,
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Vui lòng nhập Email';
                      }
                      if (!v.contains('@') || !v.contains('.')) {
                        return 'Email không hợp lệ';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Mật khẩu
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu',
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        color: AppTheme.primary,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: AppTheme.textMuted,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Vui lòng nhập mật khẩu';
                      }
                      if (v.length < 6) {
                        return 'Mật khẩu tối thiểu 6 ký tự';
                      }
                      return null;
                    },
                  ),

                  // Xác nhận mật khẩu khi Đăng ký
                  if (!_isLogin) ...[
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Xác nhận mật khẩu',
                        prefixIcon: const Icon(
                          Icons.verified_user_outlined,
                          color: AppTheme.primary,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppTheme.textMuted,
                          ),
                          onPressed: () => setState(
                            () => _obscureConfirmPassword =
                                !_obscureConfirmPassword,
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Vui lòng xác nhận mật khẩu';
                        }
                        if (v != _passwordController.text) {
                          return 'Mật khẩu xác nhận không khớp';
                        }
                        return null;
                      },
                    ),
                  ],

                  if (_isLogin) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _showForgotPasswordDialog,
                        child: const Text(
                          'Quên mật khẩu?',
                          style: TextStyle(
                            color: AppTheme.primaryDark,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 20),
                  ],

                  // Nút Submit chính
                  ElevatedButton(
                    onPressed: authProvider.isLoading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: authProvider.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.black,
                            ),
                          )
                        : Text(
                            _isLogin ? 'Đăng Nhập Ngay' : 'Tạo Tài Khoản Mới',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),

                  const SizedBox(height: 16),

                  // Hoặc đăng nhập bằng
                  const Row(
                    children: [
                      Expanded(child: Divider(color: AppTheme.border)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'Hoặc tiếp tục với',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: AppTheme.border)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Nút Google & Khách
                  OutlinedButton.icon(
                    onPressed:
                        authProvider.isLoading ? null : _handleGoogleSignIn,
                    icon: const Icon(
                      Icons.g_mobiledata_rounded,
                      size: 28,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Đăng nhập với Google',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: AppTheme.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  TextButton(
                    onPressed:
                        authProvider.isLoading ? null : _handleGuestSignIn,
                    child: const Text(
                      'Vào xem thử với tư cách Khách ➔',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withOpacity(0.14)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary
                    : AppTheme.border.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.black : AppTheme.textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected
                          ? AppTheme.primary
                          : AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
