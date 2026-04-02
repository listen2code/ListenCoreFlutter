import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../core.dart';

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../core.dart';

/// HTTP status codes used throughout the application.
/// 
/// This class provides centralized management of HTTP status codes
/// that can be configured through [NetworkConfig]. Default values follow
/// standard HTTP conventions.
/// 
/// **Example:**
/// ```dart
/// if (response.statusCode == HttpCode.ok) {
///   // Handle success
/// } else if (response.statusCode == HttpCode.unauthorized) {
///   // Handle authentication error
/// }
/// ```
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
  /// 
  /// This method is called during initialization to apply custom
  /// status code values from the provided configuration.
  /// 
  /// [config] is the network configuration containing custom status codes.
  static void updateConfig(NetworkConfig config) {
    ok = config.ok;
    unauthorized = config.unauthorized;
    forbidden = config.forbidden;
    internalServerError = config.internalServerError;
  }
}

/// Interface for delegating API request lifecycle logic to the shared layer.
/// 
/// This interface allows customization of request handling behavior,
/// particularly for authentication, tracing, and token management.
/// Implementations can be provided to [ApiClient] to customize how
/// requests are processed.
/// 
/// **Example:**
/// ```dart
/// class CustomApiDelegate implements IApiInterceptorDelegate {
///   @override
///   Future<void> onInjectAuthHeader(RequestOptions options) async {
///     final token = await _authService.getAccessToken();
///     if (token != null) {
///       options.headers['Authorization'] = 'Bearer $token';
///     }
///   }
///   
///   @override
///   Future<bool> onRefreshToken() async {
///     return await _authService.refreshToken();
///   }
/// }
/// ```
abstract class IApiInterceptorDelegate {
  /// Injects authentication headers into the request.
  /// 
  /// This method is called before each request to add authentication
  /// information like bearer tokens, API keys, or other auth headers.
  /// 
  /// [options] is the request options that can be modified with auth headers.
  /// 
  /// **Throws:** May throw exceptions if authentication fails.
  Future<void> onInjectAuthHeader(RequestOptions options);

  /// Injects tracing identifiers into the request headers.
  /// 
  /// This method adds correlation IDs and other tracing information
  /// to enable distributed tracing across microservices.
  /// 
  /// [options] is the request options that will be modified with tracing headers.
  /// [traceId] is the unique identifier for this request trace.
  void onInjectTraceHeader(RequestOptions options, String traceId);

  /// Handles token refresh logic when a 401 error occurs.
  /// 
  /// This method is called when the API returns a 401 Unauthorized
  /// response, indicating that the current token has expired or is invalid.
  /// 
  /// Returns `true` if the token was successfully refreshed and the request
  /// should be retried, `false` if the refresh failed and the request should fail.
  /// 
  /// **Example:**
  /// ```dart
  /// @override
  /// Future<bool> onRefreshToken() async {
  ///   try {
  ///     await _authService.refreshToken();
  ///     return true;
  ///   } catch (e) {
  ///     return false;
  ///   }
  /// }
  /// ```
  Future<bool> onRefreshToken();
}

/// A default, no-op implementation of the delegate to prevent null pointer issues.
/// 
/// This implementation provides safe default behavior for all delegate methods.
/// It's used as a fallback when no custom delegate is provided to [ApiClient].
/// 
/// - Authentication: No headers are added
/// - Tracing: X-Trace-Id header is added
/// - Token refresh: Always returns false (no refresh attempt)
class _DefaultApiDelegate implements IApiInterceptorDelegate {
  @override
  Future<void> onInjectAuthHeader(RequestOptions options) async {
    // Default implementation does nothing
  }

  @override
  void onInjectTraceHeader(RequestOptions options, String traceId) {
    // Add trace ID header for distributed tracing
    options.headers['X-Trace-Id'] = traceId;
  }

  @override
  Future<bool> onRefreshToken() async {
    // Default implementation doesn't attempt token refresh
    return false;
  }
}

/// Creates and configures a single Dio instance for the entire application.
/// 
/// This class provides a centralized HTTP client with built-in features:
/// - Automatic token refresh and request queuing
/// - X-Trace-Id correlation for distributed tracing
/// - Request/response interceptors for logging and error handling
/// - Configurable timeouts and retry logic
/// 
/// **Example:**
/// ```dart
/// // Initialize with custom delegate
/// final apiClient = ApiClient(
///   baseUrl: 'https://api.example.com',
///   delegate: CustomApiDelegate(),
/// );
/// 
/// // Make a request
/// final response = await apiClient.get('/users/123');
/// final user = User.fromJson(response.data);
/// 
/// // Post data
/// final result = await apiClient.post('/users', data: {
///   'name': 'John Doe',
///   'email': 'john@example.com',
/// });
/// ```
/// 
/// **See Also:**
/// - [IApiInterceptorDelegate] for custom request handling
/// - [NetworkConfig] for HTTP client configuration
/// - [BaseUseCase] for functional error handling
class ApiClient {
  ApiClient._();

  /// Key to specify that a request does not require authentication.
  /// 
  /// This constant can be used in the `extra` field of request options
  /// to bypass authentication for specific endpoints like public APIs.
  /// 
  /// **Example:**
  /// ```dart
  /// dio.get('/public/data', options: Options(extra: {ApiClient.kNoAuthKey: true}));
  /// ```
  static const String kNoAuthKey = 'no_auth';

  /// The delegate instance for handling API request lifecycle.
  /// 
  /// This delegate is used for authentication, tracing, and token refresh.
  /// Defaults to [_DefaultApiDelegate] if no custom delegate is set.
  static IApiInterceptorDelegate _delegate = _DefaultApiDelegate();
  
  /// Network configuration for HTTP client settings.
  /// 
  /// Contains timeout values, base URLs, and other network-related settings.
  static NetworkConfig? _networkConfig;

  /// Gets the current delegate instance.
  /// 
  /// Returns the delegate used for handling API request lifecycle events.
  static IApiInterceptorDelegate get delegate => _delegate;
  
  /// Gets the current network configuration.
  /// 
  /// Returns the network configuration, or null if not initialized.
  static NetworkConfig? get networkConfig => _networkConfig;

  /// Initializes the ApiClient with a concrete delegate implementation.
  /// 
  /// This method should be called once during app initialization to set up
  /// custom authentication and request handling behavior.
  /// 
  /// [delegate] is the custom delegate implementation for API request handling.
  /// 
  /// **Example:**
  /// ```dart
  /// ApiClient.init(CustomApiDelegate());
  /// ```
  static void init(IApiInterceptorDelegate delegate) {
    _delegate = delegate;
  }

  /// Initializes network configuration.
  /// 
  /// This method configures HTTP client settings like timeouts and base URLs.
  /// It also updates the HTTP status codes based on the provided configuration.
  /// 
  /// [config] is the network configuration containing HTTP client settings.
  /// 
  /// **Example:**
  /// ```dart
  /// ApiClient.initNetworkConfig(NetworkConfig(
  ///   connectTimeout: 30000,
  ///   receiveTimeout: 30000,
  /// ));
  /// ```
  static void initNetworkConfig(NetworkConfig config) {
    _networkConfig = config;
    HttpCode.updateConfig(config);
  }

  /// The singleton Dio instance used for all HTTP requests.
  /// 
  /// This instance is configured with interceptors for authentication,
  /// logging, error handling, and zone management. It's initialized once
  /// when the class is first accessed.
  static final Dio _dio = _initDio();

  /// Gets the singleton Dio instance.
  /// 
  /// Returns the configured Dio instance for making HTTP requests.
  /// 
  /// **Example:**
  /// ```dart
  /// final response = await ApiClient.dio.get('/users');
  /// ```
  static Dio get dio => _dio;

  /// Initializes and configures the Dio instance with interceptors.
  /// 
  /// This method sets up the HTTP client with:
  /// - Timeouts from environment configuration
  /// - Default headers for JSON content
  /// - Interceptors for request/response processing
  /// 
  /// The interceptor order is critical for proper request/response flow:
  /// - Request: Zone -> Error -> Auth -> Logging (in order)
  /// - Error: Logging -> Auth -> Error -> Zone (reverse order)
  /// 
  /// Returns a configured Dio instance ready for use.
  static Dio _initDio() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: Duration(milliseconds: AppEnv.connectTimeout),
        receiveTimeout: Duration(milliseconds: AppEnv.receiveTimeout),
        sendTimeout: Duration(milliseconds: AppEnv.apiTimeout),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      ),
    );

    // Order matters for logic flow:
    // onRequest: runs in order added (Zone -> Error -> Auth -> Logging)
    // onError: runs in REVERSE order (Logging -> Auth -> Error -> Zone)
    // This ensures:
    // 1. AuthInterceptor is the FIRST to handle onError, allowing it to retry before mapping to AppException.
    // 2. LoggingInterceptor records all attempts.
    // 3. ErrorInterceptor maps the final failed result to domain AppException.
    dio.interceptors.addAll([
      _ZoneContextInterceptor(),
      _ErrorInterceptor(),
      _AuthInterceptor(),
      _LoggingInterceptor(),
    ]);

    return dio;
  }
}

/// Interceptor for logging API requests and responses.
/// 
/// This interceptor provides detailed logging of all HTTP traffic including:
/// - Request method, URL, headers, and body
/// - Response status code and data
/// - Error information and response bodies
/// 
/// All logs are formatted with pretty-printed JSON for better readability.
class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final buffer = StringBuffer();
    buffer.write('🌐 REQUEST [${options.method.toUpperCase()}] => ${options.uri}');

    if (options.headers.isNotEmpty) {
      buffer.write('\nHeaders: {');
      options.headers.forEach((key, value) => buffer.write('\n  $key: $value'));
      buffer.write('\n}');
    }

    if (options.data != null) {
      buffer.write('\nBody: ${_prettyJson(options.data)}');
    }

    appLogger.i(buffer.toString());
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final buffer = StringBuffer();
    buffer.write('✅ RESPONSE [${response.statusCode}] <= ${response.requestOptions.path}');
    buffer.write('\nData: ${_prettyJson(response.data)}');

    appLogger.i(buffer.toString());
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final buffer = StringBuffer();
    buffer.write('❌ ERROR [${err.response?.statusCode ?? 'N/A'}] !! ${err.requestOptions.path}');
    buffer.write('\nMessage: ${err.message}');
    if (err.response?.data != null) {
      buffer.write('\nError Body: ${_prettyJson(err.response?.data)}');
    }

    appLogger.e(buffer.toString());
    super.onError(err, handler);
  }

  String _prettyJson(dynamic json) {
    if (json == null) return 'null';
    try {
      const encoder = JsonEncoder.withIndent('  ');
      if (json is String) {
        return encoder.convert(jsonDecode(json));
      }
      return encoder.convert(json);
    } catch (_) {
      return json.toString();
    }
  }
}

/// Interceptor that syncs context from the current Dart Zone (Trace ID and CancelToken).
class _ZoneContextInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    ZoneManager.mark('API Request: ${options.path} Sent');
    ApiClient.delegate.onInjectTraceHeader(options, ZoneManager.currentTraceId);
    final CancelToken? zoneToken = ZoneManager.currentCancelToken;
    if (zoneToken != null && options.cancelToken == null) options.cancelToken = zoneToken;
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    ZoneManager.mark('API Response: ${response.requestOptions.path} Received');
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    ZoneManager.mark('API Error: ${err.requestOptions.path}');
    super.onError(err, handler);
  }
}

class _AuthInterceptor extends Interceptor {
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
      appLogger.w('AuthInterceptor: [401] detected for ${err.requestOptions.path}');

      if (!_isRefreshing) {
        _isRefreshing = true;
        appLogger.i('AuthInterceptor: [REFRESH] -> Starting flow: ${err.requestOptions.path}');

        try {
          final bool success = await ApiClient.delegate.onRefreshToken();
          _isRefreshing = false;

          if (success) {
            _clearQueueWithComplete();

            final options = err.requestOptions.copyWith();
            options.extra[_kIsRefreshedKey] = true;
            appLogger.i(
              'AuthInterceptor: [REFRESH] -> Success. Retrying original request: ${err.requestOptions.path}',
            );

            try {
              final response = await ApiClient.dio.fetch(options);
              return handler.resolve(response);
            } catch (retryError) {
              appLogger.e(
                'AuthInterceptor: [RETRY] -> Original request failed after refresh: ${err.requestOptions.path}',
              );
              return handler.next(retryError is DioException ? retryError : err);
            }
          } else {
            appLogger.i('AuthInterceptor: [REFRESH] -> Failed after refresh: ${err.requestOptions.path}');
            _clearQueueWithError(err);
          }
        } catch (e) {
          _isRefreshing = false;
          appLogger.e('AuthInterceptor: [REFRESH] -> Exception during refresh: $e');
          _clearQueueWithError(e);
        }
      } else {
        appLogger.i('AuthInterceptor: [QUEUE] -> Refresh in progress, queueing: ${err.requestOptions.path}');
        final completer = Completer<void>();
        _refreshQueue.add(completer);
        try {
          await completer.future;
          final options = err.requestOptions.copyWith();
          options.extra[_kIsRefreshedKey] = true;
          appLogger.i('AuthInterceptor: [RETRY] -> Retrying queued request: ${err.requestOptions.path}');
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

class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    AppException exception;
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        exception = NetworkException('Network connection timeout');
        break;
      case DioExceptionType.badResponse:
        final statusCode = err.response?.statusCode;
        final message = err.response?.data?[BaseResponseModel.messageKey] ?? err.message;
        if (statusCode == HttpCode.unauthorized || statusCode == HttpCode.forbidden) {
          exception = AuthException(message ?? "", statusCode);
        } else if (statusCode != null && statusCode >= HttpCode.internalServerError) {
          exception = ServerException('Internal Server Error: $message', statusCode);
        } else {
          exception = ServerException(message ?? "", statusCode);
        }
        break;
      case DioExceptionType.badCertificate:
        exception = NetworkException('Bad certificate');
        break;
      case DioExceptionType.connectionError:
        exception = NetworkException('Connection error');
        break;
      case DioExceptionType.cancel:
        exception = AppException('Request cancelled');
        break;
      case DioExceptionType.unknown:
        exception = ServerException(err.toString());
    }

    appLogger.e('ErrorInterceptor: [${err.type}] mapped to ${exception.runtimeType}: ${exception.message}');

    return handler.next(
      DioException(
        requestOptions: err.requestOptions,
        error: exception,
        type: err.type,
        response: err.response,
      ),
    );
  }
}
