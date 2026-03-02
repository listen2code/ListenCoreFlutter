import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import '../core.dart';

/// A lightweight HTTP server running inside the app to provide real network responses.
/// Path resolution logic is synchronized with tools/api/api.js structure.
class LocalMockServer {
  static HttpServer? _server;
  static const int port = 9999;

  /// Starts the server on localhost:9999
  static Future<void> start() async {
    if (_server != null) return;

    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      appLogger.i('MockServer: Local Mock Server started at http://localhost:$port');

      _server!.listen((HttpRequest request) async {
        // Read traceId from headers to correlate with client logs
        final String? traceId = request.headers.value('X-Trace-Id');

        // Run the request handler in a specific zone with the traceId.
        // We set silent: true because this is a local helper and we don't need a separate summary.
        ZoneManager.run(() => _handleRequest(request), traceId: traceId, silent: true);
      });
    } catch (e) {
      appLogger.e('MockServer: Failed to start Local Mock Server: $e');
    }
  }

  /// Stops the running server
  static Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    appLogger.i('MockServer: Local Mock Server stopped');
  }

  static Future<void> _handleRequest(HttpRequest request) async {
    final method = request.method.toLowerCase();
    final uriPath = request.uri.path;
    final pathParts = uriPath.split('/').where((p) => p.isNotEmpty).toList();

    // Simulate network latency (approx. 2 seconds)
    await Future.delayed(const Duration(seconds: 2));

    // 1. Read and log Request Body
    String requestBody = '';
    try {
      requestBody = await utf8.decoder.bind(request).join();
    } catch (e) {
      appLogger.e('MockServer: Error reading request body: $e');
    }

    appLogger.w('MockServer: >>> [${request.method.toUpperCase()}] $uriPath');
    if (requestBody.isNotEmpty) {
      try {
        final dynamic jsonBody = json.decode(requestBody);
        appLogger.w('MockServer: [Request Body]:\n${const JsonEncoder.withIndent('  ').convert(jsonBody)}');
      } catch (_) {
        appLogger.e('MockServer: [Request Body (Raw)]: $requestBody');
      }
    }

    // 2. Identify version directory (e.g., v1)
    String versionDir = "";
    if (pathParts.isNotEmpty && RegExp(r'^v\d+$').hasMatch(pathParts[0])) {
      versionDir = pathParts[0];
      pathParts.removeAt(0);
    }

    // 3. Build candidate asset paths matching api.js rules
    List<String> candidatePaths = [];
    if (method == 'get') {
      candidatePaths.add(_buildPath(versionDir, 'get/list', pathParts));
      candidatePaths.add(_buildPath(versionDir, 'get', pathParts));
    } else {
      candidatePaths.add(_buildPath(versionDir, method, pathParts));
    }

    String? jsonData;
    String? matchedPath;

    // 4. Search for the JSON file in app assets
    for (final path in candidatePaths) {
      try {
        jsonData = await rootBundle.loadString(path);
        matchedPath = path;
        break;
      } catch (_) {
        // Not found in this candidate path
      }
    }

    try {
      if (jsonData != null) {
        appLogger.w('MockServer: [200 OK] Found asset: $matchedPath');

        // Log Response JSON for debugging
        try {
          final dynamic responseObj = json.decode(jsonData);
          appLogger.w(
            'MockServer: [Response JSON]:\n${const JsonEncoder.withIndent('  ').convert(responseObj)}',
          );
        } catch (_) {
          appLogger.e('MockServer: [Response Data]: $jsonData');
        }

        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonData);
      } else {
        throw Exception('Resource not found in assets');
      }
    } catch (e) {
      appLogger.e(
        'MockServer: [404 Not Found] No JSON for ${request.method} $uriPath. Tried: $candidatePaths',
      );
      request.response
        ..statusCode = HttpStatus.notFound
        ..write(jsonEncode({'result': '1', 'message': 'Mock file not found', 'uri': uriPath}));
    } finally {
      await request.response.close();
    }
  }

  /// Helper to join path segments safely
  static String _buildPath(String version, String method, List<String> parts) {
    final segments = ['assets/mock', if (version.isNotEmpty) version, method, ...parts];
    return '${segments.join('/')}.json'.replaceAll('//', '/');
  }
}
