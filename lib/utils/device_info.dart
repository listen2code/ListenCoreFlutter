import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Abstract interface for device identity and telemetry information.
///
/// ### Architecture & Design Rationale (Interface Segregation):
/// In accordance with the Dependency Inversion Principle (DIP) and Interface
/// Segregation Principle (ISP), application business logic (ViewModels, Interceptors)
/// should depend upon abstractions rather than concrete third-party SDKs.
///
/// By exposing [IDeviceInfo], callers are shielded from the underlying implementation.
/// Currently, the implementation delegates to the `device_info_plus` community plugin.
/// However, this interface establishes a clean boundary:
/// - **Zero-Breaking-Change Native Migration**: When transitioning from `device_info_plus`
///   to a custom lightweight `MethodChannel`, only [DeviceInfoImpl.create] needs modification.
///   All upstream consumers (HTTP interceptors, APM collectors, tests) remain untouched.
/// - **Unit Testability**: Mock implementations can be effortlessly substituted without
///   mocking complex native platform channels or plugin internals.
abstract class IDeviceInfo {
  /// Unique device identifier (e.g. Android ID, iOS identifierForVendor, or browser vendor token).
  String get deviceId;

  /// Hardware or browser model description (e.g. "Pixel 8 Pro", "iPhone15,2", "Chrome").
  String get model;

  /// Operating system or platform release version (e.g. "14", "17.4", "122.0").
  String get version;

  /// Operating system category name (e.g. "android", "ios", "web", "unknown").
  String get platform;

  /// Formats device telemetry into standardized HTTP header key-value pairs.
  ///
  /// Injected by `NetworkInspectorInterceptor` into outgoing API requests for
  /// backend APM tracing, device auditing, and security anomaly detection:
  /// - `X-Device-ID`: Device unique hardware or vendor identifier.
  /// - `X-Device-Model`: Hardware model name.
  /// - `X-Device-Version`: OS version.
  /// - `X-Platform`: Target OS family.
  Map<String, String> toHeaderMap();
}

/// Concrete implementation of [IDeviceInfo] backed by the `device_info_plus` plugin.
///
/// Handles asynchronous platform queries and routes platform-specific data models
/// ([AndroidDeviceInfo], [IosDeviceInfo], [WebBrowserInfo]) into the unified [IDeviceInfo] contract.
class DeviceInfoImpl implements IDeviceInfo {
  /// Internal untyped base device information returned by `device_info_plus`.
  final BaseDeviceInfo _info;

  /// Internal constructor wrapping a platform-specific [BaseDeviceInfo].
  DeviceInfoImpl(this._info);

  /// Asynchronously queries platform APIs and returns an initialized [IDeviceInfo] instance.
  ///
  /// Evaluates compilation target flags ([kIsWeb]) and runtime OS probes ([Platform.isAndroid],
  /// [Platform.isIOS]) to dynamically instantiate the corresponding device adapter.
  ///
  /// **Migration Blueprint**:
  /// When replacing `device_info_plus` with a native `MethodChannel('com.listen.portfolio/device_info')`:
  /// ```dart
  /// static Future<IDeviceInfo> create() async {
  ///   if (kIsWeb) return WebDeviceInfoImpl(...);
  ///   final data = await const MethodChannel('device_info').invokeMapMethod<String, String>('getDeviceInfo');
  ///   return NativeDeviceInfoImpl(data ?? {});
  /// }
  /// ```
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
    if (_info is AndroidDeviceInfo) return _info.id;
    if (_info is IosDeviceInfo) return _info.identifierForVendor ?? 'unknown';
    return 'unknown';
  }

  @override
  String get model {
    if (_info is AndroidDeviceInfo) return _info.model;
    if (_info is IosDeviceInfo) return _info.utsname.machine;
    return 'unknown';
  }

  @override
  String get version {
    if (_info is AndroidDeviceInfo) return _info.version.release;
    if (_info is IosDeviceInfo) return _info.systemVersion;
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

/// Web-specific device info adapter extracting browser and user-agent metadata.
class WebDeviceInfoImpl implements IDeviceInfo {
  /// Wrapped browser metadata parsed from `window.navigator`.
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

/// Fallback device info adapter used in unsupported host environments (e.g. desktop tests, Linux).
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
