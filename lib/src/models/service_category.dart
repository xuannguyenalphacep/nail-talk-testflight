int _readInt(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

class ServiceCategory {
  const ServiceCategory({
    required this.id,
    required this.uuid,
    required this.name,
    required this.slug,
    required this.shortLabel,
    required this.summary,
    required this.description,
    required this.heroTitle,
    required this.ctaLabel,
    required this.icon,
    required this.tintColor,
    required this.bannerImageUrl,
    required this.providersCount,
    required this.sortOrder,
    required this.isActive,
  });

  final int id;
  final String uuid;
  final String name;
  final String slug;
  final String shortLabel;
  final String summary;
  final String description;
  final String heroTitle;
  final String ctaLabel;
  final String icon;
  final String tintColor;
  final String bannerImageUrl;
  final int providersCount;
  final int sortOrder;
  final bool isActive;

  String get displayTitle => heroTitle.trim().isEmpty ? name : heroTitle;

  String get displaySummary => summary.trim().isEmpty
      ? 'Chọn dịch vụ liên kết và gửi yêu cầu đặt lịch.'
      : summary;

  factory ServiceCategory.fromJson(Map<String, dynamic> json) {
    return ServiceCategory(
      id: _readInt(json['id']),
      uuid: (json['uuid'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      shortLabel: (json['short_label'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      heroTitle: (json['hero_title'] ?? '').toString(),
      ctaLabel: (json['cta_label'] ?? '').toString(),
      icon: (json['icon'] ?? '').toString(),
      tintColor: (json['tint_color'] ?? '').toString(),
      bannerImageUrl: (json['banner_image_url'] ?? '').toString(),
      providersCount: _readInt(json['providers_count']),
      sortOrder: _readInt(json['sort_order']),
      isActive: json['is_active'] == true || json['is_active'] == 1,
    );
  }

  ServiceCategory copyWith({String? bannerImageUrl}) {
    return ServiceCategory(
      id: id,
      uuid: uuid,
      name: name,
      slug: slug,
      shortLabel: shortLabel,
      summary: summary,
      description: description,
      heroTitle: heroTitle,
      ctaLabel: ctaLabel,
      icon: icon,
      tintColor: tintColor,
      bannerImageUrl: bannerImageUrl ?? this.bannerImageUrl,
      providersCount: providersCount,
      sortOrder: sortOrder,
      isActive: isActive,
    );
  }
}
