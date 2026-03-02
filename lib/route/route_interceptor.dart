import 'package:flutter/material.dart';
import '../core.dart';


abstract class _RouteInterceptor {
  /// Priority of the interceptor. Lower value means higher priority.
  int? priority;

  /// Logic to run before navigation.
  Future<T?>? runOnRedirect<T>({Route<T>? toRoute, bool needLogin = false});
}

class CommonRouteInterceptor implements _RouteInterceptor {
  @override
  int? priority = -1;

  @override
  Future<T?>? runOnRedirect<T>({Route<T>? toRoute, bool needLogin = false}) => null;
}

/// Specialized interceptor for checking authentication status.
class LoginRouteInterceptor extends CommonRouteInterceptor {
  @override
  int? get priority => -1;

  @override
  Future<T?>? runOnRedirect<T>({Route<T>? toRoute, bool needLogin = false}) {
    // Check current auth status via registered callback in AppNav config
    final bool isGuest = AppNavConfig.isGuestCheck?.call() ?? true;

    // Intercept navigation if login is required but user is a guest
    if (needLogin && isGuest) {
      final context = AppNavConfig.context;
      if (context != null && AppNavConfig.onLoginRedirect != null) {
        appLogger.d("RouteInterceptor: Access denied. Redirecting to login...");

        // Start login flow and return its completion future
        return AppNavConfig.onLoginRedirect!(context).then((isLoginSuccess) {
          if (isLoginSuccess) {
            appLogger.d("RouteInterceptor: Auth success. Executing target route.");
            AppNavConfig.onLoginSuccessCallback?.call();

            // If there's a target route, perform the push now using global navigator state
            if (toRoute != null && context.mounted) {
              return AppNavConfig.navigatorKey.currentState?.push(toRoute);
            }
            return true as T;
          }
          return false as T;
        });
      } else {
        // Explicitly return false if interception was intended but configuration is missing
        appLogger.e("RouteInterceptor: Interception failed due to missing context or config.");
        return Future.value(false as T);
      }
    }
    return null; // No interception needed
  }
}

class RouteInterceptorRunner {
  RouteInterceptorRunner(this._routeInterceptors);

  final List<CommonRouteInterceptor>? _routeInterceptors;

  List<CommonRouteInterceptor> _getInterceptors() {
    final list = _routeInterceptors ?? <CommonRouteInterceptor>[];
    return list..sort((a, b) => (a.priority ?? 0).compareTo(b.priority ?? 0));
  }

  Future<T?>? runOnRedirect<T>({Route<T>? toRoute, bool needLogin = false}) {
    for (final element in _getInterceptors()) {
      final interceptedResult = element.runOnRedirect(toRoute: toRoute, needLogin: needLogin);
      if (interceptedResult != null) return interceptedResult;
    }

    if (toRoute != null) {
      return AppNavConfig.navigatorKey.currentState?.push(toRoute);
    }

    // Default to true only if no interceptor captured the request
    if (T == bool || T == dynamic) return Future.value(true as T);
    return null;
  }
}

/// Helper function to trigger route redirection logic.
Future<T?>? runOnRedirect<T>({
  Route<T>? toRoute,
  bool needLogin = false,
  List<CommonRouteInterceptor>? extraInterceptors,
}) {
  final runner = RouteInterceptorRunner([...?extraInterceptors, if (needLogin) loginRouteInterceptor]);
  return runner.runOnRedirect(toRoute: toRoute, needLogin: needLogin);
}

final LoginRouteInterceptor loginRouteInterceptor = LoginRouteInterceptor();
