import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/injury_model.dart';
import '../../providers/injury_provider.dart';
import '../../theme/app_theme.dart';
import 'injury_assessment_screen.dart';

class InjuryHistoryScreen extends StatelessWidget {
  const InjuryHistoryScreen({super.key});

  void _showStatusDialog(BuildContext context, InjuryRecord record) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cập Nhật Trạng Thái Phục Hồi',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Chấn thương: ${record.injuryNameVi}',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 18),
              for (final status in RecoveryStatus.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    record.status == status
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: status.color,
                  ),
                  title: Text(
                    status.label,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: record.status == status
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.read<InjuryProvider>().updateRecordStatus(record.id, status);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Đã cập nhật trạng thái: ${status.label}'),
                        backgroundColor: status.color,
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, InjuryRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Xóa Bản Ghi Chấn Thương?',
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa bản ghi "${record.injuryNameVi}" không?',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<InjuryProvider>().deleteRecord(record.id);
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

  @override
  Widget build(BuildContext context) {
    final injuryProv = context.watch<InjuryProvider>();
    final records = injuryProv.records;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sổ Tay Chấn Thương 📋'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const InjuryAssessmentScreen(),
            ),
          );
        },
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Kiểm Tra Mới',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: records.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.sentiment_very_satisfied_rounded,
                        color: AppTheme.primary,
                        size: 54,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Cơ Thể Đang Khỏe Mạnh!',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Bạn chưa có bản ghi chấn thương nào. Hãy duy trì khởi động kỹ và kiểm tra mức căng vợt thường xuyên trước khi ra sân.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const InjuryAssessmentScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      icon: const Icon(Icons.healing_rounded, size: 20),
                      label: const Text(
                        'Kiểm Tra Chấn Thương Đầu Tiên',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              itemCount: records.length,
              separatorBuilder: (_, index) => const SizedBox(height: 12),
              itemBuilder: (context, idx) {
                final r = records[idx];
                final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(r.createdAt);

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: r.status == RecoveryStatus.fullyRecovered
                          ? AppTheme.border
                          : r.status.color.withOpacity(0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(r.bodyPart.icon, color: AppTheme.primary, size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.injuryNameVi,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  dateStr,
                                  style: const TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textMuted),
                            color: AppTheme.surface,
                            onSelected: (val) {
                              if (val == 'status') {
                                _showStatusDialog(context, r);
                              } else if (val == 'delete') {
                                _confirmDelete(context, r);
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'status',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_note_rounded, size: 18),
                                    SizedBox(width: 8),
                                    Text('Cập nhật trạng thái'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline_rounded, color: AppTheme.danger, size: 18),
                                    SizedBox(width: 8),
                                    Text('Xóa bản ghi', style: TextStyle(color: AppTheme.danger)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          // Status Badge
                          InkWell(
                            onTap: () => _showStatusDialog(context, r),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: r.status.color.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: r.status.color),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    r.status.label,
                                    style: TextStyle(
                                      color: r.status.color,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.arrow_drop_down, color: r.status.color, size: 16),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Pain Score Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Đau: ${r.painScore}/10',
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Body Part Tag
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              r.bodyPart.shortLabel,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (r.relatedRacketName != null && r.relatedRacketName!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.sports_tennis_outlined, size: 14, color: AppTheme.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Vợt khi chấn thương: ${r.relatedRacketName}',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11.5,
                                ),
                                overflow: TextOverflow.ellipsis,
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
    );
  }
}
