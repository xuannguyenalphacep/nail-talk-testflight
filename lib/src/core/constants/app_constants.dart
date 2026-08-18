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

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration roomRefreshInterval = Duration(seconds: 20);
  static const int roomPageSize = 30;
  static const int messagePageSize = 30;
}
