import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/subscription_model.dart';
import '../../services/vietqr_service.dart';
import '../../theme/app_theme.dart';

class VietQrPaymentDialog extends StatefulWidget {
  final SubscriptionPlan plan;
  final String userId;
  final String? shopId;
  final Future<bool> Function() onConfirmPayment;

  const VietQrPaymentDialog({
    super.key,
    required this.plan,
    required this.userId,
    this.shopId,
    required this.onConfirmPayment,
  });

  static Future<bool?> show(
    BuildContext context, {
    required SubscriptionPlan plan,
    required String userId,
    String? shopId,
    required Future<bool> Function() onConfirmPayment,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VietQrPaymentDialog(
        plan: plan,
        userId: userId,
        shopId: shopId,
        onConfirmPayment: onConfirmPayment,
      ),
    );
  }

  @override
  State<VietQrPaymentDialog> createState() => _VietQrPaymentDialogState();
}

class _VietQrPaymentDialogState extends State<VietQrPaymentDialog> {
  late final String _transferContent;
  late final String _qrImageUrl;
  bool _isProcessing = false;
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  @override
  void initState() {
    super.initState();
    final prefix = widget.plan.target == SubscriptionTarget.player ? 'GS VIP' : 'GS SHOP';
    _transferContent = VietQrConfig.generateTransferContent(
      prefix: prefix,
      userId: widget.shopId ?? widget.userId,
    );
    _qrImageUrl = VietQrConfig.generateQrImageUrl(
      amount: widget.plan.priceVnd,
      transferContent: _transferContent,
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

  Future<void> _handleConfirm() async {
    setState(() => _isProcessing = true);
    // Giả lập xác thực giao dịch chuyển khoản VietQR trong 1 giây
    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;
    final success = await widget.onConfirmPayment();
    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (success) {
      Navigator.pop(context, true);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 28),
              SizedBox(width: 10),
              Text(
                'Thanh Toán Thành Công!',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            'Hệ thống đã xác nhận thanh toán cho gói ${widget.plan.title}.\nTài khoản của bạn đã được kích hoạt thành công!',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
              ),
              child: const Text('Bắt đầu sử dụng'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Xử lý thanh toán thất bại, vui lòng thử lại!'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Thanh Toán VietQR Napas 24/7',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${widget.plan.title} • ${currencyFormat.format(widget.plan.priceVnd)}',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const Divider(color: AppTheme.border, height: 1),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
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
                            width: 220,
                            height: 220,
                            fit: BoxFit.contain,
                            loadingBuilder: (ctx, child, progress) {
                              if (progress == null) return child;
                              return const SizedBox(
                                width: 220,
                                height: 220,
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
                                width: 220,
                                height: 220,
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
                            Icon(Icons.shield_outlined, size: 14, color: Colors.black54),
                            SizedBox(width: 4),
                            Text(
                              'Quét qua bất kỳ app Ngân hàng / MoMo / ZaloPay',
                              style: TextStyle(color: Colors.black54, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Bank details info card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      children: [
                        _infoRow(
                          label: 'Ngân hàng thụ hưởng',
                          value: VietQrConfig.defaultBankName,
                          icon: Icons.account_balance_rounded,
                        ),
                        const Divider(color: AppTheme.border, height: 16),
                        _infoRow(
                          label: 'Số tài khoản',
                          value: VietQrConfig.defaultAccountNumber,
                          icon: Icons.credit_card_rounded,
                          onCopy: () => _copyToClipboard(VietQrConfig.defaultAccountNumber, 'Số tài khoản'),
                        ),
                        const Divider(color: AppTheme.border, height: 16),
                        _infoRow(
                          label: 'Chủ tài khoản',
                          value: VietQrConfig.defaultAccountName,
                          icon: Icons.person_rounded,
                        ),
                        const Divider(color: AppTheme.border, height: 16),
                        _infoRow(
                          label: 'Số tiền thanh toán',
                          value: currencyFormat.format(widget.plan.priceVnd),
                          valueColor: AppTheme.primary,
                          icon: Icons.payments_rounded,
                          onCopy: () => _copyToClipboard(widget.plan.priceVnd.toString(), 'Số tiền'),
                        ),
                        const Divider(color: AppTheme.border, height: 16),
                        _infoRow(
                          label: 'Nội dung chuyển khoản',
                          value: _transferContent,
                          valueColor: AppTheme.accent,
                          icon: Icons.description_rounded,
                          onCopy: () => _copyToClipboard(_transferContent, 'Nội dung'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Guide note
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, color: AppTheme.primary, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Sau khi hoàn tất quét mã và chuyển khoản trên app ngân hàng của bạn, hãy nhấn "Xác nhận đã chuyển khoản" để hệ thống tự động kích hoạt dịch vụ tức thì!',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Action
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppTheme.cardBackground,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _handleConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: _isProcessing
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Đang kiểm tra giao dịch...',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.flash_on_rounded, size: 20),
                          SizedBox(width: 6),
                          Text(
                            'Xác Nhận Đã Chuyển Khoản • Kích Hoạt Tức Thì',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
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
      children: [
        Icon(icon, size: 18, color: AppTheme.textMuted),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.bold,
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
    );
  }
}
