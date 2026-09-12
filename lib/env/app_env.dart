import '../core.dart';

/// Enumeration of supported execution environments.
///
/// Environments dictate the target backend infrastructure, network timeouts,
/// mock server lifecycles, and security safeguards across the application:
/// - [mock]: Fully offline development and testing powered by on-device [LocalMockServer] at `localhost:9999`.
/// - [dev]: Active development environment backed by a remote development server or local Docker container.
/// - [prod]: Production cloud environment (AWS EC2 / S3 / Cloudflare) with stringent security and real databases.
enum AppEnvironment {
  mock(AppEnv.defaultEnv),
  dev('dev'),
  prod('prod');

  /// The serialized string identifier matching `--dart-define=APP_ENV=<name>`.
  final String name;

  const AppEnvironment(this.name);

  /// Resolves an [AppEnvironment] instance from a given [env] string name.
  ///
  /// Falls back safely to [AppEnv.defaultEnv] ('mock') if an unrecognized string is passed.
  static AppEnvironment fromString(String env) {
    return AppEnvironment.values.firstWhere(
      (e) => e.name == env,
      orElse: () => AppEnvironment.values.firstWhere((e) => e.name == AppEnv.defaultEnv),
    );
  }
}

/// Abstract contract defining the infrastructure parameters required for each environment.
///
/// Implementations (e.g. `MockConfig`, `DevConfig`, `ProdConfig`) encapsulate environment-specific
/// endpoints and network resilience parameters.
abstract class BaseEnvConfig {
  /// The specific [AppEnvironment] this configuration describes.
  AppEnvironment get env;

  /// Base HTTP/HTTPS URL for API traffic (e.g. `http://localhost:9999` or `http://13.218.192.181/api`).
  String get baseUrl;

  /// Connection timeout threshold in milliseconds before a [DioExceptionType.connectionTimeout] is thrown.
  int get connectTimeout;

  /// Response receipt timeout threshold in milliseconds before a [DioExceptionType.receiveTimeout] is thrown.
  int get receiveTimeout;

  /// Request send / payload transfer timeout threshold in milliseconds.
  int get apiTimeout;
}

/// Global environment manager orchestrating configuration state and network client parameters.
///
/// ### Architecture & Design Rationale:
/// 1. **Multi-tier Environment Arbitration**:
///    - **Compile-time defaults**: Passed via `--dart-define=APP_ENV=<env>` to set the baseline environment.
///    - **Runtime user overrides**: Developers or QA testers can switch environments dynamically from the
///      in-app Settings page. The selection is persisted into [SpUtil] and takes precedence during subsequent launches.
/// 2. **Process Lifecycle Orchestration**:
///    - Switching into [AppEnvironment.mock] automatically starts the in-app [LocalMockServer].
///    - Switching out of [AppEnvironment.mock] into remote environments gracefully closes the mock server socket.
/// 3. **Dynamic Hot Reconfiguration**:
///    - Whenever the environment changes via [setEnvironment], [ApiClient.dio.options] is updated
///      atomically, allowing immediate network redirection without requiring process termination or restart.
class AppEnv {
  AppEnv._();

  /// Key used to persist user-selected environment preference in [SpUtil].
  static const String envKey = 'env_key';

  /// Compile-time Dart define parameter key (`--dart-define=APP_ENV=...`).
  static const String envDefine = "APP_ENV";

  /// Default fallback environment when neither compile-time flags nor persistent storage specify one.
  static const String defaultEnv = "mock";

  /// Registry map caching environment configurations supplied during bootstrap.
  static Map<AppEnvironment, BaseEnvConfig>? _configs;

  /// Currently active application environment.
  static AppEnvironment _env = AppEnvironment.fromString(
    const String.fromEnvironment(envDefine, defaultValue: defaultEnv),
  );

  /// Initializes the application environment registry.
  ///
  /// [configs] represents the list of configurations passed during app bootstrap.
  ///
  /// **Workflow**:
  /// 1. Caches the environment configurations in an internal lookup map.
  /// 2. Reads persisted environment override from [SpUtil] (if present).
  /// 3. If the resolved environment is [AppEnvironment.mock], starts the [LocalMockServer].
  /// 4. Reconfigures [ApiClient.dio.options] with the active environment's parameters.
  static Future<void> init(List<BaseEnvConfig> configs) async {
    // If already initialized (e.g. during test re-entry), refresh configs and return early without throwing
    if (_configs != null) {
      _configs = {for (var config in configs) config.env: config};
      return;
    }

    _configs = {for (var config in configs) config.env: config};

    final savedEnv = SpUtil.getString(envKey);
    if (savedEnv != null) {
      _env = AppEnvironment.fromString(savedEnv);
    }

    if (_env == AppEnvironment.mock) {
      await LocalMockServer.start();
    }

    _applyDioConfig();
  }

  /// Convenience predicate checking if the current active environment is [AppEnvironment.prod].
  static bool isProd() => _env == AppEnvironment.prod;

  /// Returns the current active [AppEnvironment] enum value.
  static AppEnvironment get currentEnv => _env;

  /// Returns the string representation of the current active environment (e.g. "mock", "dev", "prod").
  static String get env => _env.name;

  /// Returns the active [BaseEnvConfig] descriptor, throwing if uninitialized.
  static BaseEnvConfig get _current {
    final config = _configs?[_env];
    if (config == null) {
      throw Exception(
        "No configuration found for environment: ${_env.name}. Ensure it was provided during initialization.",
      );
    }
    return config;
  }

  /// Switches the active environment dynamically at runtime.
  ///
  /// **Lifecycle Actions**:
  /// - If transitioning away from [AppEnvironment.mock], stops the running [LocalMockServer].
  /// - If transitioning into [AppEnvironment.mock], starts the [LocalMockServer].
  /// - Atomically updates [ApiClient.dio.options] (baseUrl, connectTimeout, receiveTimeout).
  /// - Persists [newEnv] name to [SpUtil] for cold-start restoration.
  static Future<void> setEnvironment(AppEnvironment newEnv) async {
    if (_env == AppEnvironment.mock && newEnv != AppEnvironment.mock) {
      await LocalMockServer.stop();
    }

    if (newEnv == AppEnvironment.mock) {
      await LocalMockServer.start();
    }

    _env = newEnv;
    _applyDioConfig();

    await SpUtil.put(envKey, newEnv.name);
  }

  /// Synchronizes [ApiClient.dio.options] with the current environment parameters.
  static void _applyDioConfig() {
    final config = _current;
    ApiClient.dio.options.baseUrl = config.baseUrl;
    ApiClient.dio.options.connectTimeout = Duration(milliseconds: config.connectTimeout);
    ApiClient.dio.options.receiveTimeout = Duration(milliseconds: config.receiveTimeout);
    ApiClient.dio.options.sendTimeout = Duration(milliseconds: config.apiTimeout);
  }

  /// Current base API URL.
  static String get apiBaseUrl => _current.baseUrl;

  /// Current network API timeout in milliseconds.
  static int get apiTimeout => _current.apiTimeout;

  /// Current connection timeout in milliseconds.
  static int get connectTimeout => _current.connectTimeout;

  /// Current receive timeout in milliseconds.
  static int get receiveTimeout => _current.receiveTimeout;
}
