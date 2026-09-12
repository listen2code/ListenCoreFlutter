import 'dart:async';

import 'package:flutter/material.dart';

import '../core.dart';

/// Builder function to create a page widget for a specific route path.
typedef RoutePageBuilder = Widget Function();

/// Converter delegate that deserializes a raw query parameter [map]
/// into a strongly-typed routing arguments object of type [T].
/// This enables full decoupling between ListenCore and host application DTOs.
typedef ArgumentConverter<T> = T Function(Map<String, dynamic> map);

/// Global configuration and registry for route interception, authentication hooks,
/// route paths, and supported custom URI schemes.
class AppNavConfig {
  AppNavConfig._();

  /// Global navigator key allowing context-less programmatic navigation from anywhere in the app.
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Convenience getter for the active [BuildContext] associated with the global navigator.
  static BuildContext? get context => navigatorKey.currentContext;

  /// Function delegate to check if the current user session is an unauthenticated guest.
  static bool Function()? isGuestCheck;

  /// Callback delegate to trigger the login flow when an unauthenticated user accesses a protected route.
  static Future<bool> Function(BuildContext context)? onLoginRedirect;

  /// Optional callback invoked upon successful authentication.
  static void Function()? onLoginSuccessCallback;

  /// Optional callback delegate to show an interactive login confirmation dialog.
  static Future<bool> Function(BuildContext context)? onShowLoginDialogCallback;

  /// Registry mapping route path strings to their corresponding [RoutePageBuilder] factories.
  static final Map<String, RoutePageBuilder> _routeRegistry = {};

  /// Registered custom URI schemes (e.g., 'listenportfolio', 'listen', 'myapp')
  /// stripped during deep link resolution.
  static final List<String> _schemes = [];
  static List<String> get schemes => _schemes;

  /// List of registered route interceptors executed prior to route navigation.
  static final List<RouteInterceptor> _interceptors = [];
  static List<RouteInterceptor> get interceptors => _interceptors;

  /// Registers additional route interceptors and sorts them in ascending order of [RouteInterceptor.priority].
  static void registerInterceptors(List<RouteInterceptor> interceptors) {
    _interceptors.addAll(interceptors);
    _interceptors.sort((a, b) => a.priority.compareTo(b.priority));
  }

  /// Central registration entrypoint for configuring routing behaviors, authentication hooks,
  /// route table mappings, and custom URI schemes.
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

    if (!_interceptors.any((i) => i is LoginRouteInterceptor)) {
      registerInterceptors([loginRouteInterceptor]);
    }
  }

  /// Look up the registered page builder factory for the specified route [path].
  static RoutePageBuilder? getBuilder(String path) => _routeRegistry[path];
}

class AppNav {
  AppNav._();

  static final Map<Type, ArgumentConverter<dynamic>> _argumentConverters = {};

  /// Registers a converter function [converter] for a specific target type [T].
  /// When deep links pass query parameters as a [Map<String, dynamic>],
  /// [getArgs<T>()] automatically delegates to this converter to construct
  /// a type-safe arguments instance.
  static void registerArgumentConverter<T>(ArgumentConverter<T> converter) {
    _argumentConverters[T] = converter;
  }

  /// Global snapshot of the currently active route.
  static Route<dynamic>? _currentRoute;

  /// Tracks the route that was most recently pushed or popped during transition.
  static Route<dynamic>? lastTransitionRoute;
  static Route<dynamic>? get currentRoute => _currentRoute;

  /// Global snapshot of the currently active route's name and arguments.
  static String? get currentRouteName => _currentRoute?.settings.name;
  static Object? get currentArgs => _currentRoute?.settings.arguments;

  /// Notifier to listen to route changes (push, pop, or replace).
  static final ValueNotifier<String?> routeChangeNotifier = ValueNotifier(null);

  @visibleForTesting
  static set currentRouteName(String? routeName) {
    _currentRoute = PageRouteBuilder(
      pageBuilder: (_, _, _) => const SizedBox.shrink(),
      settings: RouteSettings(name: routeName, arguments: currentArgs),
    );
    routeChangeNotifier.value = routeName;
  }

  @visibleForTesting
  static set currentArgs(Object? args) {
    _currentRoute = PageRouteBuilder(
      pageBuilder: (_, _, _) => const SizedBox.shrink(),
      settings: RouteSettings(name: currentRouteName, arguments: args),
    );
  }

  /// Combined observer for both Lifecycle tracking and Argument syncing.
  static final RouteObserver<ModalRoute<void>> observer = _AppNavObserver();

  /// Callback hook invoked when a route is pushed.
  static void Function(Route<dynamic> route, Route<dynamic>? previousRoute)? onRoutePushed;

  /// Callback hook invoked when a route is popped.
  static void Function(Route<dynamic> route, Route<dynamic>? previousRoute)? onRoutePopped;

  /// Retrieves a parameter from the current global route state.
  /// Safely usable within initState as it doesn't require BuildContext.
  static T? getParam<T>(String key) {
    if (currentArgs is Map) {
      final val = (currentArgs as Map)[key];
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
    if (currentArgs is T) {
      return currentArgs as T;
    }
    if (currentArgs is Map) {
      final map = Map<String, dynamic>.from(currentArgs as Map);
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

  /// Navigates to a target route (either a [String] path or a [Widget] instance).
  ///
  /// - [target]: The target route path (e.g., '/settings', 'listen://home?tab=aboutMe')
  ///   or a direct [Widget] instance.
  /// - [needLogin]: When true, executes authentication interceptors before pushing.
  /// - [arguments]: Optional custom arguments object or [Map] to pass to the route.
  /// - [replaceIfExists]: When true, if the target route is already the top-most
  ///   active route, replaces it via [pushReplacement] to re-trigger argument processing.
  ///   When false (default), ignores redundant duplicate navigations to prevent UI flickers.
  static Future<T?>? to<T extends Object?>(
    dynamic target, {
    bool needLogin = false,
    Object? arguments,
    bool replaceIfExists = false,
  }) {
    final completer = Completer<T?>();

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

    _runInterceptors(routeName: targetRouteName, arguments: arguments, needLogin: needLogin)
        .then((shouldProceed) {
          if (!shouldProceed) {
            completer.complete(null);
            return;
          }

          final Route<T>? route = _resolveRoute<T>(target, arguments);
          if (route == null) {
            completer.complete(null);
            return;
          }

          // Check if the target route is already the currently active route.
          // If so, we can either perform a pushReplacement or directly return based on the replaceIfExists flag.
          final isAlreadyOnTarget = targetRouteName != null && currentRouteName == targetRouteName;

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
        })
        .catchError((e) {
          appLogger.e('AppNav: Error running interceptors in to(): $e');
          completer.complete(null);
        });

    return completer.future;
  }

  /// Navigates to a target route and replaces the current top-most route in the stack.
  ///
  /// - [target]: Route path [String] or [Widget] instance.
  /// - [needLogin]: If true, enforces authentication interceptor checks.
  /// - [arguments]: Optional arguments to attach to the replaced route.
  static Future<T?>? off<T extends Object?>(dynamic target, {bool needLogin = false, Object? arguments}) {
    final completer = Completer<T?>();

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

    _runInterceptors(routeName: targetRouteName, arguments: arguments, needLogin: needLogin)
        .then((shouldProceed) {
          if (!shouldProceed) {
            completer.complete(null);
            return;
          }

          final Route<T>? route = _resolveRoute<T>(target, arguments);
          if (route == null) {
            completer.complete(null);
            return;
          }
          AppNavConfig.navigatorKey.currentState?.pushReplacement(route).then((value) {
            completer.complete(value);
          });
        })
        .catchError((e) {
          appLogger.e('AppNav: Error running interceptors in off(): $e');
          completer.complete(null);
        });

    return completer.future;
  }

  /// Navigates to a target and removes all previous routes from the stack.
  ///
  /// - [isReplace]: If true, creates a new route and replaces the entire stack (`pushAndRemoveUntil`).
  ///   If false, pops the stack backwards until the target route is reached (target must already exist).
  /// - [needLogin]: If true, checks authentication status before executing stack manipulation.
  static Future<T?>? offAll<T extends Object?>(
    dynamic target, {
    bool needLogin = false,
    bool isReplace = true,
    Object? arguments,
  }) {
    final completer = Completer<T?>();

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

    _runInterceptors(routeName: targetRouteName, arguments: arguments, needLogin: needLogin)
        .then((shouldProceed) {
          if (!shouldProceed) {
            completer.complete(null);
            return;
          }

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
        })
        .catchError((e) {
          appLogger.e('AppNav: Error running interceptors in offAll(): $e');
          completer.complete(null);
        });

    return completer.future;
  }

  /// Pops the top-most route off the navigator, optionally passing a [result] back to the previous route.
  static void back<T extends Object?>([T? result]) => AppNavConfig.navigatorKey.currentState?.pop(result);

  /// Strips any registered custom scheme prefix from [target] (e.g., 'listen://settings' -> '/settings').
  /// Ensures the returned path consistently has a leading slash for route matching.
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

  /// Internal helper to resolve [target] into a Flutter [Route], parsing URI query parameters
  /// into RouteSettings and wrapping page creation with Zone-based APM tracking.
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

  /// Builds a [MaterialPageRoute] for the given [name], wrapping page construction
  /// inside [ZoneManager.runPage] to measure build duration and attach trace context.
  static Route<T>? _buildPageRoute<T>(String name, Object? args) {
    final builder = AppNavConfig.getBuilder(name);
    if (builder == null) return null;
    return MaterialPageRoute<T>(
      // Automatically wrap page construction with performance tracking Zone
      builder: (_) => ZoneManager.runPage(name, () => builder()),
      settings: RouteSettings(name: name, arguments: args),
    );
  }

  /// Executes all registered interceptors sequentially. Returns false if any interceptor halts navigation.
  static Future<bool> _runInterceptors({
    required String? routeName,
    required Object? arguments,
    required bool needLogin,
  }) async {
    for (final interceptor in AppNavConfig.interceptors) {
      final shouldProceed = await interceptor.intercept(
        routeName: routeName,
        arguments: arguments,
        needLogin: needLogin,
      );
      if (!shouldProceed) {
        return false;
      }
    }
    return true;
  }

  /// Helper to trigger the login interception flow explicitly without navigating to a specific target.
  static void tryLogin({required VoidCallback onSuccess, VoidCallback? onFail, bool needLogin = true}) {
    _runInterceptors(routeName: null, arguments: null, needLogin: needLogin)
        .then((shouldProceed) {
          if (shouldProceed) {
            onSuccess();
          } else {
            onFail?.call();
          }
        })
        .catchError((e) {
          appLogger.e('AppNav: Error in tryLogin interceptor execution: $e');
          onFail?.call();
        });
  }
}

/// Internal observer inheriting from RouteObserver to synchronize active route tracking,
/// maintain global [AppNav.currentRoute] and [AppNav.currentRouteName], and notify listeners.
class _AppNavObserver extends RouteObserver<ModalRoute<void>> {
  void _updateRoute(Route<dynamic>? route) {
    AppNav._currentRoute = route;
    AppNav.routeChangeNotifier.value = route?.settings.name;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    AppNav.lastTransitionRoute = route;
    super.didPush(route, previousRoute);
    _updateRoute(route);
    AppNav.onRoutePushed?.call(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    AppNav.lastTransitionRoute = route;
    super.didPop(route, previousRoute);
    _updateRoute(previousRoute);
    AppNav.onRoutePopped?.call(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) {
      AppNav.lastTransitionRoute = newRoute;
    }
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _updateRoute(newRoute);
  }
}
