import 'package:flutter/material.dart';

class RemoteImage extends StatelessWidget {
  const RemoteImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.errorFallback,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Widget? errorFallback;

  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Android) AppleWebKit/537.36 Mobile Safari/537.36',
    'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
  };

  @override
  Widget build(BuildContext context) {
    final image = Image.network(
      url,
      headers: _headers,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (context, error, stackTrace) =>
          errorFallback ?? const SizedBox.shrink(),
    );

    if (borderRadius == null) return image;

    return ClipRRect(borderRadius: borderRadius!, child: image);
  }
}
