import 'package:flutter_test/flutter_test.dart';
import 'package:finalproject/main.dart';

void main() {
  testWidgets('Kiểm tra hiển thị màn hình khởi động & Đăng nhập Gear Sports', (WidgetTester tester) async {
    // Build app
    await tester.pumpWidget(const GearSportsApp());

    // Verify brand title and branding widgets
    expect(find.text('GEAR SPORTS'), findsOneWidget);
    expect(find.text('Trợ lý Số Hóa Vợt & Đặt Lịch Đan Cước Cầu Lông'), findsOneWidget);
    expect(find.text('Đăng Nhập'), findsOneWidget);
    expect(find.text('Đăng Ký Mới'), findsOneWidget);
    expect(find.text('Đăng Nhập Ngay'), findsOneWidget);
  });
}
