import 'dart:async';

import '../core.dart';

/// Base interface for navigation interceptors.
abstract class RouteInterceptor {
  /// Priority of the interceptor. Lower value means higher priority.
  int get priority;

  /// Intercepts the navigation request.
  /// Returns `true` if navigation should proceed.
  /// Returns `false` if navigation should be aborted.
  Future<bool> intercept({required String? routeName, required Object? arguments, required bool needLogin});
}

/// Specialized interceptor for checking authentication status.
class LoginRouteInterceptor implements RouteInterceptor {
  @override
  int get priority => -100; // Runs early

  @override
  Future<bool> intercept({required String? routeName, required Object? arguments, required bool needLogin}) {
    final bool isGuest = AppNavConfig.isGuestCheck?.call() ?? true;

    if (needLogin && isGuest) {
      final context = AppNavConfig.context;
      final loginRedirect = AppNavConfig.onLoginRedirect;
      if (context == null || loginRedirect == null) {
        appLogger.e("LoginRouteInterceptor: Access denied. Missing navigation context or config.");
        return Future.value(false);
      }

      appLogger.d("LoginRouteInterceptor: Access denied. Redirecting to login...");
      final Completer<bool> completer = Completer<bool>();

      void performLoginFlow() {
        loginRedirect(context)
            .then((success) {
              if (success) {
                appLogger.d("LoginRouteInterceptor: Auth success. Proceeding with navigation.");
                AppNavConfig.onLoginSuccessCallback?.call();
                completer.complete(true);
              } else {
                completer.complete(false);
              }
            })
            .catchError((e) {
              appLogger.e("LoginRouteInterceptor: Redirect failed: $e");
              completer.complete(false);
            });
      }

      final showPrompt = AppNavConfig.onShowLoginDialogCallback;
      if (showPrompt != null) {
        showPrompt(context)
            .then((confirmed) {
              if (confirmed) {
                performLoginFlow();
              } else {
                completer.complete(false);
              }
            })
            .catchError((e) {
              completer.complete(false);
            });
      } else {
        performLoginFlow();
      }

      return completer.future;
    }

    return Future.value(true); // No interception needed, proceed
  }
}

final LoginRouteInterceptor loginRouteInterceptor = LoginRouteInterceptor();
