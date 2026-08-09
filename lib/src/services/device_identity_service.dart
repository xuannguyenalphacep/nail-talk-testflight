import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

import 'storage_service.dart';

class DeviceIdentity {
  DeviceIdentity({
    required this.uuid,
    required this.platform,
    required this.deviceName,
    required this.appVersion,
  });

  final String uuid;
  final String platform;
  final String deviceName;
  final String appVersion;
}

class DeviceIdentityService {
  DeviceIdentityService(this._storageService);

  final StorageService _storageService;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<DeviceIdentity> resolve() async {
    final storedUuid = await _storageService.loadDeviceUuid();
    final deviceUuid = storedUuid ?? const Uuid().v4();
    if (storedUuid == null) {
      await _storageService.saveDeviceUuid(deviceUuid);
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final deviceName = await _resolveDeviceName();

    return DeviceIdentity(
      uuid: deviceUuid,
      platform: _resolvePlatform(),
      deviceName: deviceName,
      appVersion: '${packageInfo.version}+${packageInfo.buildNumber}',
    );
  }

  String _resolvePlatform() {
    if (kIsWeb) {
      return 'web';
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }

  Future<String> _resolveDeviceName() async {
    try {
      if (kIsWeb) {
        final web = await _deviceInfo.webBrowserInfo;
        final browser = web.browserName.name;
        final platform = (web.platform ?? '').toString();
        return '$browser ${platform.trim()}'.trim();
      }

      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = await _deviceInfo.androidInfo;
        return '${android.manufacturer} ${android.model}'.trim();
      }

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = await _deviceInfo.iosInfo;
        return ios.utsname.machine.isNotEmpty ? ios.utsname.machine : ios.name;
      }

      if (defaultTargetPlatform == TargetPlatform.macOS) {
        final macos = await _deviceInfo.macOsInfo;
        return macos.model;
      }

      if (defaultTargetPlatform == TargetPlatform.windows) {
        final windows = await _deviceInfo.windowsInfo;
        return windows.computerName;
      }

      if (defaultTargetPlatform == TargetPlatform.linux) {
        final linux = await _deviceInfo.linuxInfo;
        return linux.prettyName;
      }
    } catch (_) {
      // Ignore and use fallback.
    }

    return 'mobile-chat-device';
  }
}
