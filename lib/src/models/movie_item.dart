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
    required this.sourceType,
    required this.youtubeUrl,
    required this.youtubeVideoId,
    required this.youtubeEmbedUrl,
    required this.hostedVideoUrl,
    required this.accessType,
    required this.price,
    required this.currency,
    required this.requiresPayment,
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
  final String sourceType;
  final String youtubeUrl;
  final String youtubeVideoId;
  final String youtubeEmbedUrl;
  final String hostedVideoUrl;
  final String accessType;
  final double price;
  final String currency;
  final bool requiresPayment;
  final bool canWatch;
  final bool isPublished;
  final AppOption? category;

  bool get isYoutube => sourceType == 'youtube';
  bool get isHosted => sourceType == 'hosted';
  bool get isFree => isYoutube || accessType == 'free';
  bool get isPaid =>
      !isFree &&
      (price > 0 ||
          requiresPayment ||
          accessType == 'paid' ||
          accessType == 'pay_per_view' ||
          accessType == 'subscription');
  String get playableUrl {
    if (isYoutube) {
      return youtubeEmbedUrl.isNotEmpty ? youtubeEmbedUrl : youtubeUrl;
    }
    return hostedVideoUrl.isNotEmpty ? hostedVideoUrl : thirdPartyUrl;
  }

  factory MovieItem.fromJson(Map<String, dynamic> json) {
    final thirdPartyUrl = (json['third_party_url'] ?? '').toString();
    final apiSourceType = (json['source_type'] ?? '').toString().toLowerCase();
    final apiYoutubeUrl = (json['youtube_url'] ?? '').toString();
    final inferredYoutubeId = _extractYoutubeId(
      apiYoutubeUrl.isNotEmpty ? apiYoutubeUrl : thirdPartyUrl,
    );
    final sourceType = apiSourceType.isNotEmpty
        ? apiSourceType
        : (inferredYoutubeId == null ? 'hosted' : 'youtube');
    final youtubeUrl = apiYoutubeUrl.isNotEmpty
        ? apiYoutubeUrl
        : (sourceType == 'youtube' ? thirdPartyUrl : '');
    final youtubeVideoId =
        (json['youtube_video_id'] ?? '').toString().trim().isNotEmpty
        ? (json['youtube_video_id'] ?? '').toString().trim()
        : (inferredYoutubeId ?? '');
    final youtubeEmbedUrl =
        (json['youtube_embed_url'] ?? '').toString().trim().isNotEmpty
        ? (json['youtube_embed_url'] ?? '').toString().trim()
        : (youtubeVideoId.isEmpty
              ? ''
              : 'https://www.youtube.com/embed/$youtubeVideoId?playsinline=1&rel=0&modestbranding=1');

    return MovieItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      uuid: (json['uuid'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      posterUrl: (json['poster_url'] ?? '').toString(),
      bannerUrl: (json['banner_url'] ?? '').toString(),
      thirdPartyProvider: (json['third_party_provider'] ?? '').toString(),
      thirdPartyUrl: thirdPartyUrl,
      sourceType: sourceType,
      youtubeUrl: youtubeUrl,
      youtubeVideoId: youtubeVideoId,
      youtubeEmbedUrl: youtubeEmbedUrl,
      hostedVideoUrl: (json['hosted_video_url'] ?? '').toString(),
      accessType: (json['access_type'] ?? 'paid').toString().toLowerCase(),
      price: _readDouble(json['price']),
      currency: (json['currency'] ?? 'USD').toString().toUpperCase(),
      requiresPayment:
          json['requires_payment'] == true || json['requires_payment'] == 1,
      canWatch: json['can_watch'] == true || json['can_watch'] == 1,
      isPublished: json['is_published'] == true || json['is_published'] == 1,
      category: json['category'] is Map<String, dynamic>
          ? AppOption.fromJson(json['category'] as Map<String, dynamic>)
          : null,
    );
  }
}

double _readDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

String? _extractYoutubeId(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(trimmed)) return trimmed;

  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;

  final v = uri.queryParameters['v'];
  if (v != null && RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(v)) {
    return v;
  }

  final host = uri.host.toLowerCase();
  final segments = uri.pathSegments;
  if (host.contains('youtu.be') && segments.isNotEmpty) {
    final candidate = segments.first;
    if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(candidate)) {
      return candidate;
    }
  }

  for (final marker in ['embed', 'shorts', 'live']) {
    final markerIndex = segments.indexOf(marker);
    if (markerIndex >= 0 && markerIndex + 1 < segments.length) {
      final candidate = segments[markerIndex + 1];
      if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(candidate)) {
        return candidate;
      }
    }
  }

  return null;
}
