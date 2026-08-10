import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Abstract interface for device information to ensure core logic is testable.
abstract class IDeviceInfo {
  String get deviceId;
  String get model;
  String get version;
  String get platform;
  Map<String, String> toHeaderMap();
}

/// Concrete implementation using the device_info_plus plugin.
class DeviceInfoImpl implements IDeviceInfo {
  final BaseDeviceInfo _info;

  DeviceInfoImpl(this._info);

  static Future<IDeviceInfo> create() async {
    final plugin = DeviceInfoPlugin();
    if (kIsWeb) {
      final webInfo = await plugin.webBrowserInfo;
      return WebDeviceInfoImpl(webInfo);
    }
    if (Platform.isAndroid) {
      return DeviceInfoImpl(await plugin.androidInfo);
    } else if (Platform.isIOS) {
      return DeviceInfoImpl(await plugin.iosInfo);
    }
    return FallbackDeviceInfoImpl();
  }

  @override
  String get deviceId {
    if (_info is AndroidDeviceInfo) return (_info as AndroidDeviceInfo).id;
    if (_info is IosDeviceInfo) return (_info as IosDeviceInfo).identifierForVendor ?? 'unknown';
    return 'unknown';
  }

  @override
  String get model {
    if (_info is AndroidDeviceInfo) return (_info as AndroidDeviceInfo).model;
    if (_info is IosDeviceInfo) return (_info as IosDeviceInfo).utsname.machine;
    return 'unknown';
  }

  @override
  String get version {
    if (_info is AndroidDeviceInfo) return (_info as AndroidDeviceInfo).version.release;
    if (_info is IosDeviceInfo) return (_info as IosDeviceInfo).systemVersion;
    return 'unknown';
  }

  @override
  String get platform => kIsWeb ? 'web' : Platform.operatingSystem;

  @override
  Map<String, String> toHeaderMap() {
    return {
      'X-Device-ID': deviceId,
      'X-Device-Model': model,
      'X-Device-Version': version,
      'X-Platform': platform,
    };
  }
}

class WebDeviceInfoImpl implements IDeviceInfo {
  final WebBrowserInfo info;

  WebDeviceInfoImpl(this.info);

  @override
  String get deviceId => info.vendor ?? 'browser';

  @override
  String get model => info.browserName.name;

  @override
  String get version => info.appVersion ?? 'web';

  @override
  String get platform => 'web';

  @override
  Map<String, String> toHeaderMap() {
    return {
      'X-Device-ID': deviceId,
      'X-Device-Model': model,
      'X-Device-Version': version,
      'X-Platform': platform,
    };
  }
}

class FallbackDeviceInfoImpl implements IDeviceInfo {
  @override
  String get deviceId => 'unknown';
  @override
  String get model => 'unknown';
  @override
  String get version => 'unknown';
  @override
  String get platform => kIsWeb ? 'web' : 'unknown';
  @override
  Map<String, String> toHeaderMap() {
    return {
      'X-Device-ID': deviceId,
      'X-Device-Model': model,
      'X-Device-Version': version,
      'X-Platform': platform,
    };
  }
}
