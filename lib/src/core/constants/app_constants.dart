class AppConstants {
  const AppConstants._();

  static const String appName = 'Nails Talk';
  static const String appTagline = 'Connect, work, and share around the U.S.';
  static const String bootstrapApiBase = String.fromEnvironment(
    'BOOTSTRAP_API_BASE',
    defaultValue: 'http://54.205.74.122/api',
  );
  static const String chatCallBaseUrl = String.fromEnvironment(
    'CHAT_CALL_BASE_URL',
    defaultValue: 'http://54.205.74.122',
  );
  static const bool moviePaymentsEnabled = bool.fromEnvironment(
    'MOVIE_PAYMENTS_ENABLED',
    defaultValue: false,
  );
  static const bool youtubeVideoFeatureEnabled = bool.fromEnvironment(
    'YOUTUBE_VIDEO_FEATURE_ENABLED',
    defaultValue: true,
  );
  static const bool hostedMoviePlaybackEnabled = bool.fromEnvironment(
    'HOSTED_MOVIE_PLAYBACK_ENABLED',
    defaultValue: false,
  );
  static const bool forceShowAppleVideoFeature = bool.fromEnvironment(
    'FORCE_SHOW_APPLE_VIDEO_FEATURE',
    defaultValue: false,
  );
  static bool get hideVideoForAppleReview =>
      !youtubeVideoFeatureEnabled && !forceShowAppleVideoFeature;
  static const String noPaymentReviewNote =
      'Current App Store review build has no in-app purchases, subscriptions, external checkout, paid video unlock, or hosted/direct video playback. Video content shown in the app is limited to free YouTube embeds.';

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration roomRefreshInterval = Duration(seconds: 20);
  static const int roomPageSize = 30;
  static const int messagePageSize = 30;
}
