import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/racket_model.dart';
import '../../models/tension_log_model.dart';
import '../../models/notification_model.dart';
import '../../providers/racket_provider.dart';
import '../../providers/notification_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/tension_badge.dart';
import 'add_edit_racket_screen.dart';
import '../../widgets/racket_image_widget.dart';

class GearDetailScreen extends StatefulWidget {
  final String racketId;

  const GearDetailScreen({super.key, required this.racketId});

  @override
  State<GearDetailScreen> createState() => _GearDetailScreenState();
}

class _GearDetailScreenState extends State<GearDetailScreen> {
  final _dateFormat = DateFormat('dd/MM/yyyy');

  void _confirmDeleteRacket(BuildContext context, Racket racket) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: AppTheme.danger),
            SizedBox(width: 8),
            Text(
              'Xóa vợt khỏi Gara?',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa cây vợt "${racket.brand} ${racket.modelName}" khỏi Gara không? Toàn bộ lịch sử đan cước của cây vợt này cũng sẽ bị xóa.',
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
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx); // close dialog
              await context.read<RacketProvider>().deleteRacket(racket.id);
              if (context.mounted) {
                Navigator.pop(context); // return to Gara list
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Đã xóa vợt ${racket.brand} ${racket.modelName} khỏi Gara!',
                    ),
                    backgroundColor: AppTheme.danger,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Xóa Vợt'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteTensionLog(
    BuildContext context,
    Racket racket,
    TensionLog log,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: AppTheme.danger),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Xóa nhật ký đan cước?',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Bạn có muốn xóa lần đan "${log.stringModel} (${log.tensionLbs} lbs)" ngày ${_dateFormat.format(log.strungDate)} không?',
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
              await context
                  .read<RacketProvider>()
                  .deleteTensionLog(racket.id, log.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã xóa nhật ký đan cước!'),
                    backgroundColor: AppTheme.danger,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  void _showAddTensionLogDialog(BuildContext context, Racket racket) {
    final formKey = GlobalKey<FormState>();
    final stringModelController = TextEditingController();
    final tensionController = TextEditingController();
    final shopNameController = TextEditingController();
    final notesController = TextEditingController();
    double tensionValue = 0.0;
    bool isWarning = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final paddingBottom = MediaQuery.of(context).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, paddingBottom + 20),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Ghi Nhận Lần Đan Cước Mới',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: AppTheme.textMuted),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Cây vợt: ${racket.brand} ${racket.modelName} (Max: ${racket.maxTensionLbs} lbs)',
                        style: const TextStyle(color: AppTheme.primaryDark, fontSize: 13),
                      ),
                      const SizedBox(height: 16),

                      // String model field
                      TextFormField(
                        controller: stringModelController,
                        decoration: const InputDecoration(
                          labelText: 'Loại Dây Cước',
                          hintText: 'Ví dụ: Yonex Exbolt 63, Lining No.1, BG65...',
                          prefixIcon: Icon(Icons.line_weight_rounded, color: AppTheme.primary),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Vui lòng nhập loại cước' : null,
                      ),
                      const SizedBox(height: 14),

                      // Tension input field with real-time overload check
                      TextFormField(
                        controller: tensionController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Mức Căng Thực Tế (lbs)',
                          hintText: 'Ví dụ: 25.5, 26.0, 27.0',
                          prefixIcon: Icon(Icons.speed_rounded, color: AppTheme.primary),
                          suffixText: 'lbs',
                        ),
                        onChanged: (val) {
                          final parsed = double.tryParse(val) ?? 0.0;
                          setSheetState(() {
                            tensionValue = parsed;
                            isWarning = racket.isTensionExceeded(parsed);
                          });
                        },
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Vui lòng nhập số lbs';
                          final numVal = double.tryParse(v);
                          if (numVal == null || numVal < 18 || numVal > 36) {
                            return 'Mức căng hợp lệ từ 18 đến 36 lbs';
                          }
                          return null;
                        },
                      ),

                      // Overload Warning Banner (Bắt buộc theo yêu cầu SRS PRM393)
                      if (isWarning) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.danger.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.danger),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.dangerous_rounded, color: AppTheme.danger, size: 24),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'CẢNH BÁO NGUY HIỂM: Sức căng $tensionValue lbs vượt quá giới hạn an toàn (${racket.maxTensionLbs} lbs) của khung vợt này! Nguy cơ sụp/nứt khung rất cao!',
                                  style: const TextStyle(
                                    color: AppTheme.danger,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),

                      // Shop Name
                      TextFormField(
                        controller: shopNameController,
                        decoration: const InputDecoration(
                          labelText: 'Tên Shop / Thợ Đan',
                          prefixIcon: Icon(Icons.store_rounded, color: AppTheme.primary),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Notes
                      TextFormField(
                        controller: notesController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Ghi Chú Kỹ Thuật (Đan 4 nút, cảm nhận...)',
                          prefixIcon: Icon(Icons.edit_note_rounded, color: AppTheme.primary),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              final newLog = TensionLog(
                                id: 'log_${DateTime.now().millisecondsSinceEpoch}',
                                racketId: racket.id,
                                stringModel: stringModelController.text.trim(),
                                tensionLbs: double.parse(tensionController.text.trim()),
                                strungDate: DateTime.now(),
                                shopName: shopNameController.text.trim(),
                                notes: notesController.text.trim(),
                              );

                              // Update racket state
                              context.read<RacketProvider>().addTensionLog(racket.id, newLog);

                              // Also send notification confirmation (FR-06 & Luồng Sơ Đồ)
                              context.read<NotificationProvider>().addNotification(
                                title: '🏸 Đã ghi nhận đan cước mới!',
                                message: 'Vợt ${racket.modelName} đã được cập nhật cước ${newLog.stringModel} (${newLog.tensionLbs} lbs).',
                                type: NotificationType.orderStatus,
                                targetRacketId: racket.id,
                              );

                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Đã cập nhật nhật ký đan cước thành công!'),
                                  backgroundColor: AppTheme.primaryDark,
                                ),
                              );
                            }
                          },
                          child: const Text('Lưu Nhật Ký Đan Cước'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final racketProvider = context.watch<RacketProvider>();
    final racket = racketProvider.getRacketById(widget.racketId);

    if (racket == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi Tiết Vợt')),
        body: const Center(child: Text('Không tìm thấy vợt này')),
      );
    }

    final tensionProgress = (1.0 - (racket.tensionLossPercent / 100.0)).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: Text('${racket.brand} ${racket.modelName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Chỉnh sửa thông số & tải ảnh vợt',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đang mở màn hình chỉnh sửa vợt & tải ảnh...'), duration: Duration(milliseconds: 600)),
              );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddEditRacketScreen(existingRacket: racket),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger),
            tooltip: 'Xóa vợt khỏi Gara',
            onPressed: () => _confirmDeleteRacket(context, racket),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Card: Racket Overview & Tension Gauge
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: AppTheme.cardGradient,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: racket.needsRestring ? AppTheme.danger.withOpacity(0.5) : AppTheme.border,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryDark.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.primaryDark),
                        ),
                        child: Text(
                          racket.brand.toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.primaryDark,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      TensionBadge(
                        currentTension: racket.estimatedCurrentTension,
                        initialTension: racket.initialTensionLbs,
                        lossPercent: racket.tensionLossPercent,
                        needsRestring: racket.needsRestring,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    racket.modelName,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
                  Text(
                    '${racket.editionGen} • ${racket.colorway}',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),

                  RacketImageWidget(
                    imageUrl: racket.imageUrl,
                    brand: racket.brand,
                    height: 170,
                    borderRadius: 14,
                  ),
                  const SizedBox(height: 14),
                  // Tension Stats Highlight
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _tensionStatItem(
                              'Lực Căng Lúc Đan',
                              '${racket.initialTensionLbs} lbs',
                              AppTheme.textPrimary,
                            ),
                            Container(width: 1, height: 35, color: AppTheme.border),
                            _tensionStatItem(
                              'Ước Tính Hiện Tại',
                              '${racket.estimatedCurrentTension} lbs',
                              racket.needsRestring ? AppTheme.danger : AppTheme.primary,
                            ),
                            Container(width: 1, height: 35, color: AppTheme.border),
                            _tensionStatItem(
                              'Hao Hụt',
                              '-${racket.tensionLossPercent}%',
                              racket.needsRestring ? AppTheme.danger : AppTheme.accent,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: tensionProgress,
                            backgroundColor: AppTheme.surface,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              racket.needsRestring
                                  ? AppTheme.danger
                                  : (racket.tensionLossPercent > 12 ? AppTheme.accent : AppTheme.primary),
                            ),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Dây: ${racket.currentStringModel}',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                            ),
                            Text(
                              'Đã dùng: ${racket.daysSinceStrung} ngày (${racket.sessionsPlayed} buổi)',
                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Alert if needing restring (Tạm thời bỏ tính năng đặt lịch đan cước trực tiếp)
                  if (racket.needsRestring) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.danger.withOpacity(0.4)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: AppTheme.danger),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Cước đã chùng quá hạn! Độ đàn hồi giảm gây tốn lực cổ tay và tăng nguy cơ chấn thương.',
                              style: TextStyle(
                                color: AppTheme.danger,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Physical Specifications Grid (Thông số vật lý theo Tài liệu Chuẩn)
            const Text(
              'Thông Số Vật Lý & Kết Cấu Khung',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  _specRow('Phân khúc lối chơi', racket.playStyle, isHighlight: true),
                  const Divider(color: AppTheme.border, height: 16),
                  _specRow('Trọng lượng tĩnh', racket.weightU),
                  const Divider(color: AppTheme.border, height: 16),
                  _specRow('Chu vi cán', racket.gripG),
                  const Divider(color: AppTheme.border, height: 16),
                  _specRow('Độ cứng thân đũa', racket.shaftStiffness),
                  const Divider(color: AppTheme.border, height: 16),
                  _specRow('Điểm cân bằng tĩnh', '${racket.balancePointMm} mm'),
                  const Divider(color: AppTheme.border, height: 16),
                  _specRow('Điểm Swing Weight', '${racket.swingWeight} kg.cm²'),
                  const Divider(color: AppTheme.border, height: 16),
                  _specRow('Biên dạng khung', racket.frameProfile),
                  const Divider(color: AppTheme.border, height: 16),
                  _specRow('Sức căng tối đa (Max Tension)', '${racket.maxTensionLbs.toInt()} lbs (~12.7 kg)'),
                  const Divider(color: AppTheme.border, height: 16),
                  _specRow('Tình trạng cán cầm', racket.gripCondition),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tension History Logs (Nhật Ký Đan Cước - Yêu Cầu SRS & Screen Flow)
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Nhật Ký Đan Cước (Tension Log)',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showAddTensionLogDialog(context, racket),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18, color: AppTheme.primary),
                  label: const Text(
                    'Thêm lần đan',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (racket.tensionLogs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Center(
                  child: Text(
                    'Chưa có nhật ký đan cước nào. Nhấn "Thêm lần đan" để bắt đầu theo dõi!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: racket.tensionLogs.length,
                itemBuilder: (context, idx) {
                  final log = racket.tensionLogs[idx];
                  final isLatest = idx == 0;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isLatest
                            ? AppTheme.primary.withOpacity(0.45)
                            : AppTheme.border,
                      ),
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
                                color: (isLatest
                                        ? AppTheme.primary
                                        : AppTheme.primaryDark)
                                    .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.line_weight_rounded,
                                color: isLatest
                                    ? AppTheme.primary
                                    : AppTheme.primaryDark,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          log.stringModel,
                                          style: const TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isLatest) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primary.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'Hiện tại',
                                            style: TextStyle(
                                              color: AppTheme.primary,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today_rounded,
                                        color: AppTheme.textMuted,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _dateFormat.format(log.strungDate),
                                        style: const TextStyle(
                                          color: AppTheme.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryDark.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppTheme.primaryDark.withOpacity(0.4),
                                ),
                              ),
                              child: Text(
                                '${log.tensionLbs} lbs',
                                style: const TextStyle(
                                  color: AppTheme.primaryDark,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () => _confirmDeleteTensionLog(
                                context,
                                racket,
                                log,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppTheme.danger.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppTheme.danger.withOpacity(0.35),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: AppTheme.danger,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (log.shopName.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.store_rounded,
                                  color: AppTheme.textSecondary,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    log.shopName,
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (log.notes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.notes_rounded,
                                color: AppTheme.textMuted,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  log.notes,
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontStyle: FontStyle.italic,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 30),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  context.read<RacketProvider>().recordPlaySession(racket.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Đã ghi nhận 1 buổi chơi cho ${racket.modelName}! Độ bền cước đã cập nhật.'),
                      backgroundColor: AppTheme.primaryDark,
                    ),
                  );
                },
                icon: const Icon(Icons.sports_tennis_rounded, color: AppTheme.primary),
                label: const Text(
                  '+1 Buổi Chơi',
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppTheme.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showAddTensionLogDialog(context, racket),
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: const Text('Nhật Ký Đan Cước'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tensionStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _specRow(String title, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: isHighlight ? AppTheme.primary : AppTheme.textPrimary,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
