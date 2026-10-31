import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/notification_model.dart';
import '../../providers/notification_provider.dart';
import '../../theme/app_theme.dart';

class ShopOwnerNotificationsScreen extends StatefulWidget {
  final bool isTab;
  const ShopOwnerNotificationsScreen({super.key, this.isTab = false});

  @override
  State<ShopOwnerNotificationsScreen> createState() => _ShopOwnerNotificationsScreenState();
}

class _ShopOwnerNotificationsScreenState extends State<ShopOwnerNotificationsScreen> {
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');
  int _selectedFilterIndex = 0; // 0: Tất cả, 1: Bảo trì & Nâng cấp, 2: Shop & Đối tác, 3: Khác

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
          'Hành động này sẽ xóa toàn bộ danh sách thông báo hệ thống trên máy của bạn. Bạn có chắc chắn không?',
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

  void _showNotificationDetailModal(BuildContext context, AppNotification notif, NotificationProvider provider) {
    if (!notif.isRead) {
      provider.markAsRead(notif.id);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getTypeColor(notif.type).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getTypeIcon(notif.type),
                    color: _getTypeColor(notif.type),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _getTypeColor(notif.type).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          notif.typeDisplayName,
                          style: TextStyle(
                            color: _getTypeColor(notif.type),
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _dateFormat.format(notif.timestamp),
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              notif.title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Text(
                notif.message,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13.5,
                  height: 1.55,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.verified_user_rounded, size: 15, color: AppTheme.primary),
                const SizedBox(width: 6),
                const Text(
                  'Ban Quản Trị Hệ Thống Gear Sports',
                  style: TextStyle(
                    color: AppTheme.primaryDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger, size: 20),
                  tooltip: 'Xóa thông báo này',
                  onPressed: () {
                    Navigator.pop(ctx);
                    provider.removeNotification(notif.id);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Đã hiểu & Đóng'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(NotificationType type) {
    switch (type) {
      case NotificationType.systemAlert:
        return Colors.orangeAccent;
      case NotificationType.shopNotice:
        return const Color(0xFFFFD700);
      case NotificationType.tensionAlert:
        return AppTheme.danger;
      case NotificationType.orderStatus:
        return Colors.lightBlueAccent;
      case NotificationType.racketUpdate:
        return AppTheme.primary;
      case NotificationType.promo:
        return AppTheme.accent;
    }
  }

  IconData _getTypeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.systemAlert:
        return Icons.build_circle_rounded;
      case NotificationType.shopNotice:
        return Icons.storefront_rounded;
      case NotificationType.tensionAlert:
        return Icons.warning_amber_rounded;
      case NotificationType.orderStatus:
        return Icons.receipt_long_rounded;
      case NotificationType.racketUpdate:
        return Icons.sports_tennis_rounded;
      case NotificationType.promo:
        return Icons.campaign_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifProvider = context.watch<NotificationProvider>();
    final allNotifs = notifProvider.notifications;

    final systemAlertNotifs = allNotifs.where((n) => n.isMaintenanceOrUpgrade).toList();
    final shopNotifs = allNotifs.where((n) => n.type == NotificationType.shopNotice).toList();
    final otherNotifs = allNotifs.where((n) => !n.isMaintenanceOrUpgrade && n.type != NotificationType.shopNotice).toList();

    List<AppNotification> displayList;
    switch (_selectedFilterIndex) {
      case 1:
        displayList = systemAlertNotifs;
        break;
      case 2:
        displayList = shopNotifs;
        break;
      case 3:
        displayList = otherNotifs;
        break;
      case 0:
      default:
        displayList = allNotifs;
        break;
    }

    final latestMaintenance = notifProvider.latestMaintenanceAlert;

    final bodyContent = RefreshIndicator(
      onRefresh: () async {
        await notifProvider.syncSystemNotifications();
      },
      child: Column(
        children: [
          // Tiêu đề & nút chức năng nhanh khi hiển thị dưới dạng Tab
          if (widget.isTab)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_rounded, color: AppTheme.primary, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'Thông Báo Hệ Thống & Bảo Trì',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (notifProvider.unreadCount > 0)
                    TextButton.icon(
                      onPressed: () => notifProvider.markAllAsRead(),
                      icon: const Icon(Icons.done_all_rounded, size: 16, color: AppTheme.primary),
                      label: const Text(
                        'Đã đọc tất cả',
                        style: TextStyle(color: AppTheme.primary, fontSize: 11),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  if (allNotifs.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_sweep_outlined, color: AppTheme.textSecondary, size: 20),
                      tooltip: 'Xóa tất cả thông báo',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _confirmClearAll(context, notifProvider),
                    ),
                ],
              ),
            ),

          // Banner cảnh báo bảo trì / nâng cấp nổi bật nếu có thông báo bảo trì gần đây
          if (latestMaintenance != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.orangeAccent.withOpacity(0.5), width: 1.2),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.build_circle_rounded, color: Colors.orangeAccent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          latestMaintenance.title,
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          latestMaintenance.message,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 11.5,
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Bộ lọc danh mục thông báo
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip(0, 'Tất cả (${allNotifs.length})'),
                const SizedBox(width: 8),
                _buildFilterChip(1, '🛠️ Bảo trì & Nâng cấp (${systemAlertNotifs.length})'),
                const SizedBox(width: 8),
                _buildFilterChip(2, '🏪 Đối tác Shop (${shopNotifs.length})'),
                const SizedBox(width: 8),
                _buildFilterChip(3, '📢 Khác (${otherNotifs.length})'),
              ],
            ),
          ),

          // Danh sách thông báo
          Expanded(
            child: displayList.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
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
                              'Chưa có thông báo nào từ Admin',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Khi Admin phát thông báo bảo trì, nâng cấp tính năng hoặc chính sách dịch vụ, bạn sẽ nhận được thông báo tại đây.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: displayList.length,
                    itemBuilder: (ctx, idx) {
                      final item = displayList[idx];
                      final color = _getTypeColor(item.type);
                      final icon = _getTypeIcon(item.type);

                      return InkWell(
                        onTap: () => _showNotificationDetailModal(context, item, notifProvider),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: item.isRead ? AppTheme.surface : AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: !item.isRead ? color.withOpacity(0.55) : AppTheme.border,
                              width: !item.isRead ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(icon, size: 12, color: color),
                                        const SizedBox(width: 4),
                                        Text(
                                          item.typeDisplayName,
                                          style: TextStyle(
                                            color: color,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _dateFormat.format(item.timestamp),
                                    style: const TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                  if (!item.isRead) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: AppTheme.danger,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                item.title,
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: !item.isRead ? FontWeight.bold : FontWeight.w600,
                                  fontSize: 14.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.message,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12.5,
                                  height: 1.4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );

    if (widget.isTab) {
      return bodyContent;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông Báo Từ Admin'),
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
      body: bodyContent,
    );
  }

  Widget _buildFilterChip(int index, String label) {
    final isSelected = _selectedFilterIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilterIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
