import 'app_option.dart';

class MovieItem {
  MovieItem({
    required this.id,
    required this.uuid,
    required this.title,
    required this.slug,
    required this.summary,
    required this.posterUrl,
    required this.bannerUrl,
    required this.thirdPartyProvider,
    required this.thirdPartyUrl,
    required this.accessType,
    required this.canWatch,
    required this.isPublished,
    required this.category,
  });

  final int id;
  final String uuid;
  final String title;
  final String slug;
  final String summary;
  final String posterUrl;
  final String bannerUrl;
  final String thirdPartyProvider;
  final String thirdPartyUrl;
  final String accessType;
  final bool canWatch;
  final bool isPublished;
  final AppOption? category;

  factory MovieItem.fromJson(Map<String, dynamic> json) {
    return MovieItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      uuid: (json['uuid'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      posterUrl: (json['poster_url'] ?? '').toString(),
      bannerUrl: (json['banner_url'] ?? '').toString(),
      thirdPartyProvider: (json['third_party_provider'] ?? '').toString(),
      thirdPartyUrl: (json['third_party_url'] ?? '').toString(),
      accessType: (json['access_type'] ?? 'subscription').toString(),
      canWatch: json['can_watch'] == true || json['can_watch'] == 1,
      isPublished: json['is_published'] == true || json['is_published'] == 1,
      category: json['category'] is Map<String, dynamic>
          ? AppOption.fromJson(json['category'] as Map<String, dynamic>)
          : null,
    );
  }
}
