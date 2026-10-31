import 'dart:convert';
import 'package:finalproject/services/sepay_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finalproject/models/racket_model.dart';
import 'package:finalproject/models/user_model.dart';
import 'package:finalproject/models/shop_model.dart';
import 'package:finalproject/models/subscription_model.dart';
import 'package:finalproject/models/notification_model.dart';
import 'package:finalproject/models/chat_model.dart';
import 'package:finalproject/providers/notification_provider.dart';
import 'package:finalproject/providers/chat_provider.dart';
import 'package:finalproject/providers/admin_provider.dart';
import 'package:finalproject/providers/shop_provider.dart';
import 'package:finalproject/models/product_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finalproject/services/vietqr_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PRM393 Unit Tests - Badminton Racket & Tension Logic', () {
    test('Kiểm tra rủi ro vượt mức căng tối đa (Overload Tension Check)', () {
      final racket = Racket(
        id: 'r_test_01',
        brand: 'Yonex',
        modelName: 'Astrox 100ZZ',
        weightU: '4U',
        shaftStiffness: 'Rất cứng',
        balancePointMm: 305,
        maxTensionLbs: 28.0,
      );

      // Mức căng an toàn <= 28 lbs
      expect(racket.isTensionExceeded(26.0), isFalse);
      expect(racket.isTensionExceeded(28.0), isFalse);

      // Mức căng nguy hiểm > 28 lbs (nguy cơ sụp khung)
      expect(racket.isTensionExceeded(29.5), isTrue);
      expect(racket.isTensionExceeded(32.0), isTrue);
    });

    test('Kiểm tra thuật toán tính hao hụt lực căng và tuổi thọ cước (Tension Loss Curve)', () {
      final racketFresh = Racket(
        id: 'r_test_02',
        brand: 'Victor',
        modelName: 'Ryuga II',
        weightU: '4U',
        shaftStiffness: 'Cứng',
        balancePointMm: 308,
        maxTensionLbs: 31.0,
        currentStringModel: 'Lining No.1',
        initialTensionLbs: 27.0,
        strungDate: DateTime.now().subtract(const Duration(days: 3)),
        sessionsPlayed: 1,
      );

      expect(racketFresh.needsRestring, isFalse);
      expect(racketFresh.estimatedCurrentTension, greaterThan(24.0));

      // Vợt đã đan 50 ngày (quá hạn)
      final racketOld = Racket(
        id: 'r_test_03',
        brand: 'Yonex',
        modelName: 'Nanoflare 800',
        weightU: '4U',
        shaftStiffness: 'Cứng',
        balancePointMm: 290,
        maxTensionLbs: 28.0,
        currentStringModel: 'BG65',
        initialTensionLbs: 25.0,
        strungDate: DateTime.now().subtract(const Duration(days: 50)),
        sessionsPlayed: 20,
      );

      expect(racketOld.needsRestring, isTrue);
      expect(racketOld.tensionLossPercent, greaterThanOrEqualTo(20.0));
    });

    test('Kiểm tra quyền hạn gói Free vs VIP Player (Racket Limit & Health Features)', () {
      final freePlayer = UserModel(
        uid: 'user_free',
        email: 'free@player.vn',
        fullName: 'Player Free',
        phone: '0912345678',
        role: UserRole.player,
        createdAt: DateTime.now(),
        isVip: false,
      );

      // Free player: Tối đa 5 cây vợt (0-4 thêm được, 5 không thêm được)
      expect(freePlayer.canAddRacket(0), isTrue);
      expect(freePlayer.canAddRacket(4), isTrue);
      expect(freePlayer.canAddRacket(5), isFalse);
      expect(freePlayer.canAddRacket(6), isFalse);

      // Free player không được dùng Bác sĩ thể thao & Sổ tay chấn thương
      expect(freePlayer.canAccessHealthFeatures, isFalse);

      final vipPlayer = UserModel(
        uid: 'user_vip',
        email: 'vip@player.vn',
        fullName: 'Player VIP',
        phone: '0912345678',
        role: UserRole.player,
        createdAt: DateTime.now(),
        isVip: true,
        vipExpiresAt: DateTime.now().add(const Duration(days: 30)),
      );

      // VIP player: Thêm vợt không giới hạn & Toàn quyền dùng Bác sĩ thể thao
      expect(vipPlayer.isVipActive, isTrue);
      expect(vipPlayer.canAddRacket(5), isTrue);
      expect(vipPlayer.canAddRacket(100), isTrue);
      expect(vipPlayer.canAccessHealthFeatures, isTrue);
    });

    test('Kiểm tra chính sách Shop (Miễn phí 1 tháng đầu & Phí duy trì sau 1 tháng)', () {
      final now = DateTime.now();

      // Shop mới tạo: Trong hạn dùng thử 30 ngày
      final newShop = Shop(
        id: 'shop_01',
        name: 'Gear Sports Shop',
        address: 'Hà Nội',
        district: 'Cầu Giấy',
        city: 'Hà Nội',
        latitude: 21.0,
        longitude: 105.8,
        rating: 5.0,
        reviewCount: 0,
        machineModel: 'Yonex 9.0',
        stringerCert: 'Master Stringer',
        phone: '0912345678',
        openHours: '08:00 - 21:30',
        imageUrl: '',
        ownerUid: 'owner_01',
        createdAt: now.subtract(const Duration(days: 10)),
        trialExpiresAt: now.add(const Duration(days: 20)),
      );

      expect(newShop.isTrialActive, isTrue);
      expect(newShop.isSubscriptionActive, isTrue);

      // Shop đã tạo quá 30 ngày và chưa đóng phí duy trì -> Hết hạn
      final expiredShop = Shop(
        id: 'shop_02',
        name: 'Old Shop',
        address: 'Hà Nội',
        district: 'Cầu Giấy',
        city: 'Hà Nội',
        latitude: 21.0,
        longitude: 105.8,
        rating: 5.0,
        reviewCount: 0,
        machineModel: 'Victor C-7032',
        stringerCert: 'Kỹ thuật viên',
        phone: '0912345678',
        openHours: '08:00 - 21:30',
        imageUrl: '',
        ownerUid: 'owner_02',
        createdAt: now.subtract(const Duration(days: 45)),
        trialExpiresAt: now.subtract(const Duration(days: 15)),
      );

      expect(expiredShop.isTrialActive, isFalse);
      expect(expiredShop.isPaidActive, isFalse);
      expect(expiredShop.isSubscriptionActive, isFalse);

      // Shop đã đóng phí gia hạn 90 ngày (40k) -> Hoạt động bình thường
      final subscribedShop = expiredShop.copyWith(
        subscriptionExpiresAt: now.add(const Duration(days: 90)),
      );

      expect(subscribedShop.isPaidActive, isTrue);
      expect(subscribedShop.isSubscriptionActive, isTrue);
    });

    test('Kiểm tra bảng giá và cấu trúc sinh mã VietQR Napas 24/7', () {
      expect(SubscriptionPlan.playerPlans[0].priceVnd, equals(29000));
      expect(SubscriptionPlan.playerPlans[1].priceVnd, equals(59000));
      expect(SubscriptionPlan.shopPlans[0].priceVnd, equals(20000));
      expect(SubscriptionPlan.shopPlans[1].priceVnd, equals(40000));

      final qrUrl = VietQrConfig.generateQrImageUrl(
        amount: 29000,
        transferContent: 'GS VIP 12345 001',
      );

      expect(qrUrl, contains('amount=29000'));
      expect(qrUrl, contains('img.vietqr.io'));
    });

    test('Kiểm tra thuật toán chuẩn hóa mã giao dịch SePAY Open Banking', () {
      final code1 = SepayService.normalizeCode('GS VIP 12345 001');
      final code2 = SepayService.normalizeCode('gs_vip-12345--001');
      final bankRemark = 'MBBank TK 0949614588 +29,000VND ND: GSVIP12345001 FT23948';
      final normalizedBankRemark = SepayService.normalizeCode(bankRemark);

      expect(code1, equals('GSVIP12345001'));
      expect(code2, equals('GSVIP12345001'));
      expect(normalizedBankRemark, contains(code1));
    });

    test('Kiểm tra sinh mã nội dung chuyển khoản duy nhất và cơ chế chống gian lận dùng lại giao dịch (Replay Prevention)', () {
      final codeA = VietQrConfig.generateTransferContent(
        prefix: 'GS VIP',
        userId: 'player_crh93',
      );

      // Định dạng mã rút gọn: 'VIP RH93' và kèm theo mã phiên ngẫu nhiên 8 chữ số
      expect(codeA, startsWith('VIP RH93'));
      final partsA = codeA.split(' ');
      expect(partsA.length, equals(3));
      expect(int.tryParse(partsA[2]), isNotNull);
      expect(partsA[2].length, equals(8));

      // Mô phỏng chống dùng lại giao dịch (Replay Attack Prevention)
      final usedIds = <String>{'6cccf169-d50f-11f1-8895-0afffe87053b'};
      final currentTxId = '6cccf169-d50f-11f1-8895-0afffe87053b';
      final newTxId = 'f0c2a916-d50b-11f1-8895-0afffe87053b';

      // Giao dịch đã kích hoạt sẽ bị chặn
      expect(usedIds.contains(currentTxId), isTrue);
      // Giao dịch mới chưa từng kích hoạt sẽ được chấp thuận
      expect(usedIds.contains(newTxId), isFalse);

      // Kiểm tra so khớp chính xác mã phiên: Giao dịch cũ với mã khác sẽ không được chấp nhận
      final oldBankRemark = 'MBBank TK 0949614588 ND: 154404567923-GS VIP CRH93 240-CHUYEN TIEN';
      final normalizedOldBank = SepayService.normalizeCode(oldBankRemark);
      final newSessionCode = SepayService.normalizeCode('GS VIP CRH93 84729103');
      // Nội dung cũ không chứa mã phiên mới 8 chữ số -> Khớp thất bại (an toàn, không gia hạn bậy)
      expect(normalizedOldBank.contains(newSessionCode), isFalse);
    });

    test('Kiểm tra thông báo của người chơi & tăng/giảm số chấm đỏ khi thêm vợt (Player Notification & Red Dot Badge)', () async {
      SharedPreferences.setMockInitialValues({});
      final notifProv = NotificationProvider();

      // Ban đầu không có thông báo, unreadCount = 0 (không có chấm đỏ)
      expect(notifProv.unreadCount, equals(0));

      // 1. Thêm vợt thành công -> Sinh thông báo racketUpdate -> unreadCount tăng lên 1 (chấm đỏ hiện số 1)
      await notifProv.addNotification(
        title: '🏸 Đã thêm vợt mới vào Gara!',
        message: 'Cây vợt Yonex Astrox 100ZZ đã được thêm thành công vào Gara của bạn.',
        type: NotificationType.racketUpdate,
        targetRacketId: 'racket_123',
      );

      expect(notifProv.unreadCount, equals(1));
      expect(notifProv.notifications.length, equals(1));
      expect(notifProv.notifications.first.type, equals(NotificationType.racketUpdate));
      expect(notifProv.notifications.first.isRead, isFalse);

      // 2. Thêm tiếp 1 cây vợt khác -> unreadCount tăng lên 2 (chấm đỏ hiện số 2)
      await notifProv.addNotification(
        title: '🏸 Đã thêm vợt mới vào Gara!',
        message: 'Cây vợt Victor Thruster Ryuga II đã được thêm thành công vào Gara của bạn.',
        type: NotificationType.racketUpdate,
        targetRacketId: 'racket_456',
      );

      expect(notifProv.unreadCount, equals(2));

      // 3. Người chơi chạm vào đọc 1 thông báo -> unreadCount giảm về 1
      final firstNotifId = notifProv.notifications.first.id;
      await notifProv.markAsRead(firstNotifId);
      expect(notifProv.unreadCount, equals(1));

      // 4. Nhấn "Đã đọc tất cả" -> unreadCount về 0 (chấm đỏ biến mất)
      await notifProv.markAllAsRead();
      expect(notifProv.unreadCount, equals(0));

      // 5. Kiểm tra cảnh báo cước chùng cho vợt cũ
      final oldRacket = Racket(
        id: 'r_old_tension',
        brand: 'Yonex',
        modelName: 'Nanoflare 800',
        weightU: '4U',
        shaftStiffness: 'Cứng',
        balancePointMm: 295,
        maxTensionLbs: 28.0,
        initialTensionLbs: 26.0,
        strungDate: DateTime.now().subtract(const Duration(days: 60)),
        sessionsPlayed: 25,
      );
      expect(oldRacket.needsRestring, isTrue);

      await notifProv.syncRacketTensionAlerts([oldRacket]);
      expect(notifProv.unreadCount, equals(1));
      expect(notifProv.notifications.any((n) => n.type == NotificationType.tensionAlert), isTrue);
    });

    test('Kiểm tra huy hiệu tin nhắn chưa đọc (unreadMessagesCount) và cơ chế tăng giảm unreadCount', () async {
      SharedPreferences.setMockInitialValues({});
      final chatProv = ChatProvider();

      // Ban đầu không có tin nhắn chưa đọc
      expect(chatProv.unreadMessagesCount, equals(0));

      // Giả lập cuộc trò chuyện 1 có 1 tin nhắn chưa đọc từ đối phương
      final thread1 = ChatThread(
        id: 'thread_user1_shop1',
        userId: 'user1',
        shopId: 'shop1',
        shopName: 'Shop Cầu Lông Minh Sport',
        shopAvatar: '',
        lastMessage: 'Chào bạn, cước BG66 Ultimax bên shop còn hàng nhé!',
        lastMessageTime: DateTime.now(),
        unreadCount: 1,
        messages: [
          ChatMessage(
            id: 'm1',
            senderId: 'shop1',
            text: 'Chào bạn, cước BG66 Ultimax bên shop còn hàng nhé!',
            timestamp: DateTime.now(),
            isFromUser: false,
          ),
        ],
      );

      // Thêm cuộc trò chuyện 2 có 2 tin nhắn chưa đọc
      final thread2 = ChatThread(
        id: 'thread_user1_shop2',
        userId: 'user1',
        shopId: 'shop2',
        shopName: 'VNB Sports Quận 10',
        shopAvatar: '',
        lastMessage: 'Vợt của bạn đã căng xong 28 lbs rồi ạ',
        lastMessageTime: DateTime.now(),
        unreadCount: 2,
        messages: [],
      );

      // Lưu vào cache để provider nạp
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'gearsports_chat_threads_user1',
        jsonEncode([thread1.toMap(), thread2.toMap()]),
      );

      // Đồng bộ theo user1 (vai trò người chơi)
      await chatProv.syncForUser('user1', role: UserRole.player);

      // Tổng số tin nhắn chưa đọc phải là 1 + 2 = 3
      expect(chatProv.unreadMessagesCount, equals(3));

      // Đánh dấu đọc cuộc trò chuyện 1 -> unreadCount của thread1 về 0, tổng giảm còn 2
      chatProv.markThreadAsRead(thread1.id);
      expect(chatProv.getThread(thread1.id)?.unreadCount, equals(0));
      expect(chatProv.unreadMessagesCount, equals(2));

      // Đánh dấu đọc cuộc trò chuyện 2 -> tổng về 0 (huy hiệu tin nhắn biến mất)
      chatProv.markThreadAsRead(thread2.id);
      expect(chatProv.getThread(thread2.id)?.unreadCount, equals(0));
      expect(chatProv.unreadMessagesCount, equals(0));
    });

    test('Kiểm tra AdminProvider cập nhật trạng thái VIP tức thì cho Player (updateUserVipStatus)', () async {
      SharedPreferences.setMockInitialValues({});
      final adminProv = AdminProvider();

      final player = UserModel(
        uid: 'player_test_01',
        email: 'player01@gearsports.com',
        fullName: 'Nguyễn Văn Cầu Lông',
        phone: '0901234567',
        role: UserRole.player,
        createdAt: DateTime.now(),
        isVip: false,
        vipExpiresAt: null,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'gearsports_local_users',
        jsonEncode({
          player.email.toLowerCase(): {
            'password': 'password123',
            'user': player.toMap(),
          }
        }),
      );

      await adminProv.refreshAdminData();
      expect(adminProv.users.length, equals(1));
      final userBefore = adminProv.users.first;
      expect(userBefore.isVip, isFalse);
      expect(userBefore.isVipActive, isFalse);
      expect(userBefore.vipDaysRemaining, equals(0));

      // Admin cấp VIP 30 ngày cho Player
      final expiresAt = DateTime.now().add(const Duration(days: 30));
      await adminProv.updateUserVipStatus(
        uid: player.uid,
        isVip: true,
        vipExpiresAt: expiresAt,
      );

      // UI Admin phản ánh ngay lập tức trong RAM mà không cần tải lại
      final userAfter = adminProv.users.first;
      expect(userAfter.isVip, isTrue);
      expect(userAfter.isVipActive, isTrue);
      expect(userAfter.vipDaysRemaining, greaterThanOrEqualTo(29));
      expect(userAfter.vipExpiresAt, isNotNull);

      // Đồng thời đồng bộ xuống Local Storage SharedPreferences
      final rawUpdated = prefs.getString('gearsports_local_users');
      expect(rawUpdated, isNotNull);
      final decoded = jsonDecode(rawUpdated!) as Map<String, dynamic>;
      final storedUser = decoded[player.email.toLowerCase()]['user'] as Map<String, dynamic>;
      expect(storedUser['isVip'], isTrue);
    });

    test('Kiểm tra duyệt shop tự động: sản phẩm đã bị từ chối trước đó thì không được duyệt theo khi shop được duyệt', () async {
      SharedPreferences.setMockInitialValues({});
      final shopProv = ShopProvider();

      // Giả lập Shop A đang chờ duyệt (status: 'pending')
      final shopA = Shop(
        id: 'shop_a',
        name: 'Shop Cầu Lông Minh Sport',
        address: '123 Đường Cầu Lông, Quận 10',
        district: 'Quận 10',
        city: 'TP. Hồ Chí Minh',
        latitude: 10.7769,
        longitude: 106.7009,
        rating: 5.0,
        reviewCount: 0,
        machineModel: 'Yonex 9.0',
        stringerCert: 'Master Stringer',
        phone: '0912345678',
        openHours: '08:00 - 21:30',
        imageUrl: '',
        ownerUid: 'owner_a',
        status: 'pending',
      );
      await shopProv.upsertShop(shopA);

      // Shop A có 2 sản phẩm: Sản phẩm 1 (cước giả) và Sản phẩm 2 (vợt chính hãng)
      final prod1 = Product(
        id: 'p1',
        shopId: 'shop_a',
        shopName: 'Shop Cầu Lông Minh Sport',
        name: 'Cước BG66 Không Rõ Nguồn Gốc',
        category: ProductCategory.string,
        price: 50000,
        description: 'Hàng xách tay',
        imageUrl: '',
        status: 'pending',
      );

      final prod2 = Product(
        id: 'p2',
        shopId: 'shop_a',
        shopName: 'Shop Cầu Lông Minh Sport',
        name: 'Vợt Yonex Nanoflare 800 Chính Hãng',
        category: ProductCategory.racket,
        price: 3200000,
        description: 'Bảo hành 12 tháng',
        imageUrl: '',
        status: 'pending',
      );

      await shopProv.upsertProduct(prod1);
      await shopProv.upsertProduct(prod2);

      // Admin kiểm duyệt và TỪ CHỐI duyệt Sản phẩm 1
      await shopProv.updateProductStatus(prod1, 'rejected');

      final itemsBeforeShopApproval = shopProv.getDirectProductsForShop('shop_a');
      final p1Before = itemsBeforeShopApproval.firstWhere((p) => p.id == 'p1');
      final p2Before = itemsBeforeShopApproval.firstWhere((p) => p.id == 'p2');
      expect(p1Before.isRejected, isTrue);
      expect(p2Before.isPending, isTrue);

      // Khi shop chưa được duyệt, danh mục Người chơi không thấy sản phẩm nào
      expect(shopProv.getProductsForShop('shop_a'), isEmpty);

      // Bây giờ Admin PHÊ DUYỆT Shop A
      await shopProv.updateShopStatus(shopA, 'approved');

      // 1. Shop A phải được duyệt thành công
      expect(shopProv.getShopById('shop_a')?.isApproved, isTrue);

      // 2. Sản phẩm 2 (không bị từ chối) được duyệt tự động theo shop
      final itemsAfterShopApproval = shopProv.getDirectProductsForShop('shop_a');
      final p2After = itemsAfterShopApproval.firstWhere((p) => p.id == 'p2');
      expect(p2After.isApproved, isTrue);
      expect(p2After.status, equals('approved'));

      // 3. Sản phẩm 1 (trước đó đã bị từ chối) TUYỆT ĐỐI KHÔNG được duyệt theo
      final p1After = itemsAfterShopApproval.firstWhere((p) => p.id == 'p1');
      expect(p1After.isApproved, isFalse);
      expect(p1After.isRejected, isTrue);
      expect(p1After.status, equals('rejected'));

      // 4. Danh mục Người chơi thấy Sản phẩm 2, nhưng KHÔNG thấy Sản phẩm 1
      final playerViewProducts = shopProv.getProductsForShop('shop_a');
      expect(playerViewProducts.any((p) => p.id == 'p2'), isTrue);
      expect(playerViewProducts.any((p) => p.id == 'p1'), isFalse);
    });

    test('Kiểm tra thông báo cho Chủ Shop: Nhận thông báo bảo trì, nâng cấp hệ thống từ Admin', () async {
      SharedPreferences.setMockInitialValues({});
      final notifProv = NotificationProvider();

      // Giả lập Chủ Shop đăng nhập với uid 'shop_owner_01'
      await notifProv.syncForUser('shop_owner_01');
      expect(notifProv.unreadCount, equals(0));
      expect(notifProv.notifications, isEmpty);

      // 1. Admin phát thông báo bảo trì & nâng cấp hệ thống
      await notifProv.broadcastSystemNotification(
        title: '🛠️ Thông Báo Bảo Trì & Nâng Cấp Hệ Thống',
        message: 'Hệ thống Gear Sports sẽ bảo trì máy chủ từ 00:00 - 02:00 ngày mai. Quý cửa hàng vui lòng lưu ý.',
        type: NotificationType.systemAlert,
      );

      // Chủ shop nhận được thông báo ngay lập tức, số chấm đỏ tăng lên 1
      expect(notifProv.unreadCount, equals(1));
      expect(notifProv.notifications.length, equals(1));

      final maintenanceNotif = notifProv.notifications.first;
      expect(maintenanceNotif.type, equals(NotificationType.systemAlert));
      expect(maintenanceNotif.isMaintenanceOrUpgrade, isTrue);
      expect(maintenanceNotif.isRead, isFalse);
      expect(notifProv.latestMaintenanceAlert?.id, equals(maintenanceNotif.id));

      // 2. Admin phát tiếp thông báo hướng dẫn quy chế đối tác Shop
      await notifProv.broadcastSystemNotification(
        title: '📢 Hướng dẫn duyệt sản phẩm dành cho Chủ Shop',
        message: 'Các chủ shop vui lòng hoàn tất thông tin chứng chỉ và hình ảnh vợt trưng bày.',
        type: NotificationType.shopNotice,
      );

      // Số thông báo chưa đọc tăng lên 2
      expect(notifProv.unreadCount, equals(2));
      expect(notifProv.shopNotifs.length, equals(1));
      expect(notifProv.systemAlerts.length, equals(1));

      // 3. Chủ shop đọc thông báo bảo trì -> Số chưa đọc giảm còn 1
      await notifProv.markAsRead(maintenanceNotif.id);
      expect(notifProv.unreadCount, equals(1));
      expect(notifProv.notifications.firstWhere((n) => n.id == maintenanceNotif.id).isRead, isTrue);

      // 4. Chủ shop bấm "Đã đọc tất cả" -> Số chưa đọc về 0
      await notifProv.markAllAsRead();
      expect(notifProv.unreadCount, equals(0));
    });
  });
}
