import 'package:flutter/material.dart';

import '../widgets/remote_image.dart';

class AttachmentPreviewScreen extends StatelessWidget {
  const AttachmentPreviewScreen({
    super.key,
    required this.url,
    required this.title,
    required this.isImage,
  });

  final String url;
  final String title;
  final bool isImage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FD),
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: RemoteImage(
                  url: url,
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  fit: BoxFit.contain,
                  errorFallback: const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Unable to display the image.',
                      style: TextStyle(
                        color: Color(0xFF6A7C97),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
