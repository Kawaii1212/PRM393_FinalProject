import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/chat_provider.dart';
import '../providers/notification_provider.dart';
import 'home/home_dashboard_screen.dart';
import 'gear/gear_list_screen.dart';
import 'shop/shop_map_screen.dart';
import 'chat/chat_screen.dart';
import 'notifications/notifications_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final notifProvider = context.watch<NotificationProvider>();

    final screens = [
      HomeDashboardScreen(onNavigateTab: _onTabSelected),
      const GearListScreen(),
      const ShopMapScreen(),
      const ChatListScreen(),
      const NotificationsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabSelected,
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppTheme.surface,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: AppTheme.textMuted,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            activeIcon: Icon(Icons.dashboard_rounded, color: AppTheme.primary),
            label: 'Trang Chủ',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.sports_tennis_rounded),
            activeIcon: Icon(Icons.sports_tennis_rounded, color: AppTheme.primary),
            label: 'Gara Vợt',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.map_rounded),
            activeIcon: Icon(Icons.map_rounded, color: AppTheme.primary),
            label: 'Bản Đồ',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.chat_bubble_outline_rounded),
                if (chatProvider.unreadMessagesCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${chatProvider.unreadMessagesCount}',
                        style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            activeIcon: const Icon(Icons.chat_bubble_rounded, color: AppTheme.primary),
            label: 'Tin Nhắn',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.notifications_none_rounded),
                if (notifProvider.unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppTheme.danger,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${notifProvider.unreadCount}',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            activeIcon: const Icon(Icons.notifications_rounded, color: AppTheme.primary),
            label: 'Thông Báo',
          ),
        ],
      ),
    );
  }
}
