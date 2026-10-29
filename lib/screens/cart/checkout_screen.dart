import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/shop_provider.dart';
import '../../models/notification_model.dart';
import '../../models/order_model.dart';
import '../../theme/app_theme.dart';
import '../main_navigation_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  int _deliveryMethod = 0; // 0: Mang đến shop, 1: Giao nhận tận nơi
  int _paymentMethod = 0; // 0: Chuyển khoản VietQR, 1: Ví MoMo, 2: Tiền mặt khi lấy vợt
  String _selectedTimeSlot = '14:00 - 16:00 Hôm nay';

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  final _addressController = TextEditingController();
  final _noteController = TextEditingController();

  final List<String> _timeSlots = [
    '09:00 - 11:00 Hôm nay',
    '14:00 - 16:00 Hôm nay',
    '17:00 - 19:00 Hôm nay',
    '09:00 - 11:00 Ngày mai',
  ];

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    _nameController = TextEditingController(text: user?.fullName ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _confirmOrder(BuildContext context) {
    final cart = context.read<CartProvider>();
    final orderTotal = cart.totalAmount;
    final orderId = 'GS-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final authUser = context.read<AuthProvider>().currentUser;

    // Xác định Shop tiếp nhận đơn từ các món hàng trong giỏ
    String targetShopId = '';
    String targetShopName = 'Cửa hàng cầu lông';
    for (final item in cart.items) {
      if (item.product.shopId.isNotEmpty && item.product.shopId != 'all') {
        targetShopId = item.product.shopId;
        final name = item.product.shopName;
        if (name != null && name.isNotEmpty) {
          targetShopName = name;
        }
        break;
      }
    }
    if (targetShopId.isEmpty) {
      final shops = context.read<ShopProvider>().shops;
      if (shops.isNotEmpty) {
        targetShopId = shops.first.id;
        targetShopName = shops.first.name;
      }
    }

    final orderItems = cart.items.map((ci) => OrderItem(
      productId: ci.product.id,
      productName: ci.product.name,
      price: ci.product.price,
      quantity: ci.quantity,
      isService: ci.product.isService,
      targetRacketName: ci.targetRacket != null
          ? '${ci.targetRacket!.brand} ${ci.targetRacket!.modelName}'
          : null,
      requestedTensionLbs: ci.requestedTensionLbs,
      stringingTechnique: ci.stringingTechnique,
      selectedColor: ci.selectedColor,
      specialNotes: ci.specialNotes,
    )).toList();

    final deliveryLabel = _deliveryMethod == 0 ? 'Mang đến shop' : 'Giao nhận tận nơi';
    final paymentLabel = _paymentMethod == 0
        ? 'Chuyển khoản VietQR'
        : (_paymentMethod == 1 ? 'Ví MoMo' : 'Tiền mặt khi lấy vợt');

    final newOrder = OrderModel(
      id: orderId,
      shopId: targetShopId,
      shopName: targetShopName,
      customerId: authUser?.uid ?? 'guest',
      customerName: _nameController.text.trim().isEmpty
          ? (authUser?.fullName ?? 'Khách hàng')
          : _nameController.text.trim(),
      customerPhone: _phoneController.text.trim().isEmpty
          ? (authUser?.phone ?? '')
          : _phoneController.text.trim(),
      deliveryMethod: deliveryLabel,
      paymentMethod: paymentLabel,
      timeSlot: _selectedTimeSlot,
      deliveryAddress: _addressController.text.trim(),
      note: _noteController.text.trim(),
      totalAmount: orderTotal,
      status: OrderStatus.pending,
      createdAt: DateTime.now(),
      items: orderItems,
    );

    // 1. Lưu Order vào OrderProvider (Cloud Firestore & Cache)
    context.read<OrderProvider>().createOrder(newOrder);

    // 2. Tạo Notification cập nhật trạng thái đơn (FR-06 & Luồng Sơ Đồ)
    context.read<NotificationProvider>().addNotification(
      title: '🏸 Đặt lịch đan cước thành công! (#$orderId)',
      message: 'Đơn đặt lịch của bạn tại $targetShopName đã được ghi nhận với tổng tiền ${_currencyFormat.format(orderTotal)}. Khung giờ hẹn: $_selectedTimeSlot.',
      type: NotificationType.orderStatus,
      targetOrderId: orderId,
    );

    // 3. Clear Cart
    cart.clearCart();

    // 4. Hiển thị Dialog chúc mừng
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 44),
              ),
              const SizedBox(height: 16),
              const Text(
                'Đặt Lịch Thành Công!',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Mã đơn hàng: #$orderId\nTiệm: $targetShopName\nThời gian hẹn: $_selectedTimeSlot\nTổng thanh toán: ${_currencyFormat.format(orderTotal)}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Thông báo xác nhận đã được gửi vào mục Notifications của bạn.',
                  style: TextStyle(color: AppTheme.primaryDark, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MainNavigationScreen(initialIndex: 4), // Notifications tab
                      ),
                      (route) => false,
                    );
                  },
                  child: const Text('Xem Thông Báo Đơn Hàng'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Xác Nhận Đặt Lịch & Thanh Toán'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Phương thức bàn giao vợt
            _sectionTitle('1. Hình Thức Mang Vợt Đến Shop'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _selectionCard(
                    icon: Icons.directions_walk_rounded,
                    title: 'Tự Mang Đến',
                    subtitle: 'Lấy ngay trong 20p',
                    isSelected: _deliveryMethod == 0,
                    onTap: () => setState(() => _deliveryMethod = 0),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _selectionCard(
                    icon: Icons.delivery_dining_rounded,
                    title: 'Giao Nhận Tận Nơi',
                    subtitle: 'Shipper đến lấy',
                    isSelected: _deliveryMethod == 1,
                    onTap: () => setState(() => _deliveryMethod = 1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Section 2: Khung giờ hẹn
            _sectionTitle('2. Chọn Khung Giờ Hẹn Đan Vợt'),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedTimeSlot,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.schedule_rounded, color: AppTheme.primary),
              ),
              items: _timeSlots.map((slot) => DropdownMenuItem(value: slot, child: Text(slot))).toList(),
              onChanged: (v) => setState(() => _selectedTimeSlot = v!),
            ),
            const SizedBox(height: 20),

            // Section 3: Thông tin người đặt
            _sectionTitle('3. Thông Tin Liên Hệ'),
            const SizedBox(height: 10),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Tên người chơi',
                prefixIcon: Icon(Icons.person_outline_rounded, color: AppTheme.primary),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Số điện thoại liên lạc',
                prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.primary),
              ),
            ),
            if (_deliveryMethod == 1) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Địa chỉ nhận/trả vợt',
                  prefixIcon: Icon(Icons.location_on_outlined, color: AppTheme.primary),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Ghi chú thêm cho kỹ thuật viên',
                hintText: 'Ví dụ: Kéo cước cẩn thận, thay giúp 2 gen góc 12h',
                prefixIcon: Icon(Icons.note_alt_outlined, color: AppTheme.primary),
              ),
            ),
            const SizedBox(height: 20),

            // Section 4: Phương thức thanh toán
            _sectionTitle('4. Phương Thức Thanh Toán'),
            const SizedBox(height: 10),
            _paymentOption(
              index: 0,
              icon: Icons.qr_code_scanner_rounded,
              title: 'Chuyển Khoản Ngân Hàng (VietQR)',
              subtitle: 'Quét mã QR thanh toán nhanh không cần nhập số tài khoản',
            ),
            const SizedBox(height: 10),
            _paymentOption(
              index: 1,
              icon: Icons.account_balance_wallet_rounded,
              title: 'Ví Điện Tử MoMo / ZaloPay',
              subtitle: 'Thanh toán tức thì qua ví điện tử',
            ),
            const SizedBox(height: 10),
            _paymentOption(
              index: 2,
              icon: Icons.money_rounded,
              title: 'Tiền Mặt Khi Nhận Vợt',
              subtitle: 'Thanh toán sau khi kiểm tra xong độ căng mặt vợt',
            ),
            const SizedBox(height: 24),

            // Order Total
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tổng Thanh Toán:',
                    style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    _currencyFormat.format(cart.totalAmount),
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _confirmOrder(context),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Xác Nhận Đặt Lịch & Thanh Toán',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.primaryDark,
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _selectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withOpacity(0.12) : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppTheme.primary : AppTheme.textMuted, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentOption({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _paymentMethod == index;
    return InkWell(
      onTap: () => setState(() => _paymentMethod = index),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withOpacity(0.12) : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppTheme.primary : AppTheme.primaryDark, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                ],
              ),
            ),
            Radio<int>(
              value: index,
              groupValue: _paymentMethod,
              activeColor: AppTheme.primary,
              onChanged: (v) => setState(() => _paymentMethod = v!),
            ),
          ],
        ),
      ),
    );
  }
}
