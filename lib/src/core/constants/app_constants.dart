class AppConstants {
  const AppConstants._();

  static const String appName = 'Nails Talk';
  static const String appTagline = 'Connect, work, and share around the U.S.';
  static const String bootstrapApiBase = String.fromEnvironment(
    'BOOTSTRAP_API_BASE',
    defaultValue: 'http://54.205.74.122/api',
  );
  // Keep the raw value separate so runtime normalization can distinguish an
  // explicit development override from the production fallback.
  static const String chatCallBaseUrlOverride = String.fromEnvironment(
    'CHAT_CALL_BASE_URL',
  );
  static const String chatCallBaseUrl = chatCallBaseUrlOverride == ''
      ? 'http://54.205.74.122'
      : chatCallBaseUrlOverride;
  // Movies/video are excluded from release builds (App Store guideline
  // 2.5.19: no dormant features). Every movie entry point is guarded by this
  // compile-time constant, so the AOT tree shaker drops the movie screens and
  // API calls; the server `video_enabled` flag alone cannot re-enable them.
  static const bool moviesFeatureEnabled = bool.fromEnvironment(
    'MOVIES_FEATURE_ENABLED',
    defaultValue: false,
  );
  static const bool moviePaymentsEnabled = bool.fromEnvironment(
    'MOVIE_PAYMENTS_ENABLED',
    defaultValue: false,
  );
  static const bool youtubeEmbedPlaybackEnabled = bool.fromEnvironment(
    'YOUTUBE_VIDEO_FEATURE_ENABLED',
    defaultValue: true,
  );
  static const bool hostedMoviePlaybackEnabled = bool.fromEnvironment(
    'HOSTED_MOVIE_PLAYBACK_ENABLED',
    defaultValue: false,
  );
  static const String videoPaymentsUnavailableNote =
      'Video purchases are not available in this app configuration. There are no in-app purchases, subscriptions, external checkout, or paid video unlocks.';

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration roomRefreshInterval = Duration(seconds: 20);
  static const int roomPageSize = 30;
  static const int messagePageSize = 30;
}
