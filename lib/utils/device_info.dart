import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

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
    if (Platform.isAndroid) {
      return DeviceInfoImpl(await plugin.androidInfo);
    } else if (Platform.isIOS) {
      return DeviceInfoImpl(await plugin.iosInfo);
    }
    throw UnsupportedError("Platform not supported");
  }

  @override
  String get deviceId {
    if (_info is AndroidDeviceInfo) return (_info).id;
    if (_info is IosDeviceInfo) return (_info).identifierForVendor ?? 'unknown';
    return 'unknown';
  }

  @override
  String get model {
    if (_info is AndroidDeviceInfo) return (_info).model;
    if (_info is IosDeviceInfo) return (_info).utsname.machine;
    return 'unknown';
  }

  @override
  String get version {
    if (_info is AndroidDeviceInfo) return (_info).version.release;
    if (_info is IosDeviceInfo) return (_info).systemVersion;
    return 'unknown';
  }

  @override
  String get platform => Platform.operatingSystem;

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
