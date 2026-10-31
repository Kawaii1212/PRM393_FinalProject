import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finalproject/models/user_model.dart';
import 'package:finalproject/models/shop_model.dart';
import 'package:finalproject/models/notification_model.dart';
import 'package:finalproject/providers/auth_provider.dart';
import 'package:finalproject/providers/shop_provider.dart';
import 'package:finalproject/providers/chat_provider.dart';
import 'package:finalproject/providers/notification_provider.dart';
import 'package:finalproject/providers/subscription_provider.dart';
import 'package:finalproject/screens/shop_owner/shop_owner_dashboard_screen.dart';

void main() {
  testWidgets('Kiểm tra Tab Thông báo trên giao diện Chủ Shop (ShopOwnerDashboardScreen)', (tester) async {
    final shopOwner = UserModel(
      uid: 'owner_123',
      email: 'owner@badminton.vn',
      fullName: 'Nguyễn Văn Chủ Shop',
      phone: '0901234567',
      role: UserRole.stringer,
      createdAt: DateTime.now(),
    );

    SharedPreferences.setMockInitialValues({
      'gearsports_current_user': jsonEncode(shopOwner.toMap()),
    });

    final authProv = AuthProvider();
    await authProv.checkAuthSession();

    final shopProv = ShopProvider();
    final chatProv = ChatProvider();
    final notifProv = NotificationProvider();
    final subProv = SubscriptionProvider();

    final shop = Shop(
      id: 'shop_test',
      ownerUid: 'owner_123',
      name: 'Shop Cầu Lông Pro Sports',
      address: '123 Đường Cầu Lông, Quận 1',
      district: 'Quận 1',
      city: 'TP. Hồ Chí Minh',
      latitude: 10.7769,
      longitude: 106.7009,
      rating: 5.0,
      reviewCount: 0,
      machineModel: 'Yonex 9.0',
      stringerCert: 'Master Stringer',
      phone: '0901234567',
      openHours: '08:00 - 21:00',
      imageUrl: '',
      status: 'approved',
    );
    await shopProv.upsertShop(shop);

    // Thêm 1 thông báo bảo trì từ Admin
    await notifProv.syncForUser('owner_123');
    await notifProv.broadcastSystemNotification(
      title: '🛠️ Nâng Cấp Hệ Thống Đêm Nay',
      message: 'Hệ thống bảo trì lúc 00:00.',
      type: NotificationType.systemAlert,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: authProv),
          ChangeNotifierProvider.value(value: shopProv),
          ChangeNotifierProvider.value(value: chatProv),
          ChangeNotifierProvider.value(value: notifProv),
          ChangeNotifierProvider.value(value: subProv),
        ],
        child: const MaterialApp(
          home: ShopOwnerDashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Kiểm tra 5 tab trong BottomNavigationBar
    expect(find.text('Tổng quan'), findsOneWidget);
    expect(find.text('Vật phẩm'), findsOneWidget);
    expect(find.text('Tin nhắn'), findsOneWidget);
    expect(find.text('Thông báo'), findsOneWidget);
    expect(find.text('Tài khoản'), findsOneWidget);

    // 2. Chuyển sang Tab Thông Báo (bấm tab Thông báo)
    await tester.tap(find.text('Thông báo'));
    await tester.pumpAndSettle();

    // 3. Kiểm tra nội dung trong Tab Thông Báo
    expect(find.text('Thông Báo Hệ Thống & Bảo Trì'), findsOneWidget);
    expect(find.textContaining('Bảo trì & Nâng cấp'), findsOneWidget);
    expect(find.text('🛠️ Nâng Cấp Hệ Thống Đêm Nay'), findsNWidgets(2));
  });
}
