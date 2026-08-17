import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../core/localization/app_localizer.dart';
import '../models/chat_app_model.dart';
import '../models/session_user.dart';
import '../services/chat_api_service.dart';
import '../services/device_identity_service.dart';
import '../services/push_notification_service.dart';
import '../services/storage_service.dart';

class SessionController extends ChangeNotifier {
  SessionController({
    required ChatApiService apiService,
    required StorageService storageService,
    required DeviceIdentityService deviceIdentityService,
    required PushNotificationService pushNotificationService,
  }) : _apiService = apiService,
       _storageService = storageService,
       _deviceIdentityService = deviceIdentityService,
       _pushNotificationService = pushNotificationService;

  final ChatApiService _apiService;
  final StorageService _storageService;
  final DeviceIdentityService _deviceIdentityService;
  final PushNotificationService _pushNotificationService;

  List<ChatAppModel> _apps = const [];
  ChatAppModel? _selectedApp;
  SessionUser? _user;
  String? _token;
  bool _bootstrapping = true;
  bool _submitting = false;
  String? _error;
  DeviceIdentity? _deviceIdentity;

  List<ChatAppModel> get apps => _apps;
  ChatAppModel? get selectedApp => _selectedApp;
  SessionUser? get user => _user;
  String? get token => _token;
  bool get bootstrapping => _bootstrapping;
  bool get submitting => _submitting;
  String? get error => _error;
  bool get hasChosenApp => _selectedApp != null;
  bool get isLoggedIn =>
      _selectedApp != null && _token != null && _user != null;
  DeviceIdentity? get deviceIdentity => _deviceIdentity;
  String get notifyApiUrl => _selectedApp == null
      ? ''
      : '${_selectedApp!.apiBaseUrl}/internal/chat/notify';

  Future<void> bootstrap() async {
    if (!_bootstrapping) {
      _bootstrapping = true;
      notifyListeners();
    }

    _error = null;

    try {
      _deviceIdentity = await _deviceIdentityService.resolve();
      final storedApp = await _storageService.loadSelectedApp();
      final storedToken = await _storageService.loadToken();
      final storedUser = await _storageService.loadUser();
      try {
        _apps = await _apiService.fetchApps(AppConstants.bootstrapApiBase);
      } catch (_) {
        _apps = const [];
      }

      if (_apps.isNotEmpty && storedApp != null) {
        ChatAppModel? syncedApp;
        for (final app in _apps) {
          if (app.code == storedApp.code || app.uuid == storedApp.uuid) {
            syncedApp = app;
            break;
          }
        }
        syncedApp ??= _apps.length == 1 ? _apps.first : storedApp;
        _selectedApp = syncedApp;
        if (syncedApp.apiBaseUrl != storedApp.apiBaseUrl ||
            syncedApp.socketUrl != storedApp.socketUrl ||
            syncedApp.appUrl != storedApp.appUrl ||
            syncedApp.uuid != storedApp.uuid ||
            syncedApp.name != storedApp.name ||
            syncedApp.logoUrl != storedApp.logoUrl) {
          await _storageService.saveSelectedApp(syncedApp);
        }
      } else if (_apps.isNotEmpty) {
        _selectedApp = _apps.first;
        await _storageService.saveSelectedApp(_selectedApp!);
      } else if (storedApp != null) {
        _selectedApp = storedApp;
      }

      if (_selectedApp != null) {
        _apiService.setContext(app: _selectedApp!, accessToken: storedToken);
      }

      if (_selectedApp != null &&
          storedToken != null &&
          storedToken.isNotEmpty) {
        try {
          final freshUser = await _apiService.me();
          _token = storedToken;
          _user = freshUser;
          await _storageService.saveUser(freshUser);
          await _registerCurrentDevice();
        } catch (_) {
          _token = null;
          _user = storedUser;
          await _storageService.clearSession();
        }
      } else {
        _user = storedUser;
      }
    } catch (error) {
      _error = AppLocalizer.current.tr(
        'Unable to connect to {appName} right now.',
        {'appName': AppConstants.appName},
      );
    } finally {
      _bootstrapping = false;
      notifyListeners();
    }
  }

  Future<void> chooseApp(ChatAppModel app) async {
    _selectedApp = app;
    _user = null;
    _token = null;
    _error = null;
    _apiService.setContext(app: app);
    await _storageService.saveSelectedApp(app);
    await _storageService.clearSession();
    notifyListeners();
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    if (_selectedApp == null) {
      _error = AppLocalizer.current.tr(
        'Service setup is still loading. Please try again.',
      );
      notifyListeners();
      return;
    }

    _submitting = true;
    _error = null;
    notifyListeners();

    try {
      final deviceIdentity =
          _deviceIdentity ?? await _deviceIdentityService.resolve();
      _deviceIdentity = deviceIdentity;

      _apiService.setContext(app: _selectedApp!);
      final result = await _apiService.login(
        appCode: _selectedApp!.code,
        username: username,
        password: password,
        deviceName: deviceIdentity.deviceName,
      );

      _selectedApp = result.app;
      _token = result.token;
      _user = result.user;
      _apiService.setContext(app: result.app, accessToken: result.token);

      await _storageService.saveSelectedApp(result.app);
      await _storageService.saveToken(result.token);
      await _storageService.saveUser(result.user);

      await _registerCurrentDevice();
    } catch (error) {
      _error = _readableError(error);
      rethrow;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  Future<void> register({
    String? name,
    required String username,
    String? email,
    String? phone,
    required String password,
  }) async {
    if (_selectedApp == null) {
      _error = AppLocalizer.current.tr(
        'Service setup is still loading. Please try again.',
      );
      notifyListeners();
      return;
    }

    _submitting = true;
    _error = null;
    notifyListeners();

    try {
      final deviceIdentity =
          _deviceIdentity ?? await _deviceIdentityService.resolve();
      _deviceIdentity = deviceIdentity;

      _apiService.setContext(app: _selectedApp!);
      final result = await _apiService.register(
        name: name,
        username: username,
        email: email,
        phone: phone,
        password: password,
      );

      _token = result.token;
      _user = result.user;
      _apiService.setContext(app: _selectedApp!, accessToken: result.token);

      await _storageService.saveSelectedApp(_selectedApp!);
      await _storageService.saveToken(result.token);
      await _storageService.saveUser(result.user);

      await _registerCurrentDevice();
    } catch (error) {
      _error = _readableError(error, registering: true);
      rethrow;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile({
    required String name,
    String? phone,
    String? bio,
    String? avatarUrl,
  }) async {
    if (_selectedApp == null || _token == null || _user == null) {
      _error = AppLocalizer.current.tr(
        'Service setup is still loading. Please try again.',
      );
      notifyListeners();
      return;
    }

    _submitting = true;
    _error = null;
    notifyListeners();

    try {
      final updatedUser = await _apiService.updateProfile(
        name: name,
        phone: phone,
        bio: bio,
        avatarUrl: avatarUrl,
      );

      _user = updatedUser.copyWith(
        name: name,
        phone: phone ?? '',
        bio: bio ?? '',
        avatarUrl: (avatarUrl ?? '').trim().isEmpty
            ? updatedUser.avatarUrl
            : avatarUrl,
      );

      await _storageService.saveUser(_user!);
    } catch (error) {
      final raw = error.toString();
      _error = raw.contains('422')
          ? AppLocalizer.current.tr(
              'Please review your profile details and try again.',
            )
          : AppLocalizer.current.tr('Could not update profile right now.');
      rethrow;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  Future<void> updatePresence(bool isOpen) async {
    if (_selectedApp == null || _token == null || _deviceIdentity == null) {
      return;
    }

    try {
      await _apiService.updatePresence(
        appCode: _selectedApp!.code,
        deviceUuid: _deviceIdentity!.uuid,
        isAppOpen: isOpen,
      );
    } catch (_) {
      // Ignore presence errors to keep UX smooth.
    }
  }

  Future<void> logout() async {
    final selectedApp = _selectedApp;
    if (selectedApp != null) {
      try {
        await updatePresence(false);
        await _apiService.logout();
      } catch (_) {
        // Ignore logout API errors.
      }
    }

    _user = null;
    _token = null;
    if (selectedApp != null) {
      _apiService.setContext(app: selectedApp);
    }
    await _storageService.clearSession();
    notifyListeners();
  }

  Future<void> _registerCurrentDevice() async {
    final selectedApp = _selectedApp;
    final deviceIdentity = _deviceIdentity;

    if (selectedApp == null || deviceIdentity == null) return;

    try {
      final pushToken = await _pushNotificationService.getPushToken();
      await _apiService.registerDevice(
        appCode: selectedApp.code,
        deviceUuid: deviceIdentity.uuid,
        platform: deviceIdentity.platform,
        deviceName: deviceIdentity.deviceName,
        appVersion: deviceIdentity.appVersion,
        pushToken: pushToken,
        notificationEnabled: true,
        isAppOpen: true,
      );
    } catch (_) {
      // Safe to ignore here. Chat app still works without device registration.
    }
  }

  String _readableError(Object error, {bool registering = false}) {
    final raw = error.toString();
    if (raw.contains('422')) {
      return registering
          ? AppLocalizer.current.tr(
              'Registration details are invalid or already in use.',
            )
          : AppLocalizer.current.tr('Incorrect username or password.');
    }
    if (raw.contains('404')) {
      return AppLocalizer.current.tr('Service configuration was not found.');
    }
    return registering
        ? AppLocalizer.current.tr('Sign-up failed. Please try again later.')
        : AppLocalizer.current.tr('Sign-in failed. Please try again later.');
  }
}
