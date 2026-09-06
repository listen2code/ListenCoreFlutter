import 'package:dio/dio.dart';
import '../../core.dart';

/// Interceptor that intercepts failed HTTP responses/connection issues and maps them to appropriate domain-level AppExceptions.
class ErrorInterceptor extends Interceptor {
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
        final data = err.response?.data;
        String? message;
        String? messageId;

        if (data is Map) {
          message = data[BaseResponseModel.messageKey]?.toString();
          messageId = data[BaseResponseModel.messageIdKey]?.toString();
        } else if (data is String) {
          final trimmed = data.trim();
          if (trimmed.startsWith('<')) {
            // Extract <title> if HTML error page (e.g., Nginx 413, 502, 504)
            final titleMatch = RegExp(r'<title>(.*?)</title>', caseSensitive: false).firstMatch(trimmed);
            if (titleMatch != null && titleMatch.group(1) != null) {
              message = titleMatch.group(1)!.trim();
            }
          } else if (trimmed.isNotEmpty) {
            message = trimmed;
          }
        }

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
        if (statusCode == HttpCode.unauthorized || statusCode == HttpCode.forbidden) {
          exception = AuthException(message!, messageId, statusCode);
        } else if (statusCode != null && statusCode >= HttpCode.internalServerError) {
          exception = ServerException('Internal Server Error: $message', messageId, statusCode);
        } else {
          exception = ServerException(message!, messageId, statusCode);
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

    appLogger.e('${LogManager.errorInterceptorTag}: DioException(${err.type}, statusCode: ${err.response?.statusCode}) -> ${exception.typeName}(${exception.message})');

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
