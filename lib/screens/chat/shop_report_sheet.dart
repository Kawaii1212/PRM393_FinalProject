import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/shop_report_model.dart';
import '../../models/notification_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/shop_provider.dart';
import '../../theme/app_theme.dart';

class ShopReportSheet extends StatefulWidget {
  final String shopId;
  final String shopName;
  final String? threadId;

  const ShopReportSheet({
    super.key,
    required this.shopId,
    required this.shopName,
    this.threadId,
  });

  static Future<void> show(
    BuildContext context, {
    required String shopId,
    required String shopName,
    String? threadId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShopReportSheet(
        shopId: shopId,
        shopName: shopName,
        threadId: threadId,
      ),
    );
  }

  @override
  State<ShopReportSheet> createState() => _ShopReportSheetState();
}

class _ShopReportSheetState extends State<ShopReportSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();

  final List<String> _violationCategories = [
    'Gian lận thông số căng cước (đan non ký, sai thỏa thuận)',
    'Cung cấp cước nhái, hàng giả, phụ kiện kém chất lượng',
    'Khống giá / Thu tiền cao hơn giá báo trên app & tin nhắn',
    'Làm nứt gãy / hỏng vợt nhưng chối bỏ trách nhiệm bồi thường',
    'Nhận vợt / nhận cọc nhưng quá hạn không trả, có dấu hiệu chiếm đoạt',
    'Thái độ xúc phạm, khiếm nhã, đe dọa khách hàng qua tin nhắn',
    'Hành vi gian dối hoặc dấu hiệu lừa đảo khác',
  ];

  late String _selectedReason;
  bool _attachChatHistory = true;
  bool _confirmedTruth = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedReason = _violationCategories.first;
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_confirmedTruth) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng tích xác nhận cam đoan thông tin báo cáo là trung thực!'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final authProv = context.read<AuthProvider>();
    final chatProv = context.read<ChatProvider>();
    final notifProv = context.read<NotificationProvider>();
    final currentUser = authProv.currentUser;

    // Collect chat evidence if requested and thread exists
    String? evidence;
    if (_attachChatHistory && widget.threadId != null) {
      final thread = chatProv.getThread(widget.threadId!);
      if (thread != null && thread.messages.isNotEmpty) {
        final recent = thread.messages.length > 6
            ? thread.messages.sublist(thread.messages.length - 6)
            : thread.messages;
        evidence = recent.map((m) {
          final sender = m.isFromUser ? 'Khách hàng' : 'Shop';
          return '[$sender - ${m.timestamp.hour}:${m.timestamp.minute.toString().padLeft(2, '0')}]: ${m.text}';
        }).join('\n');
      }
    }

    final reportId = 'report_${DateTime.now().millisecondsSinceEpoch}';
    final report = ShopReport(
      id: reportId,
      shopId: widget.shopId,
      shopName: widget.shopName,
      reporterUid: currentUser?.uid ?? 'anonymous_player',
      reporterName: currentUser?.fullName ?? 'Người chơi GearSports',
      reporterEmail: currentUser?.email ?? 'player@gearsports.com',
      reason: _selectedReason,
      description: _descController.text.trim(),
      chatEvidence: evidence,
      createdAt: DateTime.now(),
      status: 'pending',
    );

    // 1. Submit report to ChatProvider
    await chatProv.submitReport(report);

    // 2. Alert Admin via NotificationProvider
    notifProv.addNotification(
      title: '⚠️ ĐƠN BÁO CÁO VI PHẠM SHOP',
      message:
          'Người chơi ${report.reporterName} vừa gửi đơn báo cáo shop "${widget.shopName}" với lý do: $_selectedReason.',
      type: NotificationType.tensionAlert,
    );

    // 3. Insert system notice into the thread
    if (widget.threadId != null) {
      final shortCode = reportId.length > 6 ? reportId.substring(reportId.length - 6) : reportId;
      chatProv.sendSystemMessage(
        widget.threadId!,
        '🛡️ [HỆ THỐNG]: Đơn báo cáo vi phạm shop đã được gửi đến Ban Quản Trị (Admin). Mã thụ lý: #$shortCode. Admin sẽ kiểm duyệt lịch sử tin nhắn và xử lý thích đáng nếu phát hiện gian lận.',
      );
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    Navigator.pop(context); // Close sheet

    // Show Success Dialog
    _showSuccessDialog(context, reportId);
  }

  void _showSuccessDialog(BuildContext context, String reportId) {
    final shortCode = reportId.length > 6 ? reportId.substring(reportId.length - 6) : reportId;
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
                color: AppTheme.success.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Gửi Đơn Thành Công!',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
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
                  Text(
                    'Cửa hàng bị báo cáo: ${widget.shopName}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Mã hồ sơ: #$shortCode',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lý do: $_selectedReason',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Ban Quản Trị (Admin) đã tiếp nhận hồ sơ khiếu nại của bạn. Chúng tôi sẽ đối soát nội dung trao đổi, tiến hành xác minh độc lập và chế tài xử lý (cảnh cáo, hạ chuẩn hoặc thu hồi quyền hoạt động) đối với cửa hàng có hành vi gian dối.',
              style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 10),
            const Text(
              'Cảm ơn bạn đã đồng hành giữ gìn môi trường thể thao minh bạch và uy tín!',
              style: TextStyle(fontSize: 12, color: AppTheme.primary, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Đã hiểu', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProv = context.watch<AuthProvider>();
    final currentUser = authProv.currentUser;
    final shopProv = context.watch<ShopProvider>();
    final shop = shopProv.getShopById(widget.shopId);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Sheet Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.gavel_rounded,
                        color: AppTheme.danger,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ĐƠN BÁO CÁO VI PHẠM & GIAN DỐI',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.danger,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Gửi trực tiếp đến Ban Quản Trị Hệ Thống (Admin)',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.textMuted,
                            ),
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
                const SizedBox(height: 16),

                // Shop & Reporter Summary Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.storefront_rounded, size: 16, color: AppTheme.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Cửa hàng: ${widget.shopName}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (shop?.isApproved == true)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '✓ Shop xác thực',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const Divider(height: 16, color: AppTheme.border),
                      Row(
                        children: [
                          const Icon(Icons.person_outline_rounded, size: 16, color: AppTheme.textMuted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Người làm đơn: ${currentUser?.fullName ?? 'Người chơi'} (${currentUser?.email ?? 'N/A'})',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Category selection
                const Text(
                  '1. Chọn hành vi vi phạm hoặc dấu hiệu gian dối *',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedReason,
                      dropdownColor: AppTheme.surface,
                      style: const TextStyle(fontSize: 12.5, color: AppTheme.textPrimary),
                      icon: const Icon(Icons.arrow_drop_down_rounded, color: AppTheme.primary),
                      items: _violationCategories.map((cat) {
                        return DropdownMenuItem<String>(
                          value: cat,
                          child: Text(
                            cat,
                            style: const TextStyle(fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedReason = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Description
                const Text(
                  '2. Mô tả chi tiết sự việc & bằng chứng gian lận *',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Ghi rõ thời điểm xảy ra, thông số đan cước đã thỏa thuận và sai lệch thực tế phát hiện được.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descController,
                  maxLines: 4,
                  minLines: 3,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText:
                        'Ví dụ: Tôi yêu cầu căng Yonex BG66UM 11kg tại tiệm, nhưng khi đo lại bằng máy thì chỉ đạt 9.2kg, cước có dấu hiệu hàng nhái không có tem Yonex chính hãng...',
                    hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    filled: true,
                    fillColor: AppTheme.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.danger, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().length < 10) {
                      return 'Vui lòng mô tả ít nhất 10 ký tự để Admin có đủ cơ sở xác minh.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Chat evidence checkbox
                if (widget.threadId != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _attachChatHistory,
                      onChanged: (val) => setState(() => _attachChatHistory = val ?? true),
                      title: const Text(
                        'Đính kèm trích xuất tin nhắn trao đổi gần nhất làm bằng chứng cho Admin',
                        style: TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                      ),
                      activeColor: AppTheme.primary,
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Commitment checkbox
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
                  ),
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _confirmedTruth,
                    onChanged: (val) => setState(() => _confirmedTruth = val ?? false),
                    title: const Text(
                      'Tôi cam đoan thông tin báo cáo trên là hoàn toàn trung thực và chịu trách nhiệm trước Ban Quản Trị.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    activeColor: AppTheme.danger,
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  ),
                ),
                const SizedBox(height: 20),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textMuted,
                          side: const BorderSide(color: AppTheme.border),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Hủy bỏ'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _handleSubmit,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.gavel_rounded, size: 18),
                        label: Text(
                          _isSubmitting ? 'Đang gửi...' : 'GỬI ĐƠN BÁO CÁO',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.danger,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
      ),
    );
  }
}
