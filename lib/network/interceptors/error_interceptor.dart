import 'package:dio/dio.dart';
import '../../core.dart';

/// Central HTTP error interceptor for Dio network operations.
///
/// This interceptor captures raw [DioException] failures occurring across the transport layer,
/// extracts error metadata (including backend contract `messageId` and error messages),
/// and maps them into strongly-typed [AppException] instances.
///
/// ### Execution Pipeline and Ordering
/// In Dio's interceptor pipeline:
/// - `onRequest` callbacks execute in registration order.
/// - `onError` callbacks execute in **reverse registration order**.
/// In [ApiClient], `AuthInterceptor` is registered *after* `ErrorInterceptor`. Therefore,
/// on error, `AuthInterceptor` executes *before* `ErrorInterceptor`, giving the authentication
/// layer the first opportunity to silently refresh expired tokens on HTTP 401 and retry requests.
/// If token refresh fails, is bypassed, or another HTTP error occurs, `ErrorInterceptor` processes
/// the terminal error and transforms it for the repository layer.
///
/// ### Resilient Gateway Error Parsing
/// In production architectures, reverse proxies and API gateways (such as Nginx, Cloudflare,
/// or AWS ALB) may emit raw HTML error pages instead of the standard JSON response envelope
/// (e.g. `413 Request Entity Too Large` when uploading large avatars, `502 Bad Gateway`, or
/// `504 Gateway Timeout`).
///
/// Standard JSON decoders will throw a fatal `TypeError` or format exception when attempting
/// to cast an HTML string to `Map<String, dynamic>`. This interceptor uses defensive type checks
/// and regex extraction on HTML `<title>` tags to gracefully salvage meaningful error messages
/// without crashing the application.
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    AppException exception;

    switch (err.type) {
      // 1. Client and Network Timeouts
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        exception = NetworkException('Network connection timeout');
        break;

      // 2. HTTP Bad Responses (4xx / 5xx)
      case DioExceptionType.badResponse:
        final statusCode = err.response?.statusCode;
        final data = err.response?.data;
        String? message;
        String? messageId;

        // Defensive Extraction: Handle both structured JSON (Map) and non-JSON (HTML/String) bodies
        if (data is Map) {
          // Standard API response envelope: { "result": "1", "messageId": "NET_0001", "message": "..." }
          message = data[BaseResponseModel.messageKey]?.toString();
          messageId = data[BaseResponseModel.messageIdKey]?.toString();
        } else if (data is String) {
          final trimmed = data.trim();
          if (trimmed.startsWith('<')) {
            // Defensive parsing: Extract <title> if response is an HTML error page (e.g. Nginx 413, 502, 504)
            // Prevents runtime type errors when parsing non-JSON responses from edge gateways
            final titleMatch = RegExp(r'<title>(.*?)</title>', caseSensitive: false).firstMatch(trimmed);
            if (titleMatch != null && titleMatch.group(1) != null) {
              message = titleMatch.group(1)!.trim();
            }
          } else if (trimmed.isNotEmpty) {
            message = trimmed;
          }
        }

        // Fallback cascades if no descriptive message was obtained
        if (message.isNullOrBlank) {
          message = err.message;
        }
        if (message.isNullOrBlank) {
          if (statusCode != null) {
            message = 'HTTP $statusCode error';
          } else {
            message = 'HTTP bad response';
          }
        }

        // Categorize into domain AppException subtypes based on HTTP status code
        if (statusCode == HttpCode.unauthorized || statusCode == HttpCode.forbidden) {
          exception = AuthException(message!, messageId, statusCode);
        } else if (statusCode != null && statusCode >= HttpCode.internalServerError) {
          exception = ServerException('Internal Server Error: $message', messageId, statusCode);
        } else {
          exception = ServerException(message!, messageId, statusCode);
        }
        break;

      // 3. TLS / SSL Security Exceptions
      case DioExceptionType.badCertificate:
        exception = NetworkException('Bad certificate');
        break;

      // 4. Socket and Connectivity Failures
      case DioExceptionType.connectionError:
        exception = NetworkException('Connection error');
        break;

      // 5. Explicit Request Cancellation (e.g., page popped, ViewModel disposed)
      case DioExceptionType.cancel:
        exception = AppException('Request cancelled');
        break;

      // 6. Data Serialization and Unknown Errors
      case DioExceptionType.transformTimeout:
      case DioExceptionType.unknown:
        var cleanMsg = err.error?.toString();
        if (cleanMsg.isNullOrBlank) {
          cleanMsg = err.message;
        }
        if (cleanMsg.isNullOrBlank) {
          cleanMsg = 'Unknown network exception';
        }
        // Remove common redundant system exception prefixes for cleaner display
        if (cleanMsg!.startsWith('Exception: ')) {
          cleanMsg = cleanMsg.substring('Exception: '.length);
        }
        exception = ServerException(cleanMsg);
        break;
    }

    // Log the error transformation with tag and status details
    appLogger.e(
      '${LogManager.errorInterceptorTag}: DioException(${err.type}, statusCode: ${err.response?.statusCode}) -> ${exception.typeName}(${exception.message})',
    );

    // Forward a cloned DioException packaging our domain AppException inside the error field
    return handler.next(
      DioException(
        requestOptions: err.requestOptions,
        error: exception,
        type: err.type,
        response: err.response,
        message: err.message,
      ),
    );
  }
}
