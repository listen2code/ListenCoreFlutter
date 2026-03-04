import 'package:package_info_plus/package_info_plus.dart';

/// Abstract interface for application information (version, build number, etc.)
abstract class IPackageInfo {
  String get appName;
  String get packageName;
  String get version;
  String get buildNumber;

  /// Returns a combined version string (e.g., "1.0.0+1")
  String get fullVersion;

  Map<String, String> toHeaderMap();
}

/// Concrete implementation using the package_info_plus plugin.
class PackageImpl implements IPackageInfo {
  final PackageInfo _info;

  PackageImpl(this._info);

  static Future<IPackageInfo> create() async {
    final info = await PackageInfo.fromPlatform();
    return PackageImpl(info);
  }

  @override
  String get appName => _info.appName;

  @override
  String get packageName => _info.packageName;

  @override
  String get version => _info.version;

  @override
  String get buildNumber => _info.buildNumber;

  @override
  String get fullVersion => '$version+$buildNumber';

  @override
  Map<String, String> toHeaderMap() {
    return {'X-App-Version': version, 'X-App-Build': buildNumber, 'X-App-Package': packageName};
  }
}
