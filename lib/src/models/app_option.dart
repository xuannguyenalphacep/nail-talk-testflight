class AppOption {
  AppOption({
    required this.id,
    required this.uuid,
    required this.name,
    required this.slug,
  });

  final int id;
  final String uuid;
  final String name;
  final String slug;

  factory AppOption.fromJson(Map<String, dynamic> json) {
    return AppOption(
      id: (json['id'] as num?)?.toInt() ?? 0,
      uuid: (json['uuid'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
    );
  }
}
