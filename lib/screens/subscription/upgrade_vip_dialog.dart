import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/subscription_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../services/vietqr_service.dart';
import '../../services/sepay_service.dart';
import '../../theme/app_theme.dart';

class UpgradeVipDialog extends StatefulWidget {
  final String? featurePrompt;

  const UpgradeVipDialog({super.key, this.featurePrompt});

  static Future<void> show(BuildContext context, {String? featurePrompt}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UpgradeVipDialog(featurePrompt: featurePrompt),
    );
  }

  @override
  State<UpgradeVipDialog> createState() => _UpgradeVipDialogState();
}

class _UpgradeVipDialogState extends State<UpgradeVipDialog> {
  int _currentStep = 0; // 0: Chọn gói, 1: Quét mã VietQR, 2: Thành công
  SubscriptionPlan _selectedPlan = SubscriptionPlan.playerPlans[1]; // Mặc định gói 3 tháng
  bool _isProcessing = false;
  bool _isChecking = false;
  String _transferContent = '';
  String _qrImageUrl = '';
  DateTime? _sessionStartTime;
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  // Đếm ngược phiên thanh toán (15 phút)
  Timer? _countdownTimer;
  int _countdownSeconds = 15 * 60;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _initPaymentDetails(String userId) {
    _sessionStartTime = DateTime.now();
    _transferContent = VietQrConfig.generateTransferContent(
      prefix: 'GS VIP',
      userId: userId,
    );
    _qrImageUrl = VietQrConfig.generateQrImageUrl(
      amount: _selectedPlan.priceVnd,
      transferContent: _transferContent,
    );
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownSeconds = 15 * 60;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_countdownSeconds > 0) {
          _countdownSeconds--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  /// Người dùng chủ động bấm xác nhận đã chuyển khoản
  Future<void> _handleUserConfirmPayment(dynamic user) async {
    if (_isChecking || _isProcessing || _currentStep != 1) return;
    setState(() => _isChecking = true);

    try {
      final subProv = context.read<SubscriptionProvider>();
      final result = await SepayService.checkPayment(
        transferCode: _transferContent,
        expectedAmount: _selectedPlan.priceVnd,
        usedTransactionIds: subProv.usedTransactionIds,
        usedTransferCodes: subProv.usedTransferCodes,
        sessionStartTime: _sessionStartTime,
      );

      if (!mounted) return;

      if (result.isSuccess) {
        setState(() {
          _isChecking = false;
          _isProcessing = true;
        });

        final subProv = context.read<SubscriptionProvider>();
        final success = await subProv.upgradePlayerSubscription(
          context: context,
          user: user,
          plan: _selectedPlan,
          customTxId: result.transactionId,
          customTransferCode: _transferContent,
          paymentMethod: 'VietQR Napas 24/7 (MBBank 0949614588)',
        );

        if (!mounted) return;
        setState(() {
          _isProcessing = false;
          if (success) {
            _countdownTimer?.cancel();
            _currentStep = 2; // Chuyển sang màn hình kích hoạt thành công
          }
        });
      } else {
        // Chưa có tiền vào hoặc người dùng bấm khi chưa chuyển khoản
        setState(() => _isChecking = false);
        _showNotReceivedAlert();
      }
    } catch (e) {
      debugPrint('Check payment error: $e');
      if (mounted) {
        setState(() => _isChecking = false);
        _showNotReceivedAlert();
      }
    }
  }

  /// Thông báo rõ ràng cho người dùng khi chưa có giao dịch
  void _showNotReceivedAlert() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: AppTheme.warning, size: 22),
            SizedBox(width: 8),
            Text(
              'Chưa ghi nhận thanh toán',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hệ thống chưa tìm thấy giao dịch chuyển khoản cho nội dung: "$_transferContent" với số tiền ${currencyFormat.format(_selectedPlan.priceVnd)} vào STK 0949614588.',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded, color: AppTheme.primary, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nếu bạn vừa chuyển khoản, vui lòng đợi vài giây để ngân hàng xử lý rồi bấm kiểm tra lại!',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
            ),
            child: const Text('Đã Hiểu', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã sao chép $label: $text'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isVipActive = user?.isVipActive == true;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
            child: Row(
              children: [
                if (_currentStep == 1)
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.primary),
                    onPressed: () {
                      _countdownTimer?.cancel();
                      setState(() => _currentStep = 0);
                    },
                  ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _currentStep == 2
                        ? Icons.check_circle_rounded
                        : (_currentStep == 1 ? Icons.qr_code_scanner_rounded : Icons.workspace_premium_rounded),
                    color: Colors.black,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentStep == 2
                            ? 'Kích Hoạt Thành Công'
                            : (_currentStep == 1 ? 'Thanh Toán VietQR Napas 24/7' : 'Nâng Cấp GearSports VIP'),
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _currentStep == 2
                            ? 'Đặc quyền VIP đã sẵn sàng'
                            : (_currentStep == 1
                                ? _selectedPlan.title
                                : (widget.featurePrompt ?? 'Mở khóa toàn bộ đặc quyền hội viên VIP')),
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
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),

          // Body Content theo từng bước
          Expanded(
            child: _currentStep == 0
                ? _buildStep0SelectPlan(context, user, isVipActive)
                : (_currentStep == 1 ? _buildStep1VietQr(context, user) : _buildStep2Success(context)),
          ),
        ],
      ),
    );
  }

  // BƯỚC 0: CHỌN GÓI DỊCH VỤ (Không bị tràn viền khi chọn gói 3 tháng)
  Widget _buildStep0SelectPlan(BuildContext context, dynamic user, bool isVipActive) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isVipActive && user?.vipExpiresAt != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.stars_rounded, color: Color(0xFFFFD700), size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Bạn đang là Hội Viên VIP Hoàng Kim',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                'Hạn sử dụng còn: ${user.vipDaysRemaining} ngày (Đến ${DateFormat('dd/MM/yyyy').format(user.vipExpiresAt!)})\nĐăng ký tiếp để cộng dồn thêm thời hạn!',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const Text(
                  'CHỌN GÓI HỘI VIÊN VIP:',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),

                // Danh sách gói dịch vụ
                ...SubscriptionPlan.playerPlans.map((plan) {
                  final isSelected = _selectedPlan.id == plan.id;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primary.withOpacity(0.08) : AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppTheme.primary : AppTheme.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => setState(() => _selectedPlan = plan),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Radio<String>(
                              value: plan.id,
                              groupValue: _selectedPlan.id,
                              activeColor: AppTheme.primary,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              onChanged: (_) => setState(() => _selectedPlan = plan),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        plan.title,
                                        style: const TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (plan.discountBadge != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade700,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            plan.discountBadge!,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    plan.description,
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 11,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  currencyFormat.format(plan.priceVnd),
                                  style: const TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '/${plan.shortTitle}',
                                  style: const TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 10),
                const Text(
                  'ĐẶC QUYỀN KHI TRỞ THÀNH VIP:',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),

                _benefitItem(
                  icon: Icons.sports_tennis_rounded,
                  title: 'Gara Vợt Không Giới Hạn',
                  description: 'Thoải mái thêm hơn 5 cây vợt và quản lý chi tiết thông số căng cước trọn đời.',
                ),
                const SizedBox(height: 8),
                _benefitItem(
                  icon: Icons.health_and_safety_rounded,
                  title: 'Bác Sĩ Thể Thao (AI Health)',
                  description: 'Chẩn đoán cảm giác tay, cảnh báo quá tải lực căng và gợi ý mức căng tối ưu.',
                ),
                const SizedBox(height: 8),
                _benefitItem(
                  icon: Icons.medical_services_rounded,
                  title: 'Sổ Tay Chấn Thương & Phục Hồi',
                  description: 'Hướng dẫn chuẩn y khoa phòng tránh viêm gân cổ tay, đau khuỷu tay tennis elbow.',
                ),
                const SizedBox(height: 8),
                _benefitItem(
                  icon: Icons.verified_rounded,
                  title: 'Huy Hiệu VIP Hoàng Kim',
                  description: 'Khẳng định đẳng cấp trên toàn hệ thống giải đấu và cộng đồng GearSports.',
                ),
              ],
            ),
          ),
        ),

        // Action Button chuyển sang bước quét mã
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceLight,
            border: Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                if (user == null) return;
                _initPaymentDetails(user.uid);
                setState(() => _currentStep = 1);
                _startCountdown();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              icon: const Icon(Icons.qr_code_rounded, size: 20),
              label: Text(
                'Tiếp Tục Thanh Toán • ${currencyFormat.format(_selectedPlan.priceVnd)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // BƯỚC 1: QUÉT MÃ VIETQR & BẤM XÁC NHẬN CHUYỂN KHOẢN
  Widget _buildStep1VietQr(BuildContext context, dynamic user) {
    final minutes = _countdownSeconds ~/ 60;
    final seconds = (_countdownSeconds % 60).toString().padLeft(2, '0');

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Clean user-friendly guidance banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.primary.withOpacity(0.35)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.touch_app_rounded,
                        color: AppTheme.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quét mã và chuyển khoản đúng số tiền',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Sau khi chuyển xong, hãy nhấn nút xác nhận bên dưới để kích hoạt VIP',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$minutes:$seconds',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // QR Container
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          _qrImageUrl,
                          width: 200,
                          height: 200,
                          fit: BoxFit.contain,
                          loadingBuilder: (ctx, child, progress) {
                            if (progress == null) return child;
                            return const SizedBox(
                              width: 200,
                              height: 200,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.primary,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (ctx, err, stack) {
                            return Container(
                              width: 200,
                              height: 200,
                              color: Colors.grey.shade100,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.qr_code_2_rounded, size: 70, color: Colors.black54),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Mã CK: $_transferContent',
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_outlined, size: 14, color: Colors.black54),
                          SizedBox(width: 6),
                          Text(
                            'Quét mã bằng App Ngân Hàng để chuyển tiền',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Bank Info Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    children: [
                      _infoRow(
                        label: 'Ngân hàng thụ hưởng:',
                        value: 'MBBank - NH TMCP Quân Đội',
                        icon: Icons.account_balance_rounded,
                      ),
                      const Divider(height: 16, color: AppTheme.border),
                      _infoRow(
                        label: 'Số tài khoản (STK):',
                        value: VietQrConfig.defaultAccountNumber,
                        icon: Icons.credit_card_rounded,
                        valueColor: AppTheme.primary,
                        onCopy: () => _copyToClipboard(
                          VietQrConfig.defaultAccountNumber,
                          'Số tài khoản MBBank',
                        ),
                      ),
                      const Divider(height: 16, color: AppTheme.border),
                      _infoRow(
                        label: 'Chủ tài khoản:',
                        value: VietQrConfig.defaultAccountName,
                        icon: Icons.person_rounded,
                      ),
                      const Divider(height: 16, color: AppTheme.border),
                      _infoRow(
                        label: 'Số tiền:',
                        value: currencyFormat.format(_selectedPlan.priceVnd),
                        icon: Icons.payments_rounded,
                        valueColor: AppTheme.accent,
                        onCopy: () => _copyToClipboard(
                          _selectedPlan.priceVnd.toString(),
                          'Số tiền',
                        ),
                      ),
                      const Divider(height: 16, color: AppTheme.border),
                      _infoRow(
                        label: 'Nội dung chuyển khoản:',
                        value: _transferContent,
                        icon: Icons.comment_bank_rounded,
                        valueColor: const Color(0xFFFFD700),
                        onCopy: () => _copyToClipboard(
                          _transferContent,
                          'Nội dung chuyển khoản',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Action Button: Chỉ kích hoạt khi người dùng chủ động bấm
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceLight,
            border: Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: (_isChecking || _isProcessing)
                  ? null
                  : () => _handleUserConfirmPayment(user),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              icon: _isChecking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.check_circle_rounded, size: 20),
              label: Text(
                _isChecking ? 'Đang kiểm tra giao dịch...' : 'Tôi Đã Chuyển Khoản',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // BƯỚC 2: KÍCH HOẠT THÀNH CÔNG
  Widget _buildStep2Success(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 64),
          ),
          const SizedBox(height: 20),
          const Text(
            'Kích Hoạt VIP Thành Công! 👑',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Tài khoản của bạn đã được nâng cấp lên ${_selectedPlan.title}.\nGiờ đây bạn có thể quản lý không giới hạn số lượng vợt trong Gara và sử dụng trọn vẹn Bác Sĩ Thể Thao!',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
              ),
              child: const Text(
                'Bắt Đầu Sử Dụng Ngay',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required String label,
    required String value,
    required IconData icon,
    Color? valueColor,
    VoidCallback? onCopy,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.textMuted),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: valueColor ?? AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (onCopy != null) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: onCopy,
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(2.0),
                    child: Icon(Icons.copy_rounded, size: 16, color: AppTheme.primary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _benefitItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.primary, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
