import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../../core.dart';

/// Interceptor that captures HTTP request details and stores them in [NetworkInspectorStore] for visual auditing.
class NetworkInspectorInterceptor extends Interceptor {
  static const String _kInspectorRequestId = 'inspector_request_id';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final requestId = const Uuid().v4();
    options.extra[_kInspectorRequestId] = requestId;

    final entry = NetworkRequestEntry(
      id: requestId,
      traceId: ZoneManager.currentTraceId,
      method: options.method.toUpperCase(),
      url: options.uri.toString(),
      path: options.path,
      headers: Map<String, dynamic>.from(options.headers),
      requestBody: options.data,
      requestTime: DateTime.now(),
    );

    NetworkInspectorStore.instance.addRequest(entry);
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final requestId = response.requestOptions.extra[_kInspectorRequestId] as String?;
    if (requestId != null) {
      final now = DateTime.now();
      NetworkInspectorStore.instance.updateRequest(requestId, (entry) {
        final duration = now.difference(entry.requestTime).inMilliseconds;
        return entry.copyWith(
          statusCode: response.statusCode,
          responseBody: response.data,
          responseTime: now,
          durationMs: duration,
        );
      });
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final requestId = err.requestOptions.extra[_kInspectorRequestId] as String?;
    if (requestId != null) {
      final now = DateTime.now();
      NetworkInspectorStore.instance.updateRequest(requestId, (entry) {
        final duration = now.difference(entry.requestTime).inMilliseconds;
        return entry.copyWith(
          statusCode: err.response?.statusCode ?? 0,
          responseBody: err.response?.data,
          errorMessage: err.message ?? err.error?.toString(),
          responseTime: now,
          durationMs: duration,
        );
      });
    }
    handler.next(err);
  }
}
