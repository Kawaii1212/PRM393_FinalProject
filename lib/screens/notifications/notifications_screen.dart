import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/notification_model.dart';
import '../../providers/notification_provider.dart';
import '../../providers/racket_provider.dart';
import '../../theme/app_theme.dart';
import '../gear/gear_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _dateFormat = DateFormat('dd/MM HH:mm');
  int _selectedFilterIndex = 0; // 0: Tất cả, 1: Vợt & Cước, 2: Cảnh báo, 3: Hệ thống

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rackets = context.read<RacketProvider>().allRackets;
      context.read<NotificationProvider>().syncRacketTensionAlerts(rackets);
    });
  }

  void _confirmClearAll(BuildContext context, NotificationProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep_rounded, color: AppTheme.danger),
            SizedBox(width: 8),
            Text(
              'Xóa tất cả thông báo?',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          'Hành động này sẽ xóa toàn bộ danh sách thông báo của bạn. Bạn có chắc chắn muốn tiếp tục không?',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.clearAllNotifications();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã xóa toàn bộ thông báo!'),
                  backgroundColor: AppTheme.danger,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa tất cả'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifProvider = context.watch<NotificationProvider>();
    final allNotifs = notifProvider.notifications;

    // Phân loại thông báo cho các filter tabs
    final racketNotifs = allNotifs.where((n) =>
        n.type == NotificationType.racketUpdate ||
        n.type == NotificationType.orderStatus).toList();
    final tensionAlertNotifs = allNotifs.where((n) =>
        n.type == NotificationType.tensionAlert).toList();
    final promoNotifs = allNotifs.where((n) =>
        n.type == NotificationType.promo ||
        n.type == NotificationType.systemAlert ||
        n.type == NotificationType.shopNotice).toList();

    List<AppNotification> displayNotifs;
    switch (_selectedFilterIndex) {
      case 1:
        displayNotifs = racketNotifs;
        break;
      case 2:
        displayNotifs = tensionAlertNotifs;
        break;
      case 3:
        displayNotifs = promoNotifs;
        break;
      case 0:
      default:
        displayNotifs = allNotifs;
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông Báo & Cảnh Báo'),
        actions: [
          if (notifProvider.unreadCount > 0)
            TextButton.icon(
              onPressed: () => notifProvider.markAllAsRead(),
              icon: const Icon(Icons.done_all_rounded, size: 18, color: AppTheme.primary),
              label: const Text(
                'Đã đọc tất cả',
                style: TextStyle(color: AppTheme.primary, fontSize: 12),
              ),
            ),
          if (allNotifs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: AppTheme.textSecondary),
              tooltip: 'Xóa tất cả thông báo',
              onPressed: () => _confirmClearAll(context, notifProvider),
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip(0, 'Tất cả (${allNotifs.length})'),
                const SizedBox(width: 8),
                _buildFilterChip(1, '🏸 Vợt & Cước (${racketNotifs.length})'),
                const SizedBox(width: 8),
                _buildFilterChip(2, '⚠️ Cảnh báo (${tensionAlertNotifs.length})'),
                const SizedBox(width: 8),
                _buildFilterChip(3, '🎁 Tin tức (${promoNotifs.length})'),
              ],
            ),
          ),

          // Notification List
          Expanded(
            child: displayNotifs.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight.withOpacity(0.4),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.notifications_off_outlined,
                              size: 48,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Chưa có thông báo nào',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Khi bạn thêm vợt mới vào Gara hoặc vợt bị chùng cước, thông báo sẽ xuất hiện tại đây.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: displayNotifs.length,
                    itemBuilder: (context, idx) {
                      final item = displayNotifs[idx];
                      return Dismissible(
                        key: ValueKey(item.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.danger.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.delete_outline_rounded, color: Colors.white),
                              SizedBox(width: 6),
                              Text(
                                'Xóa',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        onDismissed: (_) {
                          notifProvider.removeNotification(item.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Đã xóa: ${item.title}'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: _buildNotificationCard(context, item, notifProvider),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(int index, String label) {
    final isSelected = _selectedFilterIndex == index;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilterIndex = index),
      selectedColor: AppTheme.primary,
      backgroundColor: AppTheme.surface,
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : AppTheme.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      side: BorderSide(
        color: isSelected ? AppTheme.primary : AppTheme.border,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    AppNotification item,
    NotificationProvider provider,
  ) {
    Color typeColor;
    IconData typeIcon;
    String tagLabel;

    switch (item.type) {
      case NotificationType.racketUpdate:
        typeColor = AppTheme.primary;
        typeIcon = Icons.sports_tennis_rounded;
        tagLabel = 'Vợt & Gara';
        break;
      case NotificationType.tensionAlert:
        typeColor = AppTheme.danger;
        typeIcon = Icons.warning_amber_rounded;
        tagLabel = 'Cảnh báo cước';
        break;
      case NotificationType.orderStatus:
        typeColor = Colors.lightBlueAccent;
        typeIcon = Icons.receipt_long_rounded;
        tagLabel = 'Dịch vụ đan';
        break;
      case NotificationType.systemAlert:
        typeColor = Colors.orangeAccent;
        typeIcon = Icons.build_circle_rounded;
        tagLabel = 'Bảo trì hệ thống';
        break;
      case NotificationType.shopNotice:
        typeColor = const Color(0xFFFFD700);
        typeIcon = Icons.storefront_rounded;
        tagLabel = 'Thông báo Shop';
        break;
      case NotificationType.promo:
        typeColor = AppTheme.accent;
        typeIcon = Icons.campaign_rounded;
        tagLabel = 'Hệ thống';
        break;
    }

    return InkWell(
      onTap: () {
        if (!item.isRead) {
          provider.markAsRead(item.id);
        }
        // Chuyển hướng đến chi tiết vợt nếu thông báo liên kết với một cây vợt
        if (item.targetRacketId != null && item.targetRacketId!.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GearDetailScreen(racketId: item.targetRacketId!),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: item.isRead ? AppTheme.surface : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: !item.isRead ? typeColor.withOpacity(0.55) : AppTheme.border,
            width: !item.isRead ? 1.5 : 1,
          ),
          boxShadow: !item.isRead
              ? [
                  BoxShadow(
                    color: typeColor.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon hộp đại diện
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(typeIcon, color: typeColor, size: 24),
            ),
            const SizedBox(width: 12),

            // Nội dung thông báo
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Tag phân loại nhỏ
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tagLabel,
                          style: TextStyle(
                            color: typeColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        _dateFormat.format(item.timestamp),
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.title,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: !item.isRead ? FontWeight.bold : FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.message,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                  if (item.targetRacketId != null && item.targetRacketId!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 13,
                          color: typeColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Nhấn để xem chi tiết cây vợt này ➔',
                          style: TextStyle(
                            color: typeColor,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Chấm đỏ đánh dấu chưa đọc (Unread Indicator Dot)
            if (!item.isRead) ...[
              const SizedBox(width: 8),
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: AppTheme.danger,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
