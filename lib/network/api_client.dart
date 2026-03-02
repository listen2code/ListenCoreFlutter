import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import '../core.dart';

class HttpCode {
  HttpCode._();
  static const int ok = 200;
  static const int unauthorized = 401;
  static const int forbidden = 403;
  static const int internalServerError = 500;
}

class ApiResult {
  ApiResult._();

  static const String success = "0";
  static const String serverError = "1";
  static const String sessionTimeout = "3";
}

/// Interface for delegating API request lifecycle logic to the shared layer.
abstract class IApiInterceptorDelegate {
  /// Injects authentication headers into the request.
  Future<void> onInjectAuthHeader(RequestOptions options);

  /// Injects tracing identifiers into the request headers.
  void onInjectTraceHeader(RequestOptions options, String traceId);

  /// Handles token refresh logic when a 401 error occurs.
  Future<bool> onRefreshToken();
}

/// A default, no-op implementation of the delegate to prevent null pointer issues.
class _DefaultApiDelegate implements IApiInterceptorDelegate {
  @override
  Future<void> onInjectAuthHeader(RequestOptions options) async {}

  @override
  void onInjectTraceHeader(RequestOptions options, String traceId) {
    options.headers['X-Trace-Id'] = traceId;
  }

  @override
  Future<bool> onRefreshToken() async => false;
}

/// Creates and configures a single Dio instance for the entire application.
class ApiClient {
  ApiClient._();

  static IApiInterceptorDelegate _delegate = _DefaultApiDelegate();

  static IApiInterceptorDelegate get delegate => _delegate;

  /// Initializes the ApiClient with a concrete delegate implementation.
  static void init(IApiInterceptorDelegate delegate) {
    _delegate = delegate;
  }

  static final Dio _dio = _initDio();

  static Dio get dio => _dio;

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
    // onRequest: runs in order added (Zone -> Error -> Logging -> Auth)
    // onError: runs in REVERSE order (Auth -> Logging -> Error -> Zone)
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
    await ApiClient.delegate.onInjectAuthHeader(options);
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final is401 = err.response?.statusCode == HttpCode.unauthorized;
    final alreadyRefreshed = err.requestOptions.extra[_kIsRefreshedKey] == true;

    if (is401 && !alreadyRefreshed) {
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
        final message = err.response?.data?[BaseResponseModel.kMessage] ?? err.message;
        if (statusCode == HttpCode.unauthorized || statusCode == HttpCode.forbidden) {
          exception = AuthException(message ?? "", statusCode);
        } else if (statusCode != null && statusCode >= HttpCode.internalServerError) {
          exception = ServerException('Internal Server Error: $message', statusCode);
        } else {
          exception = ServerException(message ?? "", statusCode);
        }
        break;
      case DioExceptionType.cancel:
        exception = AppException('Request cancelled');
        break;
      default:
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
