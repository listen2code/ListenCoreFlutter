import '../core.dart';

enum AppEnvironment {
  mock(AppEnv.defaultEnv),

  dev('dev'),

  test('test'),

  prod('prod');

  final String name;

  const AppEnvironment(this.name);

  static AppEnvironment fromString(String env) {
    return AppEnvironment.values.firstWhere(
      (e) => e.name == env,
      orElse: () => AppEnvironment.values.firstWhere((e) => e.name == AppEnv.defaultEnv),
    );
  }
}

abstract class BaseEnvConfig {
  /// The environment this configuration belongs to.
  AppEnvironment get env;

  String get baseUrl;

  int get connectTimeout;

  int get receiveTimeout;

  int get apiTimeout;
}

class AppEnv {
  AppEnv._();

  static const String envKey = 'env_key';

  static const String envDefine = "APP_ENV";

  static const String defaultEnv = "mock";

  static Map<AppEnvironment, BaseEnvConfig>? _configs;

  static AppEnvironment _env = AppEnvironment.fromString(
    const String.fromEnvironment(envDefine, defaultValue: defaultEnv),
  );

  /// Initializes the application environments.
  /// [configs] A list of configurations, each describing its own [AppEnvironment].
  static Future<void> init(List<BaseEnvConfig> configs) async {
    if (_configs != null) {
      throw Exception("AppEnv has already been initialized.");
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

  static bool isProd() => _env == AppEnvironment.prod;

  static AppEnvironment get currentEnv => _env;

  static String get env => _env.name;

  static BaseEnvConfig get _current {
    final config = _configs?[_env];
    if (config == null) {
      throw Exception(
        "No configuration found for environment: ${_env.name}. Ensure it was provided during initialization.",
      );
    }
    return config;
  }

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

  static void _applyDioConfig() {
    final config = _current;
    ApiClient.dio.options.baseUrl = config.baseUrl;
    ApiClient.dio.options.connectTimeout = Duration(milliseconds: config.connectTimeout);
    ApiClient.dio.options.receiveTimeout = Duration(milliseconds: config.receiveTimeout);
    ApiClient.dio.options.sendTimeout = Duration(milliseconds: config.apiTimeout);
  }

  static String get apiBaseUrl => _current.baseUrl;

  static int get apiTimeout => _current.apiTimeout;

  static int get connectTimeout => _current.connectTimeout;

  static int get receiveTimeout => _current.receiveTimeout;
}
