class ChatAppModel {
  ChatAppModel({
    required this.uuid,
    required this.code,
    required this.name,
    required this.logoUrl,
    required this.appUrl,
    required this.apiBaseUrl,
    required this.socketUrl,
    required this.videoEnabled,
    required this.cardGameEnabled,
  });

  final String uuid;
  final String code;
  final String name;
  final String logoUrl;
  final String appUrl;
  final String apiBaseUrl;
  final String socketUrl;
  final bool videoEnabled;
  final bool cardGameEnabled;

  factory ChatAppModel.fromJson(Map<String, dynamic> json) {
    final featureFlags = json['feature_flags'];
    final featureMap = featureFlags is Map<String, dynamic>
        ? featureFlags
        : const <String, dynamic>{};

    return ChatAppModel(
      uuid: (json['uuid'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      logoUrl: (json['logo_url'] ?? '').toString(),
      appUrl: (json['app_url'] ?? '').toString(),
      apiBaseUrl: (json['api_base_url'] ?? '').toString(),
      socketUrl: (json['socket_url'] ?? '').toString(),
      videoEnabled: _readBool(
        json['video_enabled'] ?? featureMap['video_enabled'],
      ),
      cardGameEnabled: _readBool(
        json['card_game_enabled'] ?? featureMap['card_game_enabled'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'code': code,
      'name': name,
      'logo_url': logoUrl,
      'app_url': appUrl,
      'api_base_url': apiBaseUrl,
      'socket_url': socketUrl,
      'video_enabled': videoEnabled,
      'card_game_enabled': cardGameEnabled,
      'feature_flags': {
        'video_enabled': videoEnabled,
        'card_game_enabled': cardGameEnabled,
      },
    };
  }

  static bool _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    final text = value?.toString().trim().toLowerCase();
    return text == '1' || text == 'true' || text == 'yes' || text == 'on';
  }
}
