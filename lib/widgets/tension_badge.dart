import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TensionBadge extends StatelessWidget {
  final double currentTension;
  final double initialTension;
  final double lossPercent;
  final bool needsRestring;

  const TensionBadge({
    super.key,
    required this.currentTension,
    required this.initialTension,
    required this.lossPercent,
    required this.needsRestring,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (needsRestring) {
      statusColor = AppTheme.danger;
      statusText = 'Cần đan lại';
      statusIcon = Icons.warning_amber_rounded;
    } else if (lossPercent > 12.0) {
      statusColor = AppTheme.accent;
      statusText = 'Giảm độ nảy';
      statusIcon = Icons.access_time_filled_rounded;
    } else {
      statusColor = AppTheme.primary;
      statusText = 'Căng tối ưu';
      statusIcon = Icons.check_circle_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 14),
          const SizedBox(width: 5),
          Text(
            '$statusText ($currentTension lbs)',
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
