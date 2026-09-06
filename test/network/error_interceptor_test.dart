import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listen_core/core.dart';
import 'package:listen_core/network/interceptors/error_interceptor.dart';

void main() {
  late ErrorInterceptor interceptor;

  setUp(() {
    interceptor = ErrorInterceptor();
  });

  group('ErrorInterceptor Tests', () {
    test('handles JSON Map response body correctly', () {
      DioException? capturedException;

      final requestOptions = RequestOptions(path: '/api/test');
      final dioException = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 400,
          data: {
            'message': 'Custom business error',
            'messageId': 'ERR_001',
          },
        ),
      );

      interceptor.onError(
        dioException,
        ErrorInterceptorHandlerWrapper((e) => capturedException = e),
      );

      expect(capturedException, isNotNull);
      expect(capturedException!.error, isA<ServerException>());
      final serverEx = capturedException!.error as ServerException;
      expect(serverEx.message, 'Custom business error');
      expect(serverEx.messageId, 'ERR_001');
      expect(serverEx.statusCode, 400);
    });

    test('handles HTML String response body (e.g. Nginx 413) without throwing TypeError', () {
      DioException? capturedException;

      final requestOptions = RequestOptions(path: '/api/v1/user/upload-avatar');
      final dioException = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 413,
          data: '<html>\r\n<head><title>413 Request Entity Too Large</title></head>\r\n<body>\r\n<center><h1>413 Request Entity Too Large</h1></center>\r\n<hr><center>nginx/1.30.3</center>\r\n</body>\r\n</html>',
        ),
      );

      interceptor.onError(
        dioException,
        ErrorInterceptorHandlerWrapper((e) => capturedException = e),
      );

      expect(capturedException, isNotNull);
      expect(capturedException!.error, isA<ServerException>());
      final serverEx = capturedException!.error as ServerException;
      expect(serverEx.message, '413 Request Entity Too Large');
      expect(serverEx.statusCode, 413);
    });

    test('handles plain text String response body without throwing TypeError', () {
      DioException? capturedException;

      final requestOptions = RequestOptions(path: '/api/test');
      final dioException = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 500,
          data: 'Service Unavailable Plain Text',
        ),
      );

      interceptor.onError(
        dioException,
        ErrorInterceptorHandlerWrapper((e) => capturedException = e),
      );

      expect(capturedException, isNotNull);
      expect(capturedException!.error, isA<ServerException>());
      final serverEx = capturedException!.error as ServerException;
      expect(serverEx.message, 'Internal Server Error: Service Unavailable Plain Text');
      expect(serverEx.statusCode, 500);
    });

    test('handles 401 unauthorized status with Map response', () {
      DioException? capturedException;

      final requestOptions = RequestOptions(path: '/api/test');
      final dioException = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 401,
          data: {'message': 'Token expired'},
        ),
      );

      interceptor.onError(
        dioException,
        ErrorInterceptorHandlerWrapper((e) => capturedException = e),
      );

      expect(capturedException, isNotNull);
      expect(capturedException!.error, isA<AuthException>());
      final authEx = capturedException!.error as AuthException;
      expect(authEx.message, 'Token expired');
      expect(authEx.statusCode, 401);
    });

    test('handles null data with fallback status message', () {
      DioException? capturedException;

      final requestOptions = RequestOptions(path: '/api/test');
      final dioException = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 502,
          data: null,
        ),
      );

      interceptor.onError(
        dioException,
        ErrorInterceptorHandlerWrapper((e) => capturedException = e),
      );

      expect(capturedException, isNotNull);
      expect(capturedException!.error, isA<ServerException>());
      final serverEx = capturedException!.error as ServerException;
      expect(serverEx.message, 'Internal Server Error: HTTP 502 error');
    });
  });
}

class ErrorInterceptorHandlerWrapper extends ErrorInterceptorHandler {
  final void Function(DioException err) onNextCallback;

  ErrorInterceptorHandlerWrapper(this.onNextCallback);

  @override
  void next(DioException err) {
    onNextCallback(err);
  }
}
