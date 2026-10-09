class SessionUser {
  SessionUser({
    required this.id,
    required this.uuid,
    required this.name,
    required this.username,
    required this.email,
    required this.phone,
    required this.bio,
    required this.companyId,
    required this.avatarUrl,
    required this.gameCoins,
    required this.gameCoinGrantedOn,
  });

  final int id;
  final String uuid;
  final String name;
  final String username;
  final String email;
  final String phone;
  final String bio;
  final int? companyId;
  final String avatarUrl;
  final int gameCoins;
  final String gameCoinGrantedOn;

  factory SessionUser.fromJson(Map<String, dynamic> json) {
    return SessionUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      uuid: (json['uuid'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      bio: (json['bio'] ?? '').toString(),
      companyId: (json['company_id'] as num?)?.toInt(),
      avatarUrl: (json['avatar_url'] ?? '').toString(),
      gameCoins: (json['game_coins'] as num?)?.toInt() ?? 0,
      gameCoinGrantedOn: (json['game_coin_granted_on'] ?? '').toString(),
    );
  }

  SessionUser copyWith({
    String? name,
    String? username,
    String? email,
    String? phone,
    String? bio,
    int? companyId,
    String? avatarUrl,
    int? gameCoins,
    String? gameCoinGrantedOn,
  }) {
    return SessionUser(
      id: id,
      uuid: uuid,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      bio: bio ?? this.bio,
      companyId: companyId ?? this.companyId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      gameCoins: gameCoins ?? this.gameCoins,
      gameCoinGrantedOn: gameCoinGrantedOn ?? this.gameCoinGrantedOn,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uuid': uuid,
      'name': name,
      'username': username,
      'email': email,
      'phone': phone,
      'bio': bio,
      'company_id': companyId,
      'avatar_url': avatarUrl,
      'game_coins': gameCoins,
      'game_coin_granted_on': gameCoinGrantedOn,
    };
  }
}
