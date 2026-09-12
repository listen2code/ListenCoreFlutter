import 'dart:async';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart' hide RoutePageBuilder;

import 'core.dart';

/// Universal composition configuration defining settings for the entire [Core] framework.
///
/// ### Architecture & Composition Root Pattern:
/// [CoreConfig] serves as the single centralized configuration contract between host applications
/// and the generic [ListenCore] framework. By consolidating 13 domain configurations into this immutable
/// value object, [Core] achieves:
/// 1. **Complete Inversion of Control (IoC)**: The core framework remains strictly business-agnostic.
///    It dictates *how* things run (Zone tracing, interceptors, crash capture, route guards), while the host
///    application supplies *what* runs (API delegates, concrete routes, translations, storage prefixes).
/// 2. **Deterministic Startup Clock**: Prevents partial initialization hazards by requiring all infrastructure
///    prerequisites up-front before the UI engine or reactive ViewModels are mounted.
/// 3. **High Reusability Across Apps**: Any new Flutter app can instantiate [CoreConfig] with its own
///    API endpoints, credentials, and assets, instantly inheriting a production-ready enterprise runtime.
class CoreConfig {
  /// Custom namespace prefix applied to all SharedPreferences and SecureStorage keys (e.g., `'MyApp_'`).
  final String? storagePrefix;

  /// Global callback hook invoked whenever any event is published on the central [eventBus].
  final void Function(BaseEvent)? onEventFired;

  /// Initial list of UI effect providers (e.g. ActionSheetProvider, LoadingProvider, ToastProvider).
  final List<BaseProvider<BaseEffect>>? initialProviders;

  /// Custom network delegate handling authentication header injection and token refresh.
  final IApiInterceptorDelegate? apiDelegate;

  /// High-level network options including connect/receive timeouts, visitor paths, and retry rules.
  final NetworkConfig? networkConfig;

  /// Unified response schema configuration defining standard JSON envelope keys (`code`, `data`, `message`).
  final ResponseConfig? responseConfig;

  /// Continuous crash detection threshold and Safe Mode recovery configuration.
  final SafeModeConfig? safeModeConfig;

  /// Multi-environment configuration matrix (Mock, Dev, Test, Prod) containing base URLs and feature flags.
  final List<BaseEnvConfig>? envConfigs;

  /// Multi-language localization dictionary map (`Map<LocaleCode, Map<StringKey, TranslatedString>>`).
  final Map<String, Map<String, String>>? i18nData;

  /// Function closure returning the currently active language code (e.g., `'zh'`, `'en'`, `'ja'`).
  final String Function()? languageCodeProvider;

  /// Static route table mapping URL path strings to page builder closures.
  final Map<String, RoutePageBuilder>? routes;

  /// Predicate closure checking if the active session represents an unauthenticated guest.
  final bool Function()? isGuestCheck;

  /// Route redirection callback triggered when an unauthenticated user navigates to a protected route.
  final Future<bool> Function(BuildContext context)? onLoginRedirect;

  /// Optional callback hook triggered immediately after successful user authentication.
  final void Function()? onLoginSuccessCallback;

  /// Callback hook presenting an in-app modal dialog prompting the user to log in.
  final Future<bool> Function(BuildContext context)? onShowLoginDialogCallback;

  /// Supported deep link URL schemes (e.g. `['listenportfolio', 'myapp']`) stripped during route dispatch.
  final List<String>? schemes;

  /// Configuration for the embedded in-process HTTP mock server.
  final MockServerConfig? mockServerConfig;

  /// In-memory logging ring-buffer capacity and tag filters.
  final LogConfig? logConfig;

  /// File-system storage directories and maximum cache expiration limits.
  final StorageConfig? storageConfig;

  /// Standard fallback UI strings for system alerts, network timeouts, and empty state widgets.
  final CoreUiConfig? uiConfig;

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
    this.schemes,
    this.mockServerConfig,
    this.logConfig,
    this.storageConfig,
    this.uiConfig,
  });

  /// Creates a default configuration with sensible production defaults.
  factory CoreConfig.defaultConfig() {
    return CoreConfig(
      networkConfig: const NetworkConfig(),
      responseConfig: const ResponseConfig(),
      mockServerConfig: const MockServerConfig(),
      logConfig: const LogConfig(),
      storageConfig: const StorageConfig(),
      uiConfig: const CoreUiConfig(),
    );
  }
}

/// The universal architectural foundation and composition root for [ListenCore].
///
/// Orchestrates infrastructure bootstrapping, cross-cutting concerns (logging, APM, crash recovery),
/// and runtime isolation across Dart Zones.
///
/// ### Initialization Sequence:
/// 1. **Global Error Hooks**: Binds `FlutterError.onError` and `PlatformDispatcher.instance.onError` into Zone channels.
/// 2. **Device & Package Telemetry**: Dynamically probes hardware/browser metadata with Web fallback.
/// 3. **Storage Subsystems**: Initializes [SpUtil] and [SecureStorageUtil] with key prefix isolation.
/// 4. **Event Bus & UI Providers**: Mounts the event bus and registers global effect providers (Toasts, Loaders).
/// 5. **Network Stack**: Configures [ApiClient] with 5-stage interceptors, timeouts, and response models.
/// 6. **Safe Mode & Crash Recovery**: Initializes rapid crash counters and local diagnostic loggers.
/// 7. **Environment & Localization**: Binds multi-environment configs and i18n lookup dictionaries.
/// 8. **Navigation & Deep Linking**: Configures [AppNavConfig] route tables, auth guards, and custom schemes.
/// 9. **Mock Server & Logging**: Starts embedded mock routing and in-memory log buffer allocation.
class Core {
  Core._();

  /// Cached device identity and telemetry information.
  static late final IDeviceInfo deviceInfo;

  /// Cached application bundle package metadata (version, build number, package name).
  static late final IPackageInfo packageInfo;

  /// Shared fallback UI string configuration.
  static late final CoreUiConfig uiConfig;

  static NetworkInfo? _networkInfo;

  /// Global network connectivity monitor singleton.
  static NetworkInfo get networkInfo {
    _networkInfo ??= NetworkInfoImpl(Connectivity());
    return _networkInfo!;
  }

  /// Sets an explicit [NetworkInfo] instance (primarily used for unit/widget testing injection).
  static set networkInfo(NetworkInfo value) {
    _networkInfo = value;
  }

  /// Initializes all core utilities in the correct order.
  static Future<void> init(CoreConfig config) async {
    // 0. Setup UI Config (Guard against LateInitializationError on test re-entry)
    try {
      // Check if uiConfig has already been initialized to prevent LateInitializationError on repeated Core.init calls
      uiConfig;
    } catch (_) {
      uiConfig = config.uiConfig ?? const CoreUiConfig();
    }

    // 1. Setup Error Handlers (Infrastructure level)
    _setupGlobalErrorHooks();

    // 2. Setup System Information (Guard against LateInitializationError on test re-entry)
    try {
      deviceInfo;
    } catch (_) {
      deviceInfo = await DeviceInfoImpl.create();
    }
    try {
      packageInfo;
    } catch (_) {
      packageInfo = await PackageImpl.create();
    }

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

    if (config.isGuestCheck != null && config.onLoginRedirect != null) {
      AppNavConfig.register(
        routes: config.routes,
        isGuest: config.isGuestCheck!,
        onLogin: config.onLoginRedirect!,
        onLoginSuccess: config.onLoginSuccessCallback,
        onShowLoginDialog: config.onShowLoginDialogCallback,
        schemes: config.schemes,
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
