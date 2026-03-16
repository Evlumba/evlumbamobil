import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'shimmer_card.dart';

/// Displays images from either a base64 data URL or a regular https URL.
class SmartImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;

  const SmartImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
  });

  static bool isDataUrl(String? url) =>
      url != null && url.startsWith('data:');

  @override
  Widget build(BuildContext context) {
    final src = url;

    if (src == null || src.isEmpty) {
      return _fallback();
    }

    if (isDataUrl(src)) {
      return _buildBase64(src);
    }

    return CachedNetworkImage(
      imageUrl: src,
      fit: fit,
      width: width,
      height: height,
      placeholder: (_, __) => placeholder ?? const ShimmerCard(borderRadius: 0),
      errorWidget: (_, __, ___) => errorWidget ?? _fallback(),
    );
  }

  Widget _buildBase64(String dataUrl) {
    try {
      final comma = dataUrl.indexOf(',');
      if (comma == -1) return _fallback();
      final bytes = base64Decode(dataUrl.substring(comma + 1));
      return Image.memory(
        bytes,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    } catch (_) {
      return _fallback();
    }
  }

  Widget _fallback() {
    return errorWidget ??
        Container(
          width: width,
          height: height,
          color: AppColors.border,
          child: const Center(
            child: Icon(
              Icons.image_not_supported_outlined,
              color: AppColors.textSecondary,
            ),
          ),
        );
  }
}
