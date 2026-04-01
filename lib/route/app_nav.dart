import 'dart:async';

import 'package:flutter/material.dart';

import '../core.dart';

/// Builder function to create a page for a specific route path.
typedef RoutePageBuilder = Widget Function();

/// Global configuration for route interception and app-wide navigation settings.
class AppNavConfig {
  AppNavConfig._();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static BuildContext? get context => navigatorKey.currentContext;

  static bool Function()? isGuestCheck;

  static Future<bool> Function(BuildContext context)? onLoginRedirect;

  static void Function()? onLoginSuccessCallback;

  static Future<bool> Function(BuildContext context)? onShowLoginDialogCallback;

  static final Map<String, RoutePageBuilder> _routeRegistry = {};

  static void register({
    required bool Function() isGuest,
    required Future<bool> Function(BuildContext context) onLogin,
    void Function()? onLoginSuccess,
    Future<bool> Function(BuildContext context)? onShowLoginDialog,
    Map<String, RoutePageBuilder>? routes,
  }) {
    isGuestCheck = isGuest;
    onLoginRedirect = onLogin;
    onLoginSuccessCallback = onLoginSuccess;
    onShowLoginDialogCallback = onShowLoginDialog;
    if (routes != null) _routeRegistry.addAll(routes);
  }

  static RoutePageBuilder? getBuilder(String path) => _routeRegistry[path];
}

class AppNav {
  AppNav._();

  /// Global snapshot of the currently active route's arguments.
  static Object? _currentArgs;

  /// Combined observer for both Lifecycle tracking and Argument syncing.
  static final RouteObserver<ModalRoute<void>> observer = _AppNavObserver();

  /// Retrieves a parameter from the current global route state.
  /// Safely usable within initState as it doesn't require BuildContext.
  static T? getParam<T>(String key) {
    if (_currentArgs is Map<String, dynamic>) {
      return (_currentArgs as Map<String, dynamic>)[key] as T?;
    }
    return null;
  }

  /// Retrieves the entire arguments object from the current global route state.
  static T? getArgs<T>() => _currentArgs as T?;

  /// Hook for MaterialApp.onGenerateRoute to handle deep links and initial route
  /// while ensuring ZoneManager coverage for every page.
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final name = settings.name;
    if (name == null) return null;
    return _buildPageRoute(name, settings.arguments);
  }

  static Future<T?>? to<T>(dynamic target, {bool needLogin = false, Object? arguments}) {
    final completer = Completer<T?>();

    tryLogin(
      needLogin: needLogin,
      onSuccess: () {
        final Route<T>? route = _resolveRoute<T>(target, arguments);
        if (route == null) {
          completer.complete(null);
          return;
        }
        AppNavConfig.navigatorKey.currentState?.push(route).then((value) {
          completer.complete(value);
        });
      },
      onFail: () => completer.complete(null),
    );

    return completer.future;
  }

  static Future<T?>? off<T>(dynamic target, {bool needLogin = false, Object? arguments}) {
    final completer = Completer<T?>();

    tryLogin(
      needLogin: needLogin,
      onSuccess: () {
        final Route<T>? route = _resolveRoute<T>(target, arguments);
        if (route == null) {
          completer.complete(null);
          return;
        }
        AppNavConfig.navigatorKey.currentState?.pushReplacement(route).then((value) {
          completer.complete(value);
        });
      },
      onFail: () => completer.complete(null),
    );

    return completer.future;
  }

  /// Navigates to a target and removes all previous routes from the stack.
  /// If [isReplace] is true, creates a new route and replaces the entire stack.
  /// If [isReplace] is false, pops until the target route is reached (target must exist in stack).
  static Future<T?>? offAll<T>(
    dynamic target, {
    bool needLogin = false,
    bool isReplace = true,
    Object? arguments,
  }) {
    final completer = Completer<T?>();

    tryLogin(
      needLogin: needLogin,
      onSuccess: () {
        if (isReplace) {
          // Create new route and replace entire stack
          final Route<T>? route = _resolveRoute<T>(target, arguments);
          if (route == null) {
            completer.complete(null);
            return;
          }
          AppNavConfig.navigatorKey.currentState?.pushAndRemoveUntil(route, (route) => false).then((value) {
            completer.complete(value);
          });
        } else {
          // Pop until target route (must be a String route name)
          if (target is String) {
            AppNavConfig.navigatorKey.currentState?.popUntil((route) {
              return route.settings.name == target;
            });
          }
          completer.complete(null);
        }
      },
      onFail: () => completer.complete(null),
    );

    return completer.future;
  }

  static void back<T>([T? result]) => AppNavConfig.navigatorKey.currentState?.pop(result);

  /// Internal helper to resolve target and extract URI parameters into RouteSettings.
  static Route<T>? _resolveRoute<T>(dynamic target, Object? arguments) {
    if (target is Widget) {
      return MaterialPageRoute<T>(
        builder: (_) => ZoneManager.runPage(target.runtimeType.toString(), () => target),
        settings: RouteSettings(name: target.runtimeType.toString(), arguments: arguments),
      );
    } else if (target is String) {
      String path;
      final Map<String, dynamic> combinedArgs = {};

      if (target.contains('?')) {
        final index = target.indexOf('?');
        path = target.substring(0, index);
        final queryStr = target.substring(index + 1);
        final queryParts = queryStr.split('&');
        for (var part in queryParts) {
          final kv = part.split('=');
          if (kv.length == 2) {
            combinedArgs[kv[0]] = kv[1];
          }
        }
      } else {
        path = target;
      }

      if (arguments is Map) {
        combinedArgs.addAll(Map<String, dynamic>.from(arguments));
      } else if (arguments != null && combinedArgs.isEmpty) {
        return _buildPageRoute(path, arguments);
      }

      return _buildPageRoute<T>(path, combinedArgs);
    }
    return null;
  }

  static Route<T>? _buildPageRoute<T>(String name, Object? args) {
    final builder = AppNavConfig.getBuilder(name);
    if (builder == null) return null;
    return MaterialPageRoute<T>(
      // Automatically wrap page construction with performance tracking Zone
      builder: (_) => ZoneManager.runPage(name, () => builder()),
      settings: RouteSettings(name: name, arguments: args),
    );
  }

  static void tryLogin({required VoidCallback onSuccess, VoidCallback? onFail, bool needLogin = true}) {
    final bool isGuest = AppNavConfig.isGuestCheck?.call() ?? true;
    if (needLogin && isGuest) {
      final context = AppNavConfig.context;
      final loginRedirect = AppNavConfig.onLoginRedirect;
      if (context == null || loginRedirect == null) return;

      void performLoginFlow() {
        loginRedirect(context).then((success) {
          if (success) {
            AppNavConfig.onLoginSuccessCallback?.call();
            onSuccess();
          } else {
            onFail?.call();
          }
        });
      }

      final showPrompt = AppNavConfig.onShowLoginDialogCallback;
      if (showPrompt != null) {
        showPrompt(context).then((confirmed) {
          if (confirmed) {
            performLoginFlow();
          } else {
            onFail?.call();
          }
        });
      } else {
        performLoginFlow();
      }
    } else {
      onSuccess();
    }
  }
}

/// Internal observer inheriting from RouteObserver to support both arguments syncing and RouteAware lifecycle.
class _AppNavObserver extends RouteObserver<ModalRoute<void>> {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    AppNav._currentArgs = route.settings.arguments;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    AppNav._currentArgs = previousRoute?.settings.arguments;
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    AppNav._currentArgs = newRoute?.settings.arguments;
  }
}
