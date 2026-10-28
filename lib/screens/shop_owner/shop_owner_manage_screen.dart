import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/shop_model.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shop_provider.dart';
import '../../theme/app_theme.dart';

class ShopOwnerManageScreen extends StatefulWidget {
  const ShopOwnerManageScreen({super.key});

  @override
  State<ShopOwnerManageScreen> createState() => _ShopOwnerManageScreenState();
}

class _ShopOwnerManageScreenState extends State<ShopOwnerManageScreen> {
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  void _showAddEditItemModal(
    BuildContext context,
    Shop shop, {
    Product? existing,
  }) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(
      text: existing != null ? existing.price.toInt().toString() : '',
    );
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    ProductCategory selectedCat = existing?.category ?? ProductCategory.service;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        existing != null
                            ? 'Chỉnh Sửa Vật Phẩm / Dịch Vụ'
                            : 'Đăng Bán Vật Phẩm / Dịch Vụ Mới',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Cửa hàng: ${shop.name}',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<ProductCategory>(
                        value: selectedCat,
                        decoration: const InputDecoration(
                          labelText: 'Phân loại đăng bán',
                          prefixIcon: Icon(
                            Icons.category_outlined,
                            color: AppTheme.primary,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: ProductCategory.service,
                            child: Text('Dịch vụ đan vợt'),
                          ),
                          DropdownMenuItem(
                            value: ProductCategory.racket,
                            child: Text('Vợt cầu lông đăng bán'),
                          ),
                          DropdownMenuItem(
                            value: ProductCategory.string,
                            child: Text('Cước cầu lông'),
                          ),
                          DropdownMenuItem(
                            value: ProductCategory.grip,
                            child: Text('Quấn cán vợt'),
                          ),
                          DropdownMenuItem(
                            value: ProductCategory.accessory,
                            child: Text('Phụ kiện khác (Gen, bao vợt...)'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setSheetState(() => selectedCat = v);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Tên vật phẩm / dịch vụ *',
                          hintText:
                              'VD: Công đan 4 nút, Vợt Astrox 88D Pro, Cước BG66...',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Vui lòng nhập tên vật phẩm / dịch vụ'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Giá niêm yết (VNĐ) *',
                          suffixText: 'đ',
                        ),
                        validator: (v) {
                          final val = double.tryParse(v?.trim() ?? '');
                          if (val == null || val < 0) {
                            return 'Vui lòng nhập giá hợp lệ';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Mô tả thông số / chi tiết',
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final item = Product(
                              id: existing?.id ??
                                  'prod_${DateTime.now().millisecondsSinceEpoch}',
                              shopId: shop.id,
                              shopName: shop.name,
                              name: nameCtrl.text.trim(),
                              category: selectedCat,
                              price: double.parse(priceCtrl.text.trim()),
                              description: descCtrl.text.trim().isEmpty
                                  ? 'Đăng bán chính hãng tại ${shop.name}'
                                  : descCtrl.text.trim(),
                              imageUrl: existing?.imageUrl ?? '',
                              isService: selectedCat == ProductCategory.service,
                              status: existing?.status ?? 'pending',
                            );
                            Navigator.pop(ctx);
                            await context
                                .read<ShopProvider>()
                                .upsertProduct(item);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Đã lưu "${item.name}" lên Cloud Firestore!',
                                  ),
                                  backgroundColor: AppTheme.primaryDark,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.cloud_upload_outlined),
                          label: const Text('Lưu Lên Cửa Hàng'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final shopProv = context.watch<ShopProvider>();
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final myShop = shopProv.getShopForOwner(user.uid);
    final myItems = myShop != null
        ? shopProv.getDirectProductsForShop(myShop.id)
        : <Product>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản Lý Cửa Hàng Của Tôi'),
      ),
      floatingActionButton: myShop == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showAddEditItemModal(context, myShop),
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: const Text(
                'Thêm Dịch Vụ / Vật Phẩm',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
      body: myShop == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Chưa tìm thấy hồ sơ cửa hàng gắn với tài khoản này.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMuted),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              children: [
                // Thông tin trạng thái Shop
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppTheme.cardGradient,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: myShop.isApproved
                          ? AppTheme.primary
                          : (myShop.isPending
                              ? AppTheme.accent
                              : AppTheme.danger),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.storefront_rounded,
                            color: AppTheme.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              myShop.name,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: (myShop.isApproved
                                      ? AppTheme.primary
                                      : (myShop.isPending
                                          ? AppTheme.accent
                                          : AppTheme.danger))
                                  .withOpacity(0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              myShop.statusDisplayName,
                              style: TextStyle(
                                color: myShop.isApproved
                                    ? AppTheme.primary
                                    : (myShop.isPending
                                        ? AppTheme.accent
                                        : AppTheme.danger),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '📍 ${myShop.address}, ${myShop.district}, ${myShop.city}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '⚙️ Máy đan: ${myShop.machineModel}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '🏅 Chứng chỉ: ${myShop.stringerCert} • 🕒 ${myShop.openHours}',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Dịch Vụ & Vật Phẩm Đăng Bán (${myItems.length})',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                if (myItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'Cửa hàng chưa có dịch vụ hay vật phẩm nào.\nNhấn "Thêm Dịch Vụ / Vật Phẩm" bên dưới để đăng bán!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    ),
                  )
                else
                  for (final item in myItems)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.name,
                                        style: const TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: (item.isApproved
                                                ? AppTheme.primary
                                                : (item.isPending
                                                    ? AppTheme.accent
                                                    : AppTheme.danger))
                                            .withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        item.statusDisplayName,
                                        style: TextStyle(
                                          color: item.isApproved
                                              ? AppTheme.primary
                                              : (item.isPending
                                                  ? AppTheme.accent
                                                  : AppTheme.danger),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${item.categoryName} • ${_currencyFormat.format(item.price)}',
                                  style: const TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                  ),
                                ),
                                Text(
                                  item.description,
                                  style: const TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.edit_outlined,
                              color: AppTheme.primary,
                              size: 18,
                            ),
                            onPressed: () => _showAddEditItemModal(
                              context,
                              myShop,
                              existing: item,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppTheme.danger,
                              size: 18,
                            ),
                            onPressed: () => shopProv.deleteProduct(item.id),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
    );
  }
}
