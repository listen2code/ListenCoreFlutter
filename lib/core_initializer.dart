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

  // Provider Registry
  final List<BaseProvider<BaseEffect>>? initialProviders;

  // Network
  final IApiInterceptorDelegate? apiDelegate;

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

  const CoreConfig({
    this.storagePrefix,
    this.onEventFired,
    this.initialProviders,
    this.apiDelegate,
    this.safeModeConfig,
    this.envConfigs,
    this.i18nData,
    this.languageCodeProvider,
    this.routes,
    this.isGuestCheck,
    this.onLoginRedirect,
    this.onLoginSuccessCallback,
    this.onShowLoginDialogCallback,
  });
}

/// The main entry point for the Core module.
class Core {
  Core._();

  /// Initializes all core utilities in the correct order.
  static Future<void> init(CoreConfig config) async {
    // 1. Setup Error Handlers (Infrastructure level)
    _setupGlobalErrorHooks();

    // 2. Setup Storage
    if (config.storagePrefix != null) {
      await SpUtil.init(prefix: config.storagePrefix!);
      await SecureStorageUtil.init(prefix: config.storagePrefix!);
    }

    // 3. Setup Event Bus
    eventBus.init(onEventFired: config.onEventFired ?? (event) => appLogger.d('EventBus: [FIRE] -> $event'));

    // 4. Setup Provider Registry
    if (config.initialProviders != null) {
      ProviderRegistry.init(config.initialProviders!);
    }

    // 5. Setup Network Client
    if (config.apiDelegate != null) {
      ApiClient.init(config.apiDelegate!);
    }

    // 6. Setup Crash Protection
    if (config.safeModeConfig != null) {
      CrashManager.init(config.safeModeConfig!);
    }

    // 7. Setup Environment
    if (config.envConfigs != null) {
      await AppEnv.init(config.envConfigs!);
    }

    // 8. Setup Localization
    if (config.i18nData != null && config.languageCodeProvider != null) {
      Translations.register(data: config.i18nData!, languageCodeProvider: config.languageCodeProvider!);
    }

    // 9. Setup Navigation Config
    if (config.isGuestCheck != null && config.onLoginRedirect != null) {
      AppNavConfig.register(
        routes: config.routes,
        isGuest: config.isGuestCheck!,
        onLogin: config.onLoginRedirect!,
        onLoginSuccess: config.onLoginSuccessCallback,
        onShowLoginDialog: config.onShowLoginDialogCallback,
      );
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
