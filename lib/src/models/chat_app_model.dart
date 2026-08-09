class ChatAppModel {
  ChatAppModel({
    required this.uuid,
    required this.code,
    required this.name,
    required this.logoUrl,
    required this.appUrl,
    required this.apiBaseUrl,
    required this.socketUrl,
  });

  final String uuid;
  final String code;
  final String name;
  final String logoUrl;
  final String appUrl;
  final String apiBaseUrl;
  final String socketUrl;

  factory ChatAppModel.fromJson(Map<String, dynamic> json) {
    return ChatAppModel(
      uuid: (json['uuid'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      logoUrl: (json['logo_url'] ?? '').toString(),
      appUrl: (json['app_url'] ?? '').toString(),
      apiBaseUrl: (json['api_base_url'] ?? '').toString(),
      socketUrl: (json['socket_url'] ?? '').toString(),
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
    };
  }
}
