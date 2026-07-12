import 'package:dio/dio.dart';
import '../../core.dart';

/// Interceptor that syncs context from the current Dart Zone (Trace ID and CancelToken).
class ZoneContextInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    ZoneManager.mark('API Request: ${options.uri} Sent');
    ApiClient.delegate.onInjectTraceHeader(options, ZoneManager.currentTraceId);
    final CancelToken? zoneToken = ZoneManager.currentCancelToken;
    if (zoneToken != null && options.cancelToken == null) options.cancelToken = zoneToken;
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    ZoneManager.mark('API Response: ${response.requestOptions.uri} Received');
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    ZoneManager.mark('API Error: ${err.requestOptions.uri}');
    super.onError(err, handler);
  }
}
