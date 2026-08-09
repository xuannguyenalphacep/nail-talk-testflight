import 'session_user.dart';

class UserProfileSummary {
  UserProfileSummary({
    required this.marketplaceCount,
    required this.jobCount,
    required this.propertyCount,
    required this.movieCount,
    required this.activeSubscriptionCount,
  });

  final int marketplaceCount;
  final int jobCount;
  final int propertyCount;
  final int movieCount;
  final int activeSubscriptionCount;

  factory UserProfileSummary.fromJson(Map<String, dynamic> json) {
    return UserProfileSummary(
      marketplaceCount: (json['marketplace_count'] as num?)?.toInt() ?? 0,
      jobCount: (json['job_count'] as num?)?.toInt() ?? 0,
      propertyCount: (json['property_count'] as num?)?.toInt() ?? 0,
      movieCount: (json['movie_count'] as num?)?.toInt() ?? 0,
      activeSubscriptionCount:
          (json['active_subscription_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class UserProfileModel {
  UserProfileModel({required this.user, required this.summary});

  final SessionUser user;
  final UserProfileSummary summary;

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      user: SessionUser.fromJson(json['user'] as Map<String, dynamic>),
      summary: UserProfileSummary.fromJson(
        json['summary'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
    );
  }
}
