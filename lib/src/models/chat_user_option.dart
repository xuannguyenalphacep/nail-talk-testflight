class ChatUserOption {
  ChatUserOption({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.avatarUrl,
    this.loginId = '',
    this.mentionAll = false,
    this.mentionKey = '',
    this.linkHref = '',
  });

  final int id;
  final String name;
  final String username;
  final String email;
  final String avatarUrl;
  final String loginId;
  final bool mentionAll;
  final String mentionKey;
  final String linkHref;

  factory ChatUserOption.fromJson(Map<String, dynamic> json) {
    return ChatUserOption(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      avatarUrl: (json['avatar_url'] ?? json['avatar'] ?? '').toString(),
      loginId: (json['login_id'] ?? '').toString(),
      mentionAll: json['mention_all'] == true || json['mention_all'] == 1,
      mentionKey: (json['mention_key'] ?? '').toString(),
      linkHref: (json['link_href'] ?? '').toString(),
    );
  }

  ChatUserOption copyWith({
    String? avatarUrl,
  }) {
    return ChatUserOption(
      id: id,
      name: name,
      username: username,
      email: email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      loginId: loginId,
      mentionAll: mentionAll,
      mentionKey: mentionKey,
      linkHref: linkHref,
    );
  }
}
