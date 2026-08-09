import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../models/app_option.dart';
import '../models/chat_app_model.dart';
import '../models/chat_message.dart';
import '../models/chat_message_page.dart';
import '../models/chat_notification_item.dart';
import '../models/chat_room.dart';
import '../models/chat_search_result.dart';
import '../models/chat_user_option.dart';
import '../models/job_listing_item.dart';
import '../models/marketplace_item.dart';
import '../models/movie_item.dart';
import '../models/movie_plan_model.dart';
import '../models/property_listing_item.dart';
import '../models/saved_item.dart';
import '../models/session_user.dart';
import '../models/user_profile_model.dart';

class ChatApiService {
  ChatApiService()
    : _dio = Dio(
        BaseOptions(
          connectTimeout: AppConstants.connectTimeout,
          receiveTimeout: AppConstants.receiveTimeout,
          headers: const {'Accept': 'application/json'},
        ),
      ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (kDebugMode) {
            debugPrint(
              '[ChatApi] --> ${options.method} ${options.baseUrl}${options.path}',
            );
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            debugPrint(
              '[ChatApi] <-- ${response.statusCode} ${response.requestOptions.path}',
            );
          }
          handler.next(response);
        },
        onError: (error, handler) {
          if (kDebugMode) {
            debugPrint(
              '[ChatApi] xx ${error.requestOptions.method} ${error.requestOptions.baseUrl}${error.requestOptions.path} :: ${error.message}',
            );
            final data = error.response?.data;
            if (data != null) {
              debugPrint('[ChatApi] response: $data');
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;

  String? _baseUrl;
  String? _appUrl;

  void setBootstrapBase(String baseUrl) {
    _baseUrl = _normalizeBaseUrl(baseUrl);
    _appUrl = _inferAppUrl(baseUrl);
    _dio.options.baseUrl = _baseUrl!;
    _dio.options.headers.remove('Authorization');
  }

  void setContext({required ChatAppModel app, String? accessToken}) {
    _baseUrl = _normalizeBaseUrl(app.apiBaseUrl);
    _appUrl = app.appUrl;
    _dio.options.baseUrl = _baseUrl!;
    if (accessToken != null && accessToken.isNotEmpty) {
      _dio.options.headers['Authorization'] = 'Bearer $accessToken';
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }

  Future<List<ChatAppModel>> fetchApps(String bootstrapBase) async {
    setBootstrapBase(bootstrapBase);
    final response = await _dio.get('/mobile-chat/apps');
    final payload = response.data as Map<String, dynamic>;
    final bootstrapRoot = _inferAppUrl(bootstrapBase);
    final data = (payload['data'] as List<dynamic>? ?? <dynamic>[])
        .map(
          (item) => _normalizeAppModel(
            ChatAppModel.fromJson(item as Map<String, dynamic>),
            bootstrapRoot,
          ),
        )
        .toList();
    return data;
  }

  Future<({String token, SessionUser user, ChatAppModel app})> login({
    required String appCode,
    required String username,
    required String password,
    required String deviceName,
  }) async {
    final response = await _dio.post(
      '/mobile-chat/login',
      data: {
        'app_code': appCode,
        'username': username,
        'password': password,
        'device_name': deviceName,
      },
    );

    final payload = response.data as Map<String, dynamic>;
    return (
      token: (payload['access_token'] ?? '').toString(),
      user: SessionUser.fromJson(payload['user'] as Map<String, dynamic>),
      app: _normalizeAppModel(
        ChatAppModel.fromJson(payload['app'] as Map<String, dynamic>),
        _appUrl,
      ),
    );
  }

  Future<({String token, SessionUser user})> register({
    required String name,
    required String username,
    required String email,
    String? phone,
    required String password,
  }) async {
    final response = await _dio.post(
      '/auth/register',
      data: {
        'name': name,
        'username': username,
        'email': email,
        'phone': phone,
        'password': password,
      },
    );

    final payload = response.data as Map<String, dynamic>;
    return (
      token: (payload['access_token'] ?? '').toString(),
      user: SessionUser.fromJson(payload['user'] as Map<String, dynamic>),
    );
  }

  Future<SessionUser> me() async {
    final response = await _dio.get('/mobile-chat/me');
    final payload = response.data as Map<String, dynamic>;
    return SessionUser.fromJson(payload['user'] as Map<String, dynamic>);
  }

  Future<void> logout() async {
    await _dio.post('/mobile-chat/logout');
  }

  Future<UserProfileModel> fetchProfile() async {
    final response = await _dio.get('/me');
    return UserProfileModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<SavedItemModel>> fetchBookmarks() async {
    final response = await _dio.get('/bookmarks');
    final payload = response.data as Map<String, dynamic>;
    return (payload['data'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => SavedItemModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<bool> toggleBookmark({required String type, required int id}) async {
    final response = await _dio.post(
      '/bookmarks/toggle',
      data: {'savable_type': type, 'savable_id': id},
    );
    final payload = response.data as Map<String, dynamic>;
    return payload['saved'] == true;
  }

  Future<List<AppOption>> fetchMovieCategories() async {
    final response = await _dio.get('/movies/categories');
    final payload = response.data as Map<String, dynamic>;
    return _mapSimpleList(payload, AppOption.fromJson);
  }

  Future<List<MovieItem>> fetchMovies({int? categoryId, String? search}) async {
    final response = await _dio.get(
      '/movies',
      queryParameters: {
        if (categoryId != null && categoryId > 0)
          'movie_category_id': categoryId,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    final payload = response.data as Map<String, dynamic>;
    return _mapPaginatedList(payload, MovieItem.fromJson);
  }

  Future<MovieItem> fetchMovieDetail(int movieId) async {
    final response = await _dio.get('/movies/$movieId');
    final payload = response.data as Map<String, dynamic>;
    return MovieItem.fromJson(payload['data'] as Map<String, dynamic>);
  }

  Future<List<MoviePlanModel>> fetchMoviePlans() async {
    final response = await _dio.get('/movie-plans');
    final payload = response.data as Map<String, dynamic>;
    return _mapSimpleList(payload, MoviePlanModel.fromJson);
  }

  Future<MovieSubscriptionModel?> fetchActiveSubscription() async {
    final response = await _dio.get('/movie-subscriptions/active');
    final payload = response.data as Map<String, dynamic>;
    final data = payload['data'];
    if (data is! Map<String, dynamic>) return null;
    return MovieSubscriptionModel.fromJson(data);
  }

  Future<MovieSubscriptionModel> subscribeToPlan(int planId) async {
    final response = await _dio.post(
      '/movie-subscriptions',
      data: {'movie_plan_id': planId},
    );
    final payload = response.data as Map<String, dynamic>;
    return MovieSubscriptionModel.fromJson(
      payload['data'] as Map<String, dynamic>,
    );
  }

  Future<List<AppOption>> fetchMarketplaceCategories() async {
    final response = await _dio.get('/marketplace/categories');
    final payload = response.data as Map<String, dynamic>;
    return _mapSimpleList(payload, AppOption.fromJson);
  }

  Future<List<AppOption>> fetchUsStates() async {
    final response = await _dio.get('/locations/us-states');
    final payload = response.data as Map<String, dynamic>;
    return _mapSimpleList(payload, AppOption.fromJson);
  }

  Future<List<MarketplaceItem>> fetchMarketplace({
    bool mine = false,
    int? categoryId,
    String? state,
    String? search,
  }) async {
    final response = await _dio.get(
      '/marketplace/listings',
      queryParameters: {
        if (mine) 'mine': 1,
        if (categoryId != null && categoryId > 0)
          'marketplace_category_id': categoryId,
        if (state != null && state.trim().isNotEmpty) 'state': state.trim(),
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    final payload = response.data as Map<String, dynamic>;
    return _mapPaginatedList(payload, MarketplaceItem.fromJson);
  }

  Future<MarketplaceItem> createMarketplaceListing({
    required String title,
    required String description,
    required double price,
    required String city,
    required String state,
    required String contactPhone,
    required String contactEmail,
    int? categoryId,
    List<String> imageUrls = const [],
  }) async {
    final response = await _dio.post(
      '/marketplace/listings',
      data: {
        'marketplace_category_id': categoryId,
        'title': title,
        'description': description,
        'price': price,
        'currency': 'USD',
        'condition': 'used',
        'city': city,
        'state': state,
        'contact_phone': contactPhone,
        'contact_email': contactEmail,
        'image_urls': imageUrls,
        'status': 'published',
      },
    );
    final payload = response.data as Map<String, dynamic>;
    return MarketplaceItem.fromJson(payload['data'] as Map<String, dynamic>);
  }

  Future<List<JobListingItem>> fetchJobs({
    bool mine = false,
    String? mode,
    String? state,
    String? search,
  }) async {
    final response = await _dio.get(
      '/jobs',
      queryParameters: {
        if (mine) 'mine': 1,
        if (mode != null && mode.isNotEmpty) 'listing_mode': mode,
        if (state != null && state.trim().isNotEmpty) 'state': state.trim(),
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    final payload = response.data as Map<String, dynamic>;
    return _mapPaginatedList(payload, JobListingItem.fromJson);
  }

  Future<JobListingItem> createJobListing({
    required String title,
    required String salonName,
    required String description,
    required String requirements,
    required double salaryMin,
    required double salaryMax,
    required String city,
    required String state,
    required String contactPhone,
    required String contactEmail,
    String mode = 'hiring',
    List<String> imageUrls = const [],
  }) async {
    final response = await _dio.post(
      '/jobs',
      data: {
        'listing_mode': mode,
        'title': title,
        'salon_name': salonName,
        'description': description,
        'requirements': requirements,
        'employment_type': 'full_time',
        'salary_min': salaryMin,
        'salary_max': salaryMax,
        'salary_currency': 'USD',
        'city': city,
        'state': state,
        'contact_phone': contactPhone,
        'contact_email': contactEmail,
        'image_urls': imageUrls,
        'status': 'published',
      },
    );
    final payload = response.data as Map<String, dynamic>;
    return JobListingItem.fromJson(payload['data'] as Map<String, dynamic>);
  }

  Future<List<PropertyListingItem>> fetchProperties({
    bool mine = false,
    String? mode,
    String? state,
    String? search,
  }) async {
    final response = await _dio.get(
      '/properties',
      queryParameters: {
        if (mine) 'mine': 1,
        if (mode != null && mode.isNotEmpty) 'listing_mode': mode,
        if (state != null && state.trim().isNotEmpty) 'state': state.trim(),
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    final payload = response.data as Map<String, dynamic>;
    return _mapPaginatedList(payload, PropertyListingItem.fromJson);
  }

  Future<PropertyListingItem> createPropertyListing({
    required String title,
    required String description,
    required double price,
    required double depositAmount,
    required String city,
    required String state,
    required String addressLine,
    required String contactPhone,
    required String contactEmail,
    required List<String> amenities,
    String mode = 'room_share',
    List<String> imageUrls = const [],
  }) async {
    final response = await _dio.post(
      '/properties',
      data: {
        'listing_mode': mode,
        'title': title,
        'description': description,
        'price': price,
        'deposit_amount': depositAmount,
        'currency': 'USD',
        'city': city,
        'state': state,
        'address_line': addressLine,
        'available_from': DateTime.now().toIso8601String(),
        'amenities': amenities,
        'image_urls': imageUrls,
        'contact_phone': contactPhone,
        'contact_email': contactEmail,
        'status': 'published',
      },
    );
    final payload = response.data as Map<String, dynamic>;
    return PropertyListingItem.fromJson(
      payload['data'] as Map<String, dynamic>,
    );
  }

  Future<void> registerDevice({
    required String appCode,
    required String deviceUuid,
    required String platform,
    required String deviceName,
    required String appVersion,
    String? pushToken,
    bool notificationEnabled = true,
    bool isAppOpen = true,
  }) async {
    await _dio.post(
      '/mobile-chat/device/register',
      data: {
        'app_code': appCode,
        'device_uuid': deviceUuid,
        'platform': platform,
        'device_name': deviceName,
        'app_version': appVersion,
        'push_token': pushToken,
        'notification_enabled': notificationEnabled,
        'is_app_open': isAppOpen,
      },
    );
  }

  Future<void> updatePresence({
    required String appCode,
    required String deviceUuid,
    required bool isAppOpen,
  }) async {
    await _dio.post(
      '/mobile-chat/device/presence',
      data: {
        'app_code': appCode,
        'device_uuid': deviceUuid,
        'is_app_open': isAppOpen,
      },
    );
  }

  Future<List<ChatNotificationItem>> fetchUnreadNotifications({
    int limit = 10,
  }) async {
    final response = await _dio.get(
      '/mobile-chat/notifications',
      queryParameters: {'unread_only': 1, 'limit': limit},
    );
    final payload = response.data as Map<String, dynamic>;
    final data = payload['data'] as List<dynamic>? ?? <dynamic>[];
    return data
        .map(
          (item) =>
              ChatNotificationItem.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> markNotificationsRead(List<int> ids) async {
    if (ids.isEmpty) return;
    await _dio.post('/mobile-chat/notifications/read', data: {'ids': ids});
  }

  Future<List<ChatUserOption>> fetchUsers(
    String keyword, {
    bool mention = false,
  }) async {
    final response = await _dio.get(
      '/mobile-chat/users/select2_list',
      queryParameters: {'search': keyword, if (mention) 'mention': 1},
    );
    final payload = response.data as Map<String, dynamic>;
    final data = payload['data'] as List<dynamic>? ?? <dynamic>[];
    return data
        .map((item) => ChatUserOption.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<ChatRoom>> fetchRooms() async {
    final response = await _dio.get('/mobile-chat/rooms');
    final payload = response.data as Map<String, dynamic>;
    final data = payload['rooms'] as List<dynamic>? ?? <dynamic>[];
    return data
        .map((item) => ChatRoom.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<ChatRoom>> fetchHiddenRooms() async {
    final response = await _dio.get('/mobile-chat/rooms/hidden');
    final payload = response.data as Map<String, dynamic>;
    final data = payload['rooms'] as List<dynamic>? ?? <dynamic>[];
    return data
        .map((item) => ChatRoom.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ChatRoom> joinPublicGroup(int roomId) async {
    final response = await _dio.post('/mobile-chat/rooms/$roomId/join');
    final payload = response.data as Map<String, dynamic>;
    return ChatRoom.fromJson(payload['room'] as Map<String, dynamic>);
  }

  Future<List<ChatUserOption>> fetchGroupMembers(int roomId) async {
    final response = await _dio.get('/mobile-chat/rooms/$roomId/members');
    final payload = response.data as Map<String, dynamic>;
    final data = payload['members'] as List<dynamic>? ?? <dynamic>[];
    return data
        .map((item) => ChatUserOption.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ChatRoom> fetchRoom(int roomId) async {
    final response = await _dio.get('/mobile-chat/detail-chat/rooms/$roomId');
    final payload = response.data as Map<String, dynamic>;
    return ChatRoom.fromJson(payload['room'] as Map<String, dynamic>);
  }

  Future<ChatMessagePage> fetchMessages(
    int roomId, {
    int page = 1,
    int perPage = AppConstants.messagePageSize,
    String? search,
  }) async {
    final response = await _dio.get(
      '/mobile-chat/detail-chat/rooms/$roomId/messages',
      queryParameters: {
        'page': page,
        'per_page': perPage,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    final payload = response.data as Map<String, dynamic>;
    final result = payload['result'] as Map<String, dynamic>;
    final messages = (result['data'] as List<dynamic>? ?? <dynamic>[])
        .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
        .toList();

    return ChatMessagePage(
      messages: messages,
      currentPage: (result['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (result['last_page'] as num?)?.toInt() ?? 1,
      hasMore:
          ((result['current_page'] as num?)?.toInt() ?? 1) <
          ((result['last_page'] as num?)?.toInt() ?? 1),
    );
  }

  Future<List<ChatSearchResult>> searchMessages(
    int roomId,
    String keyword,
  ) async {
    final response = await _dio.get(
      '/mobile-chat/detail-chat/rooms/$roomId/search',
      queryParameters: {'keyword': keyword},
    );
    final payload = response.data as Map<String, dynamic>;
    final results = (payload['results'] as List<dynamic>? ?? <dynamic>[])
        .map((item) => ChatSearchResult.fromJson(item as Map<String, dynamic>))
        .toList();
    return results;
  }

  Future<List<ChatMessage>> focusMessage(int roomId, int messageId) async {
    final response = await _dio.get(
      '/mobile-chat/detail-chat/rooms/$roomId/messages/$messageId/focus',
    );
    final payload = response.data as Map<String, dynamic>;
    final data = payload['messages'] as List<dynamic>? ?? <dynamic>[];
    return data
        .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<int> createPrivateRoom(int userId) async {
    final response = await _dio.post(
      '/realtime/chat/private',
      data: {'user_id': userId},
    );
    final payload = response.data as Map<String, dynamic>;
    return (payload['id'] as num?)?.toInt() ?? 0;
  }

  Future<int> createGroup({
    required String name,
    required List<int> memberIds,
  }) async {
    final response = await _dio.post(
      '/realtime/chat/group',
      data: {'name': name, 'members': memberIds},
    );
    final payload = response.data as Map<String, dynamic>;
    return (payload['id'] as num?)?.toInt() ?? 0;
  }

  Future<void> renameGroup({required int roomId, required String name}) async {
    await _dio.post('/realtime/chat/group/$roomId', data: {'name': name});
  }

  Future<void> markRoomReadAll(int roomId) async {
    await _dio.post('/realtime/chat/group/$roomId/read-all');
  }

  Future<({String filePath, String fileName, int fileSize, String type})>
  uploadFile(PlatformFile file) async {
    final fileName = file.name.trim().isEmpty
        ? _fallbackFileName(file.path)
        : file.name.trim();

    final multipartFile = await _buildMultipartFile(
      fileName: fileName,
      filePath: file.path,
      bytes: file.bytes,
    );

    final response = await _dio.post(
      '/realtime/chat/upload',
      data: FormData.fromMap({'file': multipartFile}),
    );

    final payload = response.data as Map<String, dynamic>;

    return (
      filePath: _resolveStorageUrl((payload['path'] ?? '').toString()),
      fileName: (payload['name'] ?? fileName).toString(),
      fileSize: (payload['size'] as num?)?.toInt() ?? 0,
      type: (payload['type'] ?? 'file').toString(),
    );
  }

  Future<MultipartFile> _buildMultipartFile({
    required String fileName,
    String? filePath,
    Uint8List? bytes,
  }) async {
    if (bytes != null && bytes.isNotEmpty) {
      return MultipartFile.fromBytes(bytes, filename: fileName);
    }

    if (filePath != null && filePath.isNotEmpty) {
      return MultipartFile.fromFile(filePath, filename: fileName);
    }

    throw ArgumentError('File bytes or file path is required.');
  }

  String _fallbackFileName(String? filePath) {
    final raw = filePath?.trim() ?? '';
    if (raw.isEmpty) return 'file';
    final segments = raw.split(RegExp(r'[\\/]'));
    return segments.isEmpty
        ? 'file'
        : (segments.last.isEmpty ? 'file' : segments.last);
  }

  String resolvePublicUrl(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final normalized = _normalizePublicPath(raw);
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return normalized;
    }

    return '${_appUrl ?? _inferAppUrl(_baseUrl)}${normalized.startsWith('/') ? normalized : '/$normalized'}';
  }

  String _resolveStorageUrl(String rawPath) {
    final normalizedPath = _normalizePublicPath(rawPath);
    if (normalizedPath.startsWith('http://') ||
        normalizedPath.startsWith('https://')) {
      return normalizedPath;
    }

    final normalized = normalizedPath.startsWith('/')
        ? normalizedPath
        : '/storage/$normalizedPath';
    return resolvePublicUrl(normalized);
  }

  String _normalizePublicPath(String rawPath) {
    final trimmed = rawPath.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    final normalizedSlashes = trimmed.replaceAll('\\', '/');
    if (normalizedSlashes.startsWith('/storage/public/')) {
      return normalizedSlashes.replaceFirst('/storage/public/', '/storage/');
    }
    if (normalizedSlashes.startsWith('storage/public/')) {
      return normalizedSlashes.replaceFirst('storage/public/', '/storage/');
    }
    if (normalizedSlashes.startsWith('/public/')) {
      return normalizedSlashes.replaceFirst('/public/', '/storage/');
    }
    if (normalizedSlashes.startsWith('public/')) {
      return normalizedSlashes.replaceFirst('public/', '/storage/');
    }
    return normalizedSlashes;
  }

  static String _normalizeBaseUrl(String baseUrl) {
    return baseUrl.replaceAll(RegExp(r'/$'), '');
  }

  static String _inferAppUrl(String? baseUrl) {
    if (baseUrl == null || baseUrl.isEmpty) return '';
    return baseUrl.replaceFirst(RegExp(r'/api$'), '');
  }

  ChatAppModel _normalizeAppModel(
    ChatAppModel app,
    String? preferredRootUrl,
  ) {
    final preferred = Uri.tryParse(preferredRootUrl?.trim() ?? '');
    if (preferred == null || preferred.host.isEmpty) {
      return app;
    }

    return ChatAppModel(
      uuid: app.uuid,
      code: app.code,
      name: app.name,
      logoUrl: app.logoUrl,
      appUrl: _replaceUrlHost(app.appUrl, preferred) ?? preferred.toString(),
      apiBaseUrl:
          _replaceUrlHost(app.apiBaseUrl, preferred, ensureApiPath: true) ??
          '${preferred.toString().replaceAll(RegExp(r"/+$"), "")}/api',
      socketUrl:
          _replaceUrlHost(app.socketUrl, preferred) ?? preferred.toString(),
    );
  }

  String? _replaceUrlHost(
    String rawUrl,
    Uri preferred,
    {bool ensureApiPath = false}
  ) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final candidate = Uri.tryParse(trimmed);
    if (candidate == null || candidate.host.isEmpty) {
      return null;
    }

    var nextPath = candidate.path;
    if (ensureApiPath) {
      if (nextPath.isEmpty || nextPath == '/') {
        nextPath = '/api';
      } else if (!nextPath.endsWith('/api')) {
        nextPath = '${nextPath.replaceAll(RegExp(r"/+$"), "")}/api';
      }
    }

    return candidate
        .replace(
          scheme: preferred.scheme,
          host: preferred.host,
          port: preferred.hasPort ? preferred.port : candidate.port,
          path: nextPath,
        )
        .toString()
        .replaceAll(RegExp(r'/$'), '');
  }

  List<T> _mapSimpleList<T>(
    Map<String, dynamic> payload,
    T Function(Map<String, dynamic>) builder,
  ) {
    return (payload['data'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => builder(Map<String, dynamic>.from(item)))
        .toList();
  }

  List<T> _mapPaginatedList<T>(
    Map<String, dynamic> payload,
    T Function(Map<String, dynamic>) builder,
  ) {
    final raw = payload['data'];
    if (raw is! Map<String, dynamic>) return const [];
    return (raw['data'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => builder(Map<String, dynamic>.from(item)))
        .toList();
  }
}
