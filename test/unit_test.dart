import 'package:flutter_test/flutter_test.dart';
import 'package:finalproject/models/racket_model.dart';

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
  });
}
