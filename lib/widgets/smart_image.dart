import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'shimmer_card.dart';

/// Displays images from either a base64 data URL or a regular https URL.
class SmartImage extends StatelessWidget {
  static const int _maxCachedDataImages = 16;
  static final Map<String, Uint8List> _decodedDataImages = {};

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

  static bool isDataUrl(String? url) => url != null && url.startsWith('data:');

  static String _dataCacheKey(String dataUrl) =>
      '${dataUrl.length}:${dataUrl.hashCode}';

  @override
  Widget build(BuildContext context) {
    final src = url;

    if (src == null || src.isEmpty) {
      return _fallback();
    }

    if (isDataUrl(src)) {
      return _buildBase64(context, src);
    }

    return CachedNetworkImage(
      imageUrl: src,
      fit: fit,
      width: width,
      height: height,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      useOldImageOnUrlChange: true,
      placeholder: (_, __) => placeholder ?? const ShimmerCard(borderRadius: 0),
      errorWidget: (_, __, ___) => errorWidget ?? _fallback(),
    );
  }

  Widget _buildBase64(BuildContext context, String dataUrl) {
    try {
      final comma = dataUrl.indexOf(',');
      if (comma == -1) return _fallback();
      final key = _dataCacheKey(dataUrl);
      final bytes = _decodedDataImages[key] ??= base64Decode(
        dataUrl.substring(comma + 1),
      );

      if (_decodedDataImages.length > _maxCachedDataImages) {
        _decodedDataImages.remove(_decodedDataImages.keys.first);
      }

      final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
      final cacheWidth = width != null && width!.isFinite
          ? (width! * devicePixelRatio).round()
          : null;
      final cacheHeight = height != null && height!.isFinite
          ? (height! * devicePixelRatio).round()
          : null;

      return Image.memory(
        bytes,
        fit: fit,
        width: width,
        height: height,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
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
