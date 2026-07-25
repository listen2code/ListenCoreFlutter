import 'dart:convert';
import 'package:dio/dio.dart';
import '../../core.dart';

/// Interceptor for logging API requests and responses.
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final buffer = StringBuffer();
    buffer.write('${LogManager.requestTag} [${options.method.toUpperCase()}] => ${options.uri}');

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
    buffer.write('${LogManager.responseTag} [${response.statusCode}] <= ${response.requestOptions.uri}');
    buffer.write('\nData: ${_prettyJson(response.data)}');

    appLogger.i(buffer.toString());
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final buffer = StringBuffer();
    buffer.write('${LogManager.errorTag} [${err.response?.statusCode ?? 'N/A'}] !! ${err.requestOptions.uri}');
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
