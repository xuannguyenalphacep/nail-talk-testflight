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
    final prefs = await _prefs;
    await prefs.setString(_keyUser, jsonEncode(user.toJson()));
  }

  Future<SessionUser?> loadUser() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_keyUser);
    if (raw == null || raw.isEmpty) return null;
    return SessionUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> clearUser() async {
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
    final prefs = await _prefs;
    await prefs.setString(_keyDeviceUuid, uuid);
  }

  Future<String?> loadDeviceUuid() async {
    final prefs = await _prefs;
    return prefs.getString(_keyDeviceUuid);
  }

  Future<void> clearSession() async {
    await clearToken();
    await clearUser();
  }
}
