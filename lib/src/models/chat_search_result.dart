import '../core/utils/app_date_utils.dart';

class ChatSearchResult {
  ChatSearchResult({
    required this.id,
    required this.senderName,
    required this.createdAt,
    required this.snippet,
  });

  final int id;
  final String senderName;
  final DateTime? createdAt;
  final String snippet;

  factory ChatSearchResult.fromJson(Map<String, dynamic> json) {
    return ChatSearchResult(
      id: (json['id'] as num?)?.toInt() ?? 0,
      senderName: (json['sender_name'] ?? '').toString(),
      createdAt: AppDateUtils.tryParse(json['created_at']),
      snippet: (json['snippet'] ?? '').toString(),
    );
  }
}
