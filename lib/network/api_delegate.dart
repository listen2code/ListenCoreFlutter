import 'package:dio/dio.dart';
import '../config/network_config.dart';

/// HTTP status codes used throughout the application.
class HttpCode {
  HttpCode._();

  /// HTTP 200 - OK status code.
  static int ok = 200;

  /// HTTP 401 - Unauthorized status code.
  static int unauthorized = 401;

  /// HTTP 403 - Forbidden status code.
  static int forbidden = 403;

  /// HTTP 500 - Internal Server Error status code.
  static int internalServerError = 500;

  /// Updates HTTP status codes from network configuration.
  static void updateConfig(NetworkConfig config) {
    ok = config.ok;
    unauthorized = config.unauthorized;
    forbidden = config.forbidden;
    internalServerError = config.internalServerError;
  }
}

/// Interface for delegating API request lifecycle logic to the shared layer.
abstract class IApiInterceptorDelegate {
  /// Injects authentication headers into the request.
  Future<void> onInjectAuthHeader(RequestOptions options);

  /// Injects common headers (such as Accept-Language) into all requests.
  void onInjectCommonHeaders(RequestOptions options);

  /// Injects tracing identifiers into the request headers.
  void onInjectTraceHeader(RequestOptions options, String traceId);

  /// Handles token refresh logic when a 401 error occurs.
  Future<bool> onRefreshToken();
}

/// A default, no-op implementation of the delegate to prevent null pointer issues.
class DefaultApiDelegate implements IApiInterceptorDelegate {
  @override
  Future<void> onInjectAuthHeader(RequestOptions options) async {
    // Default implementation does nothing
  }

  @override
  void onInjectCommonHeaders(RequestOptions options) {
    // Default implementation does nothing
  }

  @override
  void onInjectTraceHeader(RequestOptions options, String traceId) {
    options.headers['X-Trace-Id'] = traceId;
  }

  @override
  Future<bool> onRefreshToken() async {
    return false;
  }
}
