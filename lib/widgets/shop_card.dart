import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/shop_model.dart';
import '../theme/app_theme.dart';

class ShopCard extends StatelessWidget {
  final Shop shop;
  final VoidCallback onTap;
  final VoidCallback onChatTap;

  const ShopCard({
    super.key,
    required this.shop,
    required this.onTap,
    required this.onChatTap,
  });

  Future<void> _openGoogleMaps(BuildContext context) async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${shop.latitude},${shop.longitude}',
    );
    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tọa độ ${shop.name}: ${shop.latitude}, ${shop.longitude}'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tọa độ ${shop.name}: ${shop.latitude}, ${shop.longitude}'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPartner = shop.isVerifiedPartner;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPartner ? AppTheme.primary.withOpacity(0.5) : AppTheme.border,
          width: isPartner ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Shop Avatar/Icon
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isPartner
                        ? AppTheme.primary.withOpacity(0.15)
                        : AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isPartner ? AppTheme.primary : AppTheme.border,
                      width: 1.2,
                    ),
                  ),
                  child: Icon(
                    isPartner ? Icons.storefront_rounded : Icons.map_rounded,
                    color: isPartner ? AppTheme.primary : AppTheme.textSecondary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),

                // Name & address
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    shop.name,
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (isPartner)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      '✓ Đối tác App',
                                      style: TextStyle(
                                        color: AppTheme.primaryDark,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceLight,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppTheme.border),
                                    ),
                                    child: const Text(
                                      '📍 Google Maps',
                                      style: TextStyle(
                                        color: AppTheme.textMuted,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star_rounded, color: AppTheme.accent, size: 14),
                                const SizedBox(width: 3),
                                Text(
                                  '${shop.rating}',
                                  style: const TextStyle(
                                    color: AppTheme.accent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        shop.address,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // Distance and hours
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, color: AppTheme.primaryDark, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            'Cách bạn ${shop.distanceKm} km',
                            style: const TextStyle(
                              color: AppTheme.primaryDark,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.access_time_rounded, color: AppTheme.textMuted, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            shop.openHours.split('(').first.trim(),
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Machine and stringer certificate
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: AppTheme.surfaceLight.withOpacity(0.5),
            child: Row(
              children: [
                Icon(
                  isPartner ? Icons.precision_manufacturing_rounded : Icons.info_outline_rounded,
                  color: isPartner ? AppTheme.primary : AppTheme.textMuted,
                  size: 15,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isPartner
                        ? '${shop.machineModel} • ${shop.stringerCert}'
                        : 'Điểm tham khảo từ Google Maps • Chưa có gian hàng trên App',
                    style: TextStyle(
                      color: isPartner ? AppTheme.textSecondary : AppTheme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      fontStyle: isPartner ? FontStyle.normal : FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Action buttons: Phân biệt rõ shop có sẵn và shop đối tác
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: isPartner
                ? Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onTap,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Xem Dịch Vụ & Trưng Bày',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Nhắn tin tư vấn',
                        onPressed: onChatTap,
                        icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.primaryDark),
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.surfaceLight,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: AppTheme.border),
                          ),
                        ),
                      ),
                    ],
                  )
                : SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _openGoogleMaps(context),
                      icon: const Icon(Icons.directions_rounded, size: 18),
                      label: const Text(
                        'Chỉ Đường Qua Google Maps 🗺️',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(color: AppTheme.primary, width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
