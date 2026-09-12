import 'dart:async';
import 'package:dio/dio.dart';
import '../../core.dart';

/// Interceptor that handles automatic access token injection, token refresh, and request queueing for 401 Unauthorized errors.
///
/// ### Authentication Architecture & Lifecycle:
/// 1. **Token Injection (`onRequest`)**:
///    - Evaluates whether the endpoint requires authentication (`kNoAuthKey` or `visitorPaths`).
///    - Injects the Bearer access token stored in memory/keystore via [ApiClient.delegate.onInjectAuthHeader].
///
/// 2. **Silent Refresh & Concurrent Queueing (`onError`)**:
///    - Detects HTTP 401 Unauthorized responses.
///    - If a refresh flow is already underway, queues pending requests using [Completer] objects.
///    - Initiates a single token refresh request via [ApiClient.delegate.onRefreshToken].
///    - Upon success, flushes the queued requests and retries the original request with the fresh token.
///
/// 3. **Passkey / FIDO2 Alignment**:
///    - In FIDO2/Passkey passwordless authentication flows, hardware-backed cryptographic assertions
///      replace shared password secrets at initial login.
///    - The backend returns standard JWT access and refresh token pairs.
///    - Once acquired, the lifecycle of token injection, automatic refresh, and expiration fallback
///      is uniformly governed by this [AuthInterceptor].
///    - If refresh fails completely (e.g., refresh token expired or revoked), [AuthInterceptor]
///      triggers session termination, redirecting the user to re-authenticate via Passkey (Face ID/Touch ID)
///      or password fallback.
class AuthInterceptor extends Interceptor {
  static const String _tag = LogManager.authInterceptorTag;
  static const String _kIsRefreshedKey = 'is_refreshed';

  bool _isRefreshing = false;
  final List<Completer<void>> _refreshQueue = [];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final bool noAuth = options.extra[ApiClient.kNoAuthKey] == true;
    final networkConfig = ApiClient.networkConfig;
    final bool isVisitorPath = networkConfig != null && networkConfig.visitorPaths.contains(options.path);

    if (!noAuth && !isVisitorPath) {
      await ApiClient.delegate.onInjectAuthHeader(options);
    }

    ApiClient.delegate.onInjectCommonHeaders(options);

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final is401 = err.response?.statusCode == HttpCode.unauthorized;
    final alreadyRefreshed = err.requestOptions.extra[_kIsRefreshedKey] == true;
    final bool noAuth = err.requestOptions.extra[ApiClient.kNoAuthKey] == true;

    // Do not attempt token refresh if auth is disabled for this request.
    if (is401 && !alreadyRefreshed && !noAuth) {
      appLogger.w('$_tag: [401] detected for ${err.requestOptions.uri}');

      if (!_isRefreshing) {
        _isRefreshing = true;
        appLogger.i('$_tag: [REFRESH] -> Starting flow: ${err.requestOptions.uri}');

        try {
          final bool success = await ApiClient.delegate.onRefreshToken();
          _isRefreshing = false;

          if (success) {
            _clearQueueWithComplete();

            final options = err.requestOptions.copyWith();
            options.extra[_kIsRefreshedKey] = true;
            appLogger.i('$_tag: [REFRESH] -> Success. Retrying original request: ${err.requestOptions.uri}');

            try {
              final response = await ApiClient.dio.fetch(options);
              return handler.resolve(response);
            } catch (retryError) {
              appLogger.e(
                '$_tag: [RETRY] -> Original request failed after refresh: ${err.requestOptions.uri}',
              );
              return handler.next(retryError is DioException ? retryError : err);
            }
          } else {
            appLogger.i('$_tag: [REFRESH] -> Failed after refresh: ${err.requestOptions.uri}');
            _clearQueueWithError(err);
          }
        } catch (e) {
          _isRefreshing = false;
          appLogger.e('$_tag: [REFRESH] -> Exception during refresh: $e');
          _clearQueueWithError(e);
        }
      } else {
        // Concurrency defense: Another request is already performing token refresh.
        // Enqueue this request's Completer into the pending queue and await completion.
        appLogger.i('$_tag: [QUEUE] -> Refresh in progress, queueing: ${err.requestOptions.uri}');
        final completer = Completer<void>();
        _refreshQueue.add(completer);
        try {
          // Asynchronously suspends until the lead request succeeds and calls c.complete()
          await completer.future;
          final options = err.requestOptions.copyWith();
          options.extra[_kIsRefreshedKey] = true;
          appLogger.i('$_tag: [RETRY] -> Retrying queued request: ${err.requestOptions.uri}');
          final response = await ApiClient.dio.fetch(options);
          return handler.resolve(response);
        } catch (_) {
          // If the token refresh failed, forward the original 401 error to the caller
          return handler.next(err);
        }
      }
    }
    return handler.next(err);
  }

  /// Atomically drains and resolves all queued requests upon successful token refresh.
  ///
  /// Takes a defensive snapshot copy of the queue before clearing to prevent
  /// concurrent modification exceptions if completion handlers enqueue new operations.
  void _clearQueueWithComplete() {
    final queue = List<Completer<void>>.from(_refreshQueue);
    _refreshQueue.clear();
    for (var c in queue) {
      c.complete();
    }
  }

  /// Atomically drains and rejects all queued requests with the specified error.
  void _clearQueueWithError(Object error) {
    final queue = List<Completer<void>>.from(_refreshQueue);
    _refreshQueue.clear();
    for (var c in queue) {
      c.completeError(error);
    }
  }
}
