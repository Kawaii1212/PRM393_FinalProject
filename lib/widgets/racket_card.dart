import 'package:flutter/material.dart';
import '../models/racket_model.dart';
import '../theme/app_theme.dart';
import 'tension_badge.dart';

class RacketCard extends StatelessWidget {
  final Racket racket;
  final VoidCallback onTap;

  const RacketCard({
    super.key,
    required this.racket,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color brandColor;
    switch (racket.brand.toLowerCase()) {
      case 'yonex':
        brandColor = const Color(0xFF00B0FF);
        break;
      case 'victor':
        brandColor = const Color(0xFF304FFE);
        break;
      case 'li-ning':
        brandColor = const Color(0xFFFF5252);
        break;
      default:
        brandColor = AppTheme.primary;
    }

    final tensionProgress = (1.0 - (racket.tensionLossPercent / 100.0)).clamp(0.0, 1.0);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: racket.needsRestring ? AppTheme.danger.withOpacity(0.5) : AppTheme.border,
            width: racket.needsRestring ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Brand Badge + Tension Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: brandColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: brandColor.withOpacity(0.4)),
                    ),
                    child: Text(
                      racket.brand.toUpperCase(),
                      style: TextStyle(
                        color: brandColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  TensionBadge(
                    currentTension: racket.estimatedCurrentTension,
                    initialTension: racket.initialTensionLbs,
                    lossPercent: racket.tensionLossPercent,
                    needsRestring: racket.needsRestring,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Racket Name & Edition
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.sports_tennis_rounded, color: AppTheme.primary, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          racket.modelName,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          '${racket.editionGen} • ${racket.colorway}',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Specs Row Chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _specChip(racket.weightU),
                  _specChip(racket.gripG),
                  _specChip('${racket.balancePointMm}mm (${racket.balancePointMm > 295 ? "Nặng đầu" : "Cân bằng"})'),
                  _specChip('Max: ${racket.maxTensionLbs.toInt()} lbs'),
                ],
              ),
              const SizedBox(height: 14),

              // String tension status bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Cước: ${racket.currentStringModel} (${racket.initialTensionLbs} lbs)',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                      Text(
                        racket.daysSinceStrung > 0
                            ? '${racket.daysSinceStrung} ngày trước'
                            : 'Mới đan',
                        style: TextStyle(
                          color: racket.needsRestring ? AppTheme.danger : AppTheme.textMuted,
                          fontSize: 11,
                          fontWeight: racket.needsRestring ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: tensionProgress,
                      backgroundColor: AppTheme.surfaceLight,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        racket.needsRestring
                            ? AppTheme.danger
                            : (racket.tensionLossPercent > 12.0 ? AppTheme.accent : AppTheme.primary),
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),

              // Warning alert if needed
              if (racket.needsRestring) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cước đã chùng hơn 20%, nên đan lại để tránh đau tay!',
                          style: TextStyle(
                            color: AppTheme.danger,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _specChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.border.withOpacity(0.6)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
