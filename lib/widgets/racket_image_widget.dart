import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RacketImageWidget extends StatelessWidget {
  final String? imageUrl;
  final String brand;
  final double width;
  final double height;
  final double borderRadius;

  const RacketImageWidget({
    super.key,
    required this.imageUrl,
    required this.brand,
    this.width = double.infinity,
    this.height = 140,
    this.borderRadius = 12,
  });

  Color _getBrandColor() {
    switch (brand.toLowerCase()) {
      case 'yonex':
        return const Color(0xFF00B0FF);
      case 'victor':
        return const Color(0xFF304FFE);
      case 'li-ning':
        return const Color(0xFFFF5252);
      default:
        return AppTheme.primary;
    }
  }

  Uint8List? _tryDecodeBase64(String raw) {
    try {
      String clean = raw.trim();
      if (clean.contains(',')) {
        clean = clean.split(',').last;
      }
      return base64Decode(clean);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final brandColor = _getBrandColor();
    final url = imageUrl?.trim() ?? '';

    Widget content;

    if (url.isEmpty) {
      content = _buildPlaceholder(brandColor);
    } else if (url.startsWith('data:image') || !url.startsWith('http')) {
      final bytes = _tryDecodeBase64(url);
      if (bytes != null && bytes.isNotEmpty) {
        content = Image.memory(
          bytes,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildPlaceholder(brandColor),
        );
      } else {
        content = _buildPlaceholder(brandColor);
      }
    } else {
      content = Image.network(
        url,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildPlaceholder(brandColor),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: width,
            height: height,
            color: AppTheme.surfaceLight,
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primary,
                ),
              ),
            ),
          );
        },
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: content,
      ),
    );
  }

  Widget _buildPlaceholder(Color brandColor) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.surfaceLight,
            brandColor.withOpacity(0.18),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            right: -12,
            bottom: -12,
            child: Icon(
              Icons.sports_tennis_rounded,
              size: height * 0.85,
              color: brandColor.withOpacity(0.12),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: brandColor.withOpacity(0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: brandColor.withOpacity(0.4)),
                ),
                child: Icon(
                  Icons.sports_tennis_rounded,
                  color: brandColor,
                  size: 28,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Chưa có ảnh vợt • Bấm Sửa để tải ảnh lên',
                style: TextStyle(
                  color: AppTheme.textSecondary.withOpacity(0.85),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
