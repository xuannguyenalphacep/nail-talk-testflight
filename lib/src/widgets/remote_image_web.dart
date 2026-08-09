// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

class RemoteImage extends StatefulWidget {
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

  @override
  State<RemoteImage> createState() => _RemoteImageState();
}

class _RemoteImageState extends State<RemoteImage> {
  static int _seed = 0;

  late final String _viewType;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'remote-image-${_seed++}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final img = html.ImageElement()
        ..src = widget.url
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.display = 'block'
        ..style.objectFit = _cssObjectFit(widget.fit)
        ..style.pointerEvents = 'none'
        ..draggable = false;

      img.onError.first.then((_) {
        if (!mounted) return;
        setState(() => _hasError = true);
      });

      return img;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return widget.errorFallback ?? const SizedBox.shrink();
    }

    Widget child = LayoutBuilder(
      builder: (context, constraints) {
        double? width = widget.width;
        double? height = widget.height;

        if ((width == null || !width.isFinite) && constraints.hasBoundedWidth) {
          width = constraints.maxWidth;
        }
        if ((height == null || !height.isFinite) &&
            constraints.hasBoundedHeight) {
          height = constraints.maxHeight;
        }

        if ((width == null || width <= 0) && (height == null || height <= 0)) {
          width = 1;
          height = 1;
        }

        return SizedBox(
          width: width,
          height: height,
          child: HtmlElementView(viewType: _viewType),
        );
      },
    );

    if (widget.borderRadius != null) {
      child = ClipRRect(borderRadius: widget.borderRadius!, child: child);
    }

    return child;
  }

  String _cssObjectFit(BoxFit fit) {
    switch (fit) {
      case BoxFit.contain:
        return 'contain';
      case BoxFit.cover:
        return 'cover';
      case BoxFit.fill:
        return 'fill';
      case BoxFit.fitWidth:
      case BoxFit.fitHeight:
      case BoxFit.scaleDown:
        return 'scale-down';
      case BoxFit.none:
        return 'none';
    }
  }
}
