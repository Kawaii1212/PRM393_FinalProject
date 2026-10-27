import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/racket_model.dart';
import '../../providers/racket_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/racket_card.dart';
import 'gear_detail_screen.dart';
import 'add_edit_racket_screen.dart';

class GearListScreen extends StatelessWidget {
  const GearListScreen({super.key});

  void _confirmDeleteRacket(BuildContext context, Racket racket) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: AppTheme.danger),
            SizedBox(width: 8),
            Text(
              'Xóa vợt khỏi Gara?',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa cây vợt "${racket.brand} ${racket.modelName}" khỏi Gara không? Toàn bộ lịch sử đan cước của cây vợt này cũng sẽ bị xóa.',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Hủy',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<RacketProvider>().deleteRacket(racket.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Đã xóa vợt ${racket.brand} ${racket.modelName} khỏi Gara!',
                    ),
                    backgroundColor: AppTheme.danger,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Xóa Vợt'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final racketProvider = context.watch<RacketProvider>();
    final rackets = racketProvider.rackets;
    final needingRestringCount = racketProvider.racketsNeedingRestring.length;

    final brands = [
      'Tất cả',
      'Yonex',
      'Victor',
      'Li-Ning',
      'Mizuno',
      'Felet',
      'Kumpoo',
      'Khác',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gara Vợt Của Tôi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primary),
            tooltip: 'Thêm vợt mới',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddEditRacketScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick Stats Banner
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tổng số vợt', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                        const SizedBox(height: 4),
                        Text(
                          '${racketProvider.totalRacketsCount} cây',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: needingRestringCount > 0 ? AppTheme.danger.withOpacity(0.12) : AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: needingRestringCount > 0 ? AppTheme.danger.withOpacity(0.5) : AppTheme.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Cần đan lại', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (needingRestringCount > 0)
                              const Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 18),
                            if (needingRestringCount > 0) const SizedBox(width: 4),
                            Text(
                              '$needingRestringCount cây',
                              style: TextStyle(
                                color: needingRestringCount > 0 ? AppTheme.danger : AppTheme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Brand Filter Horizontal List
          Container(
            height: 42,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: brands.length,
              itemBuilder: (context, index) {
                final brand = brands[index];
                final isSelected = racketProvider.selectedBrandFilter == brand;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(brand),
                    selected: isSelected,
                    onSelected: (_) => racketProvider.setBrandFilter(brand),
                    backgroundColor: AppTheme.surface,
                    selectedColor: AppTheme.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : AppTheme.textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    side: BorderSide(
                      color: isSelected ? AppTheme.primary : AppTheme.border,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                );
              },
            ),
          ),

          // Racket List
          Expanded(
            child: rackets.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.sports_tennis_rounded, size: 64, color: AppTheme.textMuted),
                        const SizedBox(height: 12),
                        const Text(
                          'Chưa có cây vợt nào trong danh mục này',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AddEditRacketScreen()),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Thêm Vợt Vào Gara Ngay'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                    itemCount: rackets.length,
                    itemBuilder: (context, index) {
                      final racket = rackets[index];
                      return RacketCard(
                        racket: racket,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GearDetailScreen(racketId: racket.id),
                            ),
                          );
                        },
                        onDelete: () => _confirmDeleteRacket(context, racket),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEditRacketScreen()),
          );
        },
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm Vợt', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
