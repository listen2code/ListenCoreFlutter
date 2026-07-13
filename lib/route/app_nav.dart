import 'dart:async';

import 'package:flutter/material.dart';

import '../core.dart';

/// Builder function to create a page for a specific route path.
typedef RoutePageBuilder = Widget Function();

typedef ArgumentConverter<T> = T Function(Map<String, dynamic> map);

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

  static final List<String> _schemes = [];
  static List<String> get schemes => _schemes;

  static void register({
    required bool Function() isGuest,
    required Future<bool> Function(BuildContext context) onLogin,
    void Function()? onLoginSuccess,
    Future<bool> Function(BuildContext context)? onShowLoginDialog,
    Map<String, RoutePageBuilder>? routes,
    List<String>? schemes,
  }) {
    isGuestCheck = isGuest;
    onLoginRedirect = onLogin;
    onLoginSuccessCallback = onLoginSuccess;
    onShowLoginDialogCallback = onShowLoginDialog;
    if (routes != null) _routeRegistry.addAll(routes);
    if (schemes != null) {
      _schemes.clear();
      _schemes.addAll(schemes);
    }
  }

  static RoutePageBuilder? getBuilder(String path) => _routeRegistry[path];
}

class AppNav {
  AppNav._();

  static final Map<Type, ArgumentConverter<dynamic>> _argumentConverters = {};

  static void registerArgumentConverter<T>(ArgumentConverter<T> converter) {
    _argumentConverters[T] = converter;
  }

  /// Global snapshot of the currently active route's arguments.
  static Object? _currentArgs;

  static String? _currentRouteName;
  static String? get currentRouteName => _currentRouteName;
  static Object? get currentArgs => _currentArgs;

  /// Notifier to listen to route changes (push, pop, or replace).
  static final ValueNotifier<String?> routeChangeNotifier = ValueNotifier(null);

  @visibleForTesting
  static set currentRouteName(String? routeName) {
    _currentRouteName = routeName;
    routeChangeNotifier.value = routeName;
  }

  @visibleForTesting
  static set currentArgs(Object? args) => _currentArgs = args;

  /// Combined observer for both Lifecycle tracking and Argument syncing.
  static final RouteObserver<ModalRoute<void>> observer = _AppNavObserver();

  /// Callback hook invoked when a route is pushed.
  static void Function(Route<dynamic> route, Route<dynamic>? previousRoute)? onRoutePushed;

  /// Callback hook invoked when a route is popped.
  static void Function(Route<dynamic> route, Route<dynamic>? previousRoute)? onRoutePopped;

  /// Retrieves a parameter from the current global route state.
  /// Safely usable within initState as it doesn't require BuildContext.
  static T? getParam<T>(String key) {
    if (_currentArgs is Map) {
      final val = (_currentArgs as Map)[key];
      if (val is T) return val;
      // Handle string to bool conversion from query params
      if (T == bool && val is String) {
        return (val == 'true') as T;
      }
      return val as T?;
    }
    return null;
  }

  /// Retrieves the entire arguments object from the current global route state.
  /// Seamlessly fallback-decodes Map of query params from Deep Links to type-safe classes using registered converters.
  static T? getArgs<T>() {
    if (_currentArgs is T) {
      return _currentArgs as T;
    }
    if (_currentArgs is Map) {
      final map = Map<String, dynamic>.from(_currentArgs as Map);
      final converter = _argumentConverters[T];
      if (converter != null) {
        return converter(map) as T?;
      }
    }
    return null;
  }

  /// Hook for MaterialApp.onGenerateRoute to handle deep links and initial route
  /// while ensuring ZoneManager coverage and deep-link query parameter parsing.
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final name = settings.name;
    if (name == null) return null;
    return _resolveRoute<dynamic>(name, settings.arguments);
  }

  static Future<T?>? to<T extends Object?>(
    dynamic target, {
    bool needLogin = false,
    Object? arguments,
    bool replaceIfExists = false,
  }) {
    final completer = Completer<T?>();

    tryLogin(
      needLogin: needLogin,
      onSuccess: () {
        final Route<T>? route = _resolveRoute<T>(target, arguments);
        if (route == null) {
          completer.complete(null);
          return;
        }

        String? targetRouteName;
        if (target is Widget) {
          targetRouteName = target.runtimeType.toString();
        } else if (target is String) {
          final cleanTarget = _stripScheme(target);
          if (cleanTarget.contains('?')) {
            targetRouteName = cleanTarget.substring(0, cleanTarget.indexOf('?'));
          } else {
            targetRouteName = cleanTarget;
          }
        }

        // Check if the target route is already the currently active route.
        // If so, we can either perform a pushReplacement or directly return based on the replaceIfExists flag.
        final isAlreadyOnTarget = targetRouteName != null && _currentRouteName == targetRouteName;

        if (isAlreadyOnTarget) {
          if (replaceIfExists) {
            AppNavConfig.navigatorKey.currentState?.pushReplacement(route).then((value) {
              completer.complete(value);
            });
          } else {
            appLogger.i('AppNav: Target route $targetRouteName is already current. Ignoring navigation.');
            completer.complete(null);
          }
        } else {
          AppNavConfig.navigatorKey.currentState?.push(route).then((value) {
            completer.complete(value);
          });
        }
      },
      onFail: () => completer.complete(null),
    );

    return completer.future;
  }

  static Future<T?>? off<T extends Object?>(dynamic target, {bool needLogin = false, Object? arguments}) {
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
  static Future<T?>? offAll<T extends Object?>(
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

  static void back<T extends Object?>([T? result]) => AppNavConfig.navigatorKey.currentState?.pop(result);

  static String _stripScheme(String target) {
    var path = target;
    for (final scheme in AppNavConfig.schemes) {
      final prefix = '$scheme://';
      if (path.startsWith(prefix)) {
        path = path.substring(prefix.length);
        if (!path.startsWith('/')) {
          path = '/$path';
        }
        break;
      }
    }
    return path;
  }

  /// Internal helper to resolve target and extract URI parameters into RouteSettings.
  static Route<T>? _resolveRoute<T>(dynamic target, Object? arguments) {
    if (target is Widget) {
      return MaterialPageRoute<T>(
        builder: (_) => ZoneManager.runPage(target.runtimeType.toString(), () => target),
        settings: RouteSettings(name: target.runtimeType.toString(), arguments: arguments),
      );
    } else if (target is String) {
      final cleanTarget = _stripScheme(target);
      String path;
      final Map<String, dynamic> combinedArgs = {};

      if (cleanTarget.contains('?')) {
        final index = cleanTarget.indexOf('?');
        path = cleanTarget.substring(0, index);
        final queryStr = cleanTarget.substring(index + 1);
        final queryParts = queryStr.split('&');
        for (var part in queryParts) {
          final kv = part.split('=');
          if (kv.length == 2) {
            combinedArgs[kv[0]] = Uri.decodeComponent(kv[1]);
          }
        }
      } else {
        path = cleanTarget;
      }

      if (arguments is Map) {
        combinedArgs.addAll(Map<String, dynamic>.from(arguments));
      } else if (arguments != null && combinedArgs.isEmpty) {
        return _buildPageRoute(path, arguments);
      }

      return _buildPageRoute<T>(path, combinedArgs.isEmpty && arguments != null ? arguments : combinedArgs);
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
  void _updateRoute(String? routeName, Object? arguments) {
    AppNav._currentArgs = arguments;
    AppNav._currentRouteName = routeName;
    AppNav.routeChangeNotifier.value = routeName;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _updateRoute(route.settings.name, route.settings.arguments);
    AppNav.onRoutePushed?.call(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _updateRoute(previousRoute?.settings.name, previousRoute?.settings.arguments);
    AppNav.onRoutePopped?.call(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _updateRoute(newRoute?.settings.name, newRoute?.settings.arguments);
  }
}
