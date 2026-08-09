import 'dart:convert';
import 'dart:typed_data';

class ChatContentUtils {
  const ChatContentUtils._();

  static String renderPlainText(String? content) {
    if (content == null || content.isEmpty) return '';

    return content
        .replaceAllMapped(
          RegExp(r'@\[(.*?)\]\(([^)]+)\)'),
          (match) => '@${match.group(1) ?? ''}',
        )
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }

  static String encodeFileContent(String name) {
    final bytes = utf8.encode(name);
    return 'b64:${base64Encode(bytes)}';
  }

  static String decodeFileContent(String? content) {
    if (content == null || content.isEmpty) return '';
    if (!content.startsWith('b64:')) return content;
    try {
      final Uint8List bytes = base64Decode(content.substring(4));
      return utf8.decode(bytes);
    } catch (_) {
      return content;
    }
  }
}
