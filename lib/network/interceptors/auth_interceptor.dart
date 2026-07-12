import 'dart:async';
import 'package:dio/dio.dart';
import '../../core.dart';

/// Interceptor that handles automatic access token injection, token refresh, and request queueing for 401 Unauthorized errors.
class AuthInterceptor extends Interceptor {
  static const String _kIsRefreshedKey = 'is_refreshed';

  bool _isRefreshing = false;
  final List<Completer<void>> _refreshQueue = [];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Check if the request explicitly disables authentication.
    final bool noAuth = options.extra[ApiClient.kNoAuthKey] == true;
    final networkConfig = ApiClient.networkConfig;
    if (!noAuth && networkConfig != null && !networkConfig.visitorPaths.contains(options.path)) {
      await ApiClient.delegate.onInjectAuthHeader(options);
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final is401 = err.response?.statusCode == HttpCode.unauthorized;
    final alreadyRefreshed = err.requestOptions.extra[_kIsRefreshedKey] == true;
    final bool noAuth = err.requestOptions.extra[ApiClient.kNoAuthKey] == true;

    // Do not attempt token refresh if auth is disabled for this request.
    if (is401 && !alreadyRefreshed && !noAuth) {
      appLogger.w('AuthInterceptor: [401] detected for ${err.requestOptions.uri}');

      if (!_isRefreshing) {
        _isRefreshing = true;
        appLogger.i('AuthInterceptor: [REFRESH] -> Starting flow: ${err.requestOptions.uri}');

        try {
          final bool success = await ApiClient.delegate.onRefreshToken();
          _isRefreshing = false;

          if (success) {
            _clearQueueWithComplete();

            final options = err.requestOptions.copyWith();
            options.extra[_kIsRefreshedKey] = true;
            appLogger.i(
              'AuthInterceptor: [REFRESH] -> Success. Retrying original request: ${err.requestOptions.uri}',
            );

            try {
              final response = await ApiClient.dio.fetch(options);
              return handler.resolve(response);
            } catch (retryError) {
              appLogger.e(
                'AuthInterceptor: [RETRY] -> Original request failed after refresh: ${err.requestOptions.uri}',
              );
              return handler.next(retryError is DioException ? retryError : err);
            }
          } else {
            appLogger.i('AuthInterceptor: [REFRESH] -> Failed after refresh: ${err.requestOptions.uri}');
            _clearQueueWithError(err);
          }
        } catch (e) {
          _isRefreshing = false;
          appLogger.e('AuthInterceptor: [REFRESH] -> Exception during refresh: $e');
          _clearQueueWithError(e);
        }
      } else {
        appLogger.i('AuthInterceptor: [QUEUE] -> Refresh in progress, queueing: ${err.requestOptions.uri}');
        final completer = Completer<void>();
        _refreshQueue.add(completer);
        try {
          await completer.future;
          final options = err.requestOptions.copyWith();
          options.extra[_kIsRefreshedKey] = true;
          appLogger.i('AuthInterceptor: [RETRY] -> Retrying queued request: ${err.requestOptions.uri}');
          final response = await ApiClient.dio.fetch(options);
          return handler.resolve(response);
        } catch (_) {
          return handler.next(err);
        }
      }
    }
    return handler.next(err);
  }

  void _clearQueueWithComplete() {
    final queue = List<Completer<void>>.from(_refreshQueue);
    _refreshQueue.clear();
    for (var c in queue) {
      c.complete();
    }
  }

  void _clearQueueWithError(Object error) {
    final queue = List<Completer<void>>.from(_refreshQueue);
    _refreshQueue.clear();
    for (var c in queue) {
      c.completeError(error);
    }
  }
}
