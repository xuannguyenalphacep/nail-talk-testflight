import '../core/utils/app_date_utils.dart';

class ChatMessageLike {
  ChatMessageLike({required this.userId, required this.name});

  final int userId;
  final String name;

  factory ChatMessageLike.fromJson(Map<String, dynamic> json) {
    return ChatMessageLike(
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? '').toString(),
    );
  }
}

class ChatMessageReply {
  ChatMessageReply({
    required this.id,
    required this.type,
    required this.content,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
  });

  final int id;
  final String type;
  final String content;
  final int senderId;
  final String senderName;
  final String senderAvatar;

  factory ChatMessageReply.fromJson(Map<String, dynamic> json) {
    return ChatMessageReply(
      id: (json['id'] as num?)?.toInt() ?? 0,
      type: (json['type'] ?? 'text').toString(),
      content: (json['content'] ?? '').toString(),
      senderId: (json['sender_id'] as num?)?.toInt() ?? 0,
      senderName: (json['sender_name'] ?? '').toString(),
      senderAvatar:
          (json['sender_avatar'] ??
                  json['avatar_url'] ??
                  (json['sender'] is Map<String, dynamic>
                      ? (json['sender']['avatar_url'] ??
                            json['sender']['avatar'])
                      : null) ??
                  '')
              .toString(),
    );
  }
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    required this.type,
    required this.content,
    required this.filePath,
    required this.replyToId,
    required this.replyTo,
    required this.likes,
    required this.likeCount,
    required this.likedByMe,
    required this.isPinned,
    required this.isRecalled,
    required this.isRead,
    required this.createdAt,
  });

  final int id;
  final int roomId;
  final int senderId;
  final String senderName;
  final String senderAvatar;
  final String type;
  final String content;
  final String? filePath;
  final int? replyToId;
  final ChatMessageReply? replyTo;
  final List<ChatMessageLike> likes;
  final int likeCount;
  final bool likedByMe;
  final bool isPinned;
  final bool isRecalled;
  final bool isRead;
  final DateTime? createdAt;

  bool get isImage => type == 'image';
  bool get isFile => type == 'file';
  bool get isText => type == 'text';

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      roomId: (json['room_id'] as num?)?.toInt() ?? 0,
      senderId: (json['sender_id'] as num?)?.toInt() ?? 0,
      senderName: (json['sender_name'] ?? '').toString(),
      senderAvatar:
          (json['sender_avatar'] ??
                  json['avatar_url'] ??
                  (json['sender'] is Map<String, dynamic>
                      ? (json['sender']['avatar_url'] ??
                            json['sender']['avatar'])
                      : null) ??
                  '')
              .toString(),
      type: (json['type'] ?? 'text').toString(),
      content: (json['content'] ?? '').toString(),
      filePath: json['file_path']?.toString(),
      replyToId: (json['reply_to_id'] as num?)?.toInt(),
      replyTo: json['reply_to'] is Map<String, dynamic>
          ? ChatMessageReply.fromJson(json['reply_to'] as Map<String, dynamic>)
          : null,
      likes: (json['likes'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (item) => ChatMessageLike.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      likedByMe: json['liked_by_me'] == true || json['liked_by_me'] == 1,
      isPinned: json['is_pinned'] == true || json['is_pinned'] == 1,
      isRecalled: json['is_recalled'] == true || json['is_recalled'] == 1,
      isRead: json['is_read'] == true || json['is_read'] == 1,
      createdAt: AppDateUtils.tryParse(json['created_at']),
    );
  }

  ChatMessage copyWith({
    String? content,
    String? senderAvatar,
    String? filePath,
    int? replyToId,
    ChatMessageReply? replyTo,
    List<ChatMessageLike>? likes,
    int? likeCount,
    bool? likedByMe,
    bool? isPinned,
    bool? isRecalled,
    bool? isRead,
  }) {
    return ChatMessage(
      id: id,
      roomId: roomId,
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      type: type,
      content: content ?? this.content,
      filePath: filePath ?? this.filePath,
      replyToId: replyToId ?? this.replyToId,
      replyTo: replyTo ?? this.replyTo,
      likes: likes ?? this.likes,
      likeCount: likeCount ?? this.likeCount,
      likedByMe: likedByMe ?? this.likedByMe,
      isPinned: isPinned ?? this.isPinned,
      isRecalled: isRecalled ?? this.isRecalled,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}

class ChatPinnedMessage {
  ChatPinnedMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.type,
    required this.content,
    required this.snippet,
    required this.createdAt,
    required this.pinnedAt,
    required this.pinnedBy,
    required this.pinnedByName,
  });

  final int id;
  final int senderId;
  final String senderName;
  final String type;
  final String content;
  final String snippet;
  final DateTime? createdAt;
  final DateTime? pinnedAt;
  final int? pinnedBy;
  final String pinnedByName;

  factory ChatPinnedMessage.fromJson(Map<String, dynamic> json) {
    return ChatPinnedMessage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      senderId: (json['sender_id'] as num?)?.toInt() ?? 0,
      senderName: (json['sender_name'] ?? '').toString(),
      type: (json['type'] ?? 'text').toString(),
      content: (json['content'] ?? '').toString(),
      snippet: (json['snippet'] ?? '').toString(),
      createdAt: AppDateUtils.tryParse(json['created_at']),
      pinnedAt: AppDateUtils.tryParse(json['pinned_at']),
      pinnedBy: (json['pinned_by'] as num?)?.toInt(),
      pinnedByName: (json['pinned_by_name'] ?? '').toString(),
    );
  }
}
