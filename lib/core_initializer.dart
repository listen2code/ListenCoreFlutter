import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart' hide RoutePageBuilder;

import 'core.dart';

/// Configuration class for Core module initialization.
class CoreConfig {
  // Storage
  final String? storagePrefix;

  // Event Bus
  final void Function(BaseEvent)? onEventFired;
  final List<BaseProvider<BaseEffect>>? initialProviders;

  // Network
  final IApiInterceptorDelegate? apiDelegate;
  final NetworkConfig? networkConfig;

  // Response
  final ResponseConfig? responseConfig;

  // Crash Manager
  final SafeModeConfig? safeModeConfig;

  // Environment
  final List<BaseEnvConfig>? envConfigs;

  // Localization
  final Map<String, Map<String, String>>? i18nData;
  final String Function()? languageCodeProvider;

  // Navigation & Auth Interception
  final Map<String, RoutePageBuilder>? routes;
  final bool Function()? isGuestCheck;
  final Future<bool> Function(BuildContext context)? onLoginRedirect;
  final void Function()? onLoginSuccessCallback;
  final Future<bool> Function(BuildContext context)? onShowLoginDialogCallback;

  // Mock Server
  final MockServerConfig? mockServerConfig;

  // Logging
  final LogConfig? logConfig;

  // Storage
  final StorageConfig? storageConfig;

  const CoreConfig({
    this.storagePrefix,
    this.onEventFired,
    this.initialProviders,
    this.apiDelegate,
    this.networkConfig,
    this.responseConfig,
    this.safeModeConfig,
    this.envConfigs,
    this.i18nData,
    this.languageCodeProvider,
    this.routes,
    this.isGuestCheck,
    this.onLoginRedirect,
    this.onLoginSuccessCallback,
    this.onShowLoginDialogCallback,
    this.mockServerConfig,
    this.logConfig,
    this.storageConfig,
  });

  /// Creates a default configuration with sensible defaults
  factory CoreConfig.defaultConfig() {
    return CoreConfig(
      networkConfig: const NetworkConfig(),
      responseConfig: const ResponseConfig(),
      mockServerConfig: const MockServerConfig(),
      logConfig: const LogConfig(),
      storageConfig: const StorageConfig(),
    );
  }
}

/// The main entry point for the Core module.
class Core {
  Core._();

  static late final IDeviceInfo deviceInfo;
  static late final IPackageInfo packageInfo;

  /// Initializes all core utilities in the correct order.
  static Future<void> init(CoreConfig config) async {
    // 1. Setup Error Handlers (Infrastructure level)
    _setupGlobalErrorHooks();

    // 2. Setup System Information
    deviceInfo = await DeviceInfoImpl.create();
    packageInfo = await PackageImpl.create();

    // 3. Setup Storage
    final storagePrefix = config.storagePrefix ?? config.storageConfig?.defaultStoragePrefix;
    if (storagePrefix != null) {
      await SpUtil.init(prefix: storagePrefix);
      await SecureStorageUtil.init(prefix: storagePrefix);
    }

    // 4. Setup Event Bus
    eventBus.init(onEventFired: config.onEventFired ?? (event) => appLogger.d('EventBus: [FIRE] -> $event'));

    // 5. Setup Provider Registry
    if (config.initialProviders != null) {
      ProviderRegistry.init(config.initialProviders!);
    }

    // 6. Setup Network Client
    if (config.apiDelegate != null) {
      ApiClient.init(config.apiDelegate!);
    }
    if (config.networkConfig != null) {
      ApiClient.initNetworkConfig(config.networkConfig!);
    }
    if (config.responseConfig != null) {
      BaseResponseModel.initConfig(config.responseConfig!);
    }

    // 7. Setup Crash Protection
    if (config.safeModeConfig != null) {
      CrashManager.init(config.safeModeConfig!);
    }
    if (config.storageConfig != null) {
      CrashManager.initStorageConfig(config.storageConfig!);
    }

    // 8. Setup Environment
    if (config.envConfigs != null) {
      await AppEnv.init(config.envConfigs!);
    }

    // 9. Setup Localization
    if (config.i18nData != null && config.languageCodeProvider != null) {
      Translations.register(data: config.i18nData!, languageCodeProvider: config.languageCodeProvider!);
    }

    // 10. Setup Navigation Config
    if (config.isGuestCheck != null && config.onLoginRedirect != null) {
      AppNavConfig.register(
        routes: config.routes,
        isGuest: config.isGuestCheck!,
        onLogin: config.onLoginRedirect!,
        onLoginSuccess: config.onLoginSuccessCallback,
        onShowLoginDialog: config.onShowLoginDialogCallback,
      );
    }

    // 12. Setup Mock Server Config
    if (config.mockServerConfig != null) {
      LocalMockServer.initConfig(config.mockServerConfig!);
    }

    // 13. Setup Log Config
    if (config.logConfig != null) {
      LogManager.initConfig(config.logConfig!);
    }
  }

  /// Runs the application within a guarded Zone.
  /// Automatically handles crash logging and provides a hook for UI error handling.
  static void run(
    FutureOr<void> Function() body, {
    required Future<void> Function(String? logPath, Object error, StackTrace stack) onAppError,
  }) {
    ZoneManager.runGuarded(
      body,
      onError: (error, stack) async {
        // 1. Automatically persist crash data locally
        final filePath = await CrashManager.saveCrashLog(error, stack);

        // 2. Delegate UI response to the business layer
        await onAppError(filePath, error, stack);
      },
    );
  }

  /// Pipes all Flutter and Platform errors into the current Zone for centralized handling.
  static void _setupGlobalErrorHooks() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      Zone.current.handleUncaughtError(details, details.stack ?? StackTrace.current);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      Zone.current.handleUncaughtError(error, stack);
      return true;
    };
  }
}
