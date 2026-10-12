// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
    this.headers = const <String, String>{},
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Widget? errorFallback;
  final Map<String, String> headers;

  @override
  State<RemoteImage> createState() => _RemoteImageState();
}

class _RemoteImageState extends State<RemoteImage> {
  static int _seed = 0;

  late final String _viewType;
  late final html.ImageElement _imageElement;
  bool _hasError = false;
  String? _objectUrl;
  int _loadEpoch = 0;

  @override
  void initState() {
    super.initState();
    _viewType = 'remote-image-${_seed++}';
    _imageElement = html.ImageElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.display = 'block'
      ..style.objectFit = _cssObjectFit(widget.fit)
      ..style.pointerEvents = 'none'
      ..draggable = false;

    _imageElement.onError.listen((_) {
      if (!mounted) return;
      setState(() => _hasError = true);
    });

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      return _imageElement;
    });
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant RemoteImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        !mapEquals(oldWidget.headers, widget.headers)) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    final epoch = ++_loadEpoch;
    if (mounted && _hasError) {
      setState(() => _hasError = false);
    }

    if (widget.headers.isEmpty) {
      _replaceImageSource(widget.url);
      return;
    }

    // Never keep private bytes from a previous token/url visible while the
    // replacement request is in flight (for example, during account switch).
    _replaceImageSource('');
    try {
      final response = await Dio().get<List<int>>(
        widget.url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: widget.headers,
          followRedirects: true,
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
        ),
      );
      if (!mounted || epoch != _loadEpoch) return;
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw StateError('Empty image response');
      }
      final blob = html.Blob(<Object>[Uint8List.fromList(bytes)]);
      _replaceImageSource(html.Url.createObjectUrlFromBlob(blob));
      if (_hasError) setState(() => _hasError = false);
    } catch (_) {
      if (!mounted || epoch != _loadEpoch) return;
      setState(() => _hasError = true);
    }
  }

  void _replaceImageSource(String source) {
    final previousObjectUrl = _objectUrl;
    _objectUrl = source.startsWith('blob:') ? source : null;
    if (source.isEmpty) {
      _imageElement.attributes.remove('src');
    } else {
      _imageElement.src = source;
    }
    if (previousObjectUrl != null && previousObjectUrl != _objectUrl) {
      html.Url.revokeObjectUrl(previousObjectUrl);
    }
  }

  @override
  void dispose() {
    _loadEpoch++;
    final objectUrl = _objectUrl;
    if (objectUrl != null) html.Url.revokeObjectUrl(objectUrl);
    super.dispose();
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
