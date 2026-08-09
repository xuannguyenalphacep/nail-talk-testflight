import '../core/utils/app_date_utils.dart';

class ChatNotificationItem {
  ChatNotificationItem({
    required this.id,
    required this.content,
    required this.linkTo,
    required this.isRead,
    required this.createdAt,
  });

  final int id;
  final String content;
  final String linkTo;
  final bool isRead;
  final DateTime? createdAt;

  int? get roomId {
    final uri = Uri.tryParse(linkTo);
    final value = uri?.queryParameters['room_id'];
    if (value == null || value.isEmpty) return null;
    return int.tryParse(value);
  }

  factory ChatNotificationItem.fromJson(Map<String, dynamic> json) {
    return ChatNotificationItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      content: (json['content'] ?? '').toString(),
      linkTo: (json['link_to'] ?? '').toString(),
      isRead: json['is_read'] == true || json['is_read'] == 1,
      createdAt: AppDateUtils.tryParse(json['created_at']),
    );
  }
}
