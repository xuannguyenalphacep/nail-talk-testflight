class SessionUser {
  SessionUser({
    required this.id,
    required this.uuid,
    required this.name,
    required this.username,
    required this.email,
    required this.companyId,
    required this.avatarUrl,
  });

  final int id;
  final String uuid;
  final String name;
  final String username;
  final String email;
  final int? companyId;
  final String avatarUrl;

  factory SessionUser.fromJson(Map<String, dynamic> json) {
    return SessionUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      uuid: (json['uuid'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      companyId: (json['company_id'] as num?)?.toInt(),
      avatarUrl: (json['avatar_url'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uuid': uuid,
      'name': name,
      'username': username,
      'email': email,
      'company_id': companyId,
      'avatar_url': avatarUrl,
    };
  }
}
