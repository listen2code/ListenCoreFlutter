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
        var message = err.response?.data?[BaseResponseModel.messageKey]?.toString();
        if (message.isNullOrBlank) {
          message = err.message;
        }
        if (message.isNullOrBlank) {
          message = 'HTTP bad response';
        }
        if (statusCode == HttpCode.unauthorized || statusCode == HttpCode.forbidden) {
          exception = AuthException(message!, statusCode);
        } else if (statusCode != null && statusCode >= HttpCode.internalServerError) {
          exception = ServerException('Internal Server Error: $message', statusCode);
        } else {
          exception = ServerException(message!, statusCode);
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

    appLogger.e('ErrorInterceptor: DioException(${err.type}, statusCode: ${err.response?.statusCode}) -> ${exception.typeName}(${exception.message})');

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
