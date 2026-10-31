import 'package:finalproject/services/sepay_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finalproject/models/racket_model.dart';
import 'package:finalproject/models/user_model.dart';
import 'package:finalproject/models/shop_model.dart';
import 'package:finalproject/models/subscription_model.dart';
import 'package:finalproject/services/vietqr_service.dart';

void main() {
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

      // Định dạng mã phải có tiền tố 'GS VIP CRH93' và kèm theo mã phiên 8 chữ số
      expect(codeA, startsWith('GS VIP CRH93'));
      final partsA = codeA.split(' ');
      expect(partsA.length, equals(4));
      expect(int.tryParse(partsA[3]), isNotNull);
      expect(partsA[3].length, equals(8));

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
  });
}
