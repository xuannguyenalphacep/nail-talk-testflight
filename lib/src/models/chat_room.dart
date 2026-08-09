import '../core/utils/app_date_utils.dart';

class ChatRoomLastMessage {
  ChatRoomLastMessage({
    required this.content,
    required this.createdAt,
    required this.senderName,
    required this.senderId,
  });

  final String content;
  final DateTime? createdAt;
  final String senderName;
  final int? senderId;

  factory ChatRoomLastMessage.fromJson(Map<String, dynamic> json) {
    return ChatRoomLastMessage(
      content: (json['content'] ?? '').toString(),
      createdAt: AppDateUtils.tryParse(json['created_at']),
      senderName: (json['sender_name'] ?? '').toString(),
      senderId: (json['sender_id'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'created_at': createdAt?.toIso8601String(),
      'sender_name': senderName,
      'sender_id': senderId,
    };
  }
}

class ChatRoom {
  ChatRoom({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.avatar,
    required this.peerId,
    required this.tableName,
    required this.uuidTableRecord,
    required this.unreadCount,
    required this.bookmarked,
    required this.hiddenAt,
    required this.lastMessage,
    required this.isPublic,
    required this.isActive,
    required this.isJoined,
    required this.canJoin,
    required this.memberCount,
  });

  final int id;
  final String type;
  final String title;
  final String description;
  final String avatar;
  final int? peerId;
  final String? tableName;
  final String? uuidTableRecord;
  final int unreadCount;
  final bool bookmarked;
  final DateTime? hiddenAt;
  final ChatRoomLastMessage? lastMessage;
  final bool isPublic;
  final bool isActive;
  final bool isJoined;
  final bool canJoin;
  final int memberCount;

  bool get isPrivate => type == 'private';
  bool get isGroup => type == 'group';

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: (json['id'] as num?)?.toInt() ?? 0,
      type: (json['type'] ?? 'group').toString(),
      title: (json['title'] ?? json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      avatar: (json['avatar'] ?? json['avatar_url'] ?? json['peer_avatar'] ?? '').toString(),
      peerId: (json['peer_id'] as num?)?.toInt(),
      tableName: json['table_name']?.toString(),
      uuidTableRecord: json['uuid_table_record']?.toString(),
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      bookmarked: (json['bookmarked'] == true) || (json['bookmarked'] == 1),
      hiddenAt: AppDateUtils.tryParse(json['hidden_at']),
      isPublic: json['is_public'] == true || json['is_public'] == 1,
      isActive: json['is_active'] == null || json['is_active'] == true || json['is_active'] == 1,
      isJoined: json['is_joined'] == true || json['is_joined'] == 1,
      canJoin: json['can_join'] == true || json['can_join'] == 1,
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      lastMessage: json['last_message'] is Map<String, dynamic>
          ? ChatRoomLastMessage.fromJson(json['last_message'] as Map<String, dynamic>)
          : null,
    );
  }

  ChatRoom copyWith({
    String? title,
    String? description,
    String? avatar,
    int? unreadCount,
    bool? bookmarked,
    ChatRoomLastMessage? lastMessage,
    bool? isPublic,
    bool? isActive,
    bool? isJoined,
    bool? canJoin,
    int? memberCount,
  }) {
    return ChatRoom(
      id: id,
      type: type,
      title: title ?? this.title,
      description: description ?? this.description,
      avatar: avatar ?? this.avatar,
      peerId: peerId,
      tableName: tableName,
      uuidTableRecord: uuidTableRecord,
      unreadCount: unreadCount ?? this.unreadCount,
      bookmarked: bookmarked ?? this.bookmarked,
      hiddenAt: hiddenAt,
      lastMessage: lastMessage ?? this.lastMessage,
      isPublic: isPublic ?? this.isPublic,
      isActive: isActive ?? this.isActive,
      isJoined: isJoined ?? this.isJoined,
      canJoin: canJoin ?? this.canJoin,
      memberCount: memberCount ?? this.memberCount,
    );
  }
}
