// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openAttachmentExternally({
  required String url,
  required String fileName,
  Map<String, String> headers = const <String, String>{},
}) async {
  if (headers.isEmpty) {
    final launched = await launchUrl(
      Uri.parse(url),
      webOnlyWindowName: '_blank',
    );
    if (!launched) throw Exception('Failed to open attachment');
    return;
  }

  final response = await Dio().get<List<int>>(
    url,
    options: Options(
      responseType: ResponseType.bytes,
      headers: headers,
      followRedirects: true,
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
    ),
  );
  final bytes = response.data;
  if (bytes == null || bytes.isEmpty) {
    throw StateError('Empty attachment response');
  }

  final contentType = response.headers.value(Headers.contentTypeHeader);
  final blob = html.Blob(<Object>[Uint8List.fromList(bytes)], contentType);
  final objectUrl = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: objectUrl)
    ..download = _sanitizeFileName(fileName)
    ..target = '_blank'
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  unawaited(
    Future<void>.delayed(
      const Duration(seconds: 30),
      () => html.Url.revokeObjectUrl(objectUrl),
    ),
  );
}

String _sanitizeFileName(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'attachment';
  return trimmed.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
}
