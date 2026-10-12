import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_app_model.dart';
import '../models/session_user.dart';

class StorageService {
  static const _keySelectedApp = 'selected_chat_app';
  static const _keyUser = 'session_user';
  static const _keyToken = 'session_token';
  static const _keyDeviceUuid = 'device_uuid';
  static const _keyLanguageCode = 'app_language_code';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<void> saveSelectedApp(ChatAppModel app) async {
    final prefs = await _prefs;
    await prefs.setString(_keySelectedApp, jsonEncode(app.toJson()));
  }

  Future<ChatAppModel?> loadSelectedApp() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_keySelectedApp);
    if (raw == null || raw.isEmpty) return null;
    return ChatAppModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> clearSelectedApp() async {
    final prefs = await _prefs;
    await prefs.remove(_keySelectedApp);
  }

  Future<void> saveUser(SessionUser user) async {
    await _secureStorage.write(key: _keyUser, value: jsonEncode(user.toJson()));
    // Remove the legacy plaintext copy after a successful secure write.
    final prefs = await _prefs;
    await prefs.remove(_keyUser);
  }

  Future<SessionUser?> loadUser() async {
    final secureRaw = await _secureStorage.read(key: _keyUser);
    if (secureRaw != null && secureRaw.isNotEmpty) {
      return SessionUser.fromJson(
        jsonDecode(secureRaw) as Map<String, dynamic>,
      );
    }

    // One-time migration for installs that stored the profile in preferences.
    final prefs = await _prefs;
    final raw = prefs.getString(_keyUser);
    if (raw == null || raw.isEmpty) return null;
    final user = SessionUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    await saveUser(user);
    return user;
  }

  Future<void> clearUser() async {
    await _secureStorage.delete(key: _keyUser);
    final prefs = await _prefs;
    await prefs.remove(_keyUser);
  }

  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: _keyToken, value: token);
  }

  Future<String?> loadToken() async {
    return _secureStorage.read(key: _keyToken);
  }

  Future<void> clearToken() async {
    await _secureStorage.delete(key: _keyToken);
  }

  Future<void> saveDeviceUuid(String uuid) async {
    await _secureStorage.write(key: _keyDeviceUuid, value: uuid);
    final prefs = await _prefs;
    await prefs.remove(_keyDeviceUuid);
  }

  Future<String?> loadDeviceUuid() async {
    final secureUuid = await _secureStorage.read(key: _keyDeviceUuid);
    if (secureUuid != null && secureUuid.isNotEmpty) return secureUuid;

    final prefs = await _prefs;
    final legacyUuid = prefs.getString(_keyDeviceUuid);
    if (legacyUuid == null || legacyUuid.isEmpty) return null;
    await saveDeviceUuid(legacyUuid);
    return legacyUuid;
  }

  Future<void> saveLanguageCode(String code) async {
    final prefs = await _prefs;
    await prefs.setString(_keyLanguageCode, code);
  }

  Future<String?> loadLanguageCode() async {
    final prefs = await _prefs;
    return prefs.getString(_keyLanguageCode);
  }

  Future<void> clearSession() async {
    await clearToken();
    await clearUser();
  }
}
