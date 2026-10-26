import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finalproject/main.dart';

void main() {
  testWidgets(
    'Kiểm tra luồng màn hình Khởi động (Splash) & Đăng nhập / Đăng ký Gear Sports',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      // 1. Build app -> Hiển thị màn hình Splash trước
      await tester.pumpWidget(const GearSportsApp());
      expect(find.text('GEAR SPORTS'), findsOneWidget);

      // 2. Chờ Splash kiểm tra phiên và chuyển sang màn hình Login/Register
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 3. Kiểm tra các thành phần trên màn hình Đăng nhập
      expect(find.text('GEAR SPORTS'), findsOneWidget);
      expect(
        find.text('Trợ lý Số Hóa Vợt & Đặt Lịch Đan Cước Cầu Lông'),
        findsOneWidget,
      );
      expect(find.text('Đăng Nhập'), findsOneWidget);
      expect(find.text('Đăng Ký Mới'), findsOneWidget);
      expect(find.text('Đăng Nhập Ngay'), findsOneWidget);

      // 4. Chuyển sang tab Đăng Ký Mới và kiểm tra hiển thị chọn Vai trò (Người chơi / Chủ Shop)
      await tester.tap(find.text('Đăng Ký Mới'));
      await tester.pumpAndSettle();
      expect(find.text('Tạo Tài Khoản Mới'), findsOneWidget);
      expect(find.text('Người chơi'), findsOneWidget);
      expect(find.text('Chủ Shop'), findsOneWidget);
    },
  );
}
