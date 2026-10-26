import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/notification_model.dart';
import '../../providers/notification_provider.dart';
import '../../theme/app_theme.dart';
import '../gear/gear_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int _selectedFilter = 0; // 0: All, 1: Tension alerts, 2: Order status
  final _dateFormat = DateFormat('dd/MM HH:mm');

  @override
  Widget build(BuildContext context) {
    final notifProvider = context.watch<NotificationProvider>();
    final allNotifs = notifProvider.notifications;

    final filteredNotifs = allNotifs.where((n) {
      if (_selectedFilter == 1) return n.type == NotificationType.tensionAlert;
      if (_selectedFilter == 2) return n.type == NotificationType.orderStatus;
      return true;
    }).toList();

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
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _filterChip(0, 'Tất cả (${allNotifs.length})'),
                const SizedBox(width: 8),
                _filterChip(1, 'Cảnh Báo Vợt'),
                const SizedBox(width: 8),
                _filterChip(2, 'Đơn Đặt Lịch'),
              ],
            ),
          ),

          // Notification List
          Expanded(
            child: filteredNotifs.isEmpty
                ? const Center(
                    child: Text(
                      'Không có thông báo nào trong mục này',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredNotifs.length,
                    itemBuilder: (context, idx) {
                      final item = filteredNotifs[idx];
                      return _buildNotificationCard(context, item, notifProvider);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(int index, String label) {
    final isSelected = _selectedFilter == index;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilter = index),
      selectedColor: AppTheme.primary,
      backgroundColor: AppTheme.surface,
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : AppTheme.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      side: BorderSide(color: isSelected ? AppTheme.primary : AppTheme.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Widget _buildNotificationCard(BuildContext context, AppNotification item, NotificationProvider provider) {
    Color typeColor;
    IconData typeIcon;

    switch (item.type) {
      case NotificationType.tensionAlert:
        typeColor = AppTheme.danger;
        typeIcon = Icons.warning_amber_rounded;
        break;
      case NotificationType.orderStatus:
        typeColor = AppTheme.primary;
        typeIcon = Icons.check_circle_outline_rounded;
        break;
      case NotificationType.promo:
        typeColor = AppTheme.accent;
        typeIcon = Icons.card_giftcard_rounded;
        break;
    }

    return InkWell(
      onTap: () {
        provider.markAsRead(item.id);
        // Navigate to Gear Detail if it links to a racket (Theo đúng sơ đồ Screen Flow!)
        if (item.targetRacketId != null) {
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
            color: !item.isRead ? typeColor.withOpacity(0.5) : AppTheme.border,
            width: !item.isRead ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(typeIcon, color: typeColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: !item.isRead ? FontWeight.bold : FontWeight.w600,
                            fontSize: 14,
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
                    item.message,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  if (item.targetRacketId != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: const [
                        Text(
                          'Nhấn để xem chi tiết cây vợt này ➔',
                          style: TextStyle(
                            color: AppTheme.primaryDark,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (!item.isRead) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: typeColor,
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
