import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

Future<void> openAttachmentExternally({
  required String url,
  required String fileName,
}) async {
  final directory = await getTemporaryDirectory();
  final sanitized = _sanitizeFileName(fileName);
  final target = File('${directory.path}/$sanitized');

  final dio = Dio();
  await dio.download(
    url,
    target.path,
    options: Options(
      responseType: ResponseType.bytes,
      followRedirects: true,
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
    ),
  );

  final result = await OpenFilex.open(target.path);
  if (result.type != ResultType.done) {
    throw Exception(result.message);
  }
}

String _sanitizeFileName(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'attachment';
  return trimmed.replaceAll(RegExp(r'[\\\\/:*?"<>|]'), '_');
}
