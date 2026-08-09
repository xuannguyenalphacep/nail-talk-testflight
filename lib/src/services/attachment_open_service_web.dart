import 'package:url_launcher/url_launcher.dart';

Future<void> openAttachmentExternally({
  required String url,
  required String fileName,
}) async {
  final uri = Uri.parse(url);
  final launched = await launchUrl(uri, webOnlyWindowName: '_blank');
  if (!launched) {
    throw Exception('Failed to open attachment');
  }
}
