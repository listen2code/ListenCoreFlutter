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
    final queryParams = request.uri.queryParameters;
    final pathParts = uriPath.split('/').where((p) => p.isNotEmpty).toList();

    // 1. Read Request Headers
    final reqHeaders = <String, dynamic>{};
    request.headers.forEach((name, values) {
      reqHeaders[name] = values.length == 1 ? values.first : values;
    });

    // 2. Read Request Body
    String rawBody = '';
    try {
      rawBody = await utf8.decodeStream(request);
    } catch (e) {
      appLogger.e('MockServer: Error reading body: $e');
    }

    // 3. Combined Request Log (Method, Path, Headers, Query, Body)
    final reqBuffer = StringBuffer();
    reqBuffer.writeln('MockServer: >>> [${request.method.toUpperCase()}] $uriPath');
    reqBuffer.writeln('Request Headers: ${const JsonEncoder.withIndent('  ').convert(reqHeaders)}');
    if (queryParams.isNotEmpty) {
      reqBuffer.writeln('Request Query: ${const JsonEncoder.withIndent('  ').convert(queryParams)}');
    }
    if (rawBody.isNotEmpty) {
      try {
        final dynamic jsonBody = jsonDecode(rawBody);
        reqBuffer.writeln('Request Body:\n${const JsonEncoder.withIndent('  ').convert(jsonBody)}');
      } catch (_) {
        reqBuffer.writeln('Request Body (Raw): $rawBody');
      }
    }
    appLogger.w(reqBuffer.toString().trim());

    // Simulate network latency
    await Future.delayed(const Duration(seconds: 1));

    // 4. Identify version directory (e.g., v1)
    String versionDir = "";
    if (pathParts.isNotEmpty && RegExp(r'^v\d+$').hasMatch(pathParts[0])) {
      versionDir = pathParts[0];
      pathParts.removeAt(0);
    }

    // 5. Build candidate asset paths matching api.js rules
    List<String> candidatePaths = [];
    if (method == 'get') {
      if (pathParts.length > 1) {
        final resource = pathParts[0];
        candidatePaths.add(_buildPath(versionDir, 'get', [resource]));
        candidatePaths.add(_buildPath(versionDir, 'get', pathParts));
      } else if (pathParts.length == 1) {
        final resource = pathParts[0];
        candidatePaths.add(_buildPath(versionDir, 'get/list', [resource]));
        candidatePaths.add(_buildPath(versionDir, 'get', [resource]));
      }
    } else {
      if (pathParts.length > 1) {
        candidatePaths.add(_buildPath(versionDir, method, [pathParts[0]]));
      }
      candidatePaths.add(_buildPath(versionDir, method, pathParts));
    }

    String? jsonData;
    String? matchedPath;

    // 6. Search for the JSON file in app assets
    for (final path in candidatePaths) {
      try {
        jsonData = await rootBundle.loadString(path);
        matchedPath = path;
        break;
      } catch (_) {}
    }

    // 7. Send Response and Log (Status, Asset Path, Headers, Body)
    try {
      if (jsonData != null) {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonData);

        final resHeaders = <String, dynamic>{};
        request.response.headers.forEach((name, values) {
          resHeaders[name] = values.length == 1 ? values.first : values;
        });

        final resBuffer = StringBuffer();
        resBuffer.writeln('MockServer: <<< [200 OK] $uriPath');
        resBuffer.writeln('Matched Asset: $matchedPath');
        resBuffer.writeln('Response Headers: ${const JsonEncoder.withIndent('  ').convert(resHeaders)}');
        try {
          final dynamic decoded = jsonDecode(jsonData);
          resBuffer.writeln('Response JSON:\n${const JsonEncoder.withIndent('  ').convert(decoded)}');
        } catch (_) {
          resBuffer.writeln('Response Body: $jsonData');
        }
        appLogger.w(resBuffer.toString().trim());
      } else {
        throw Exception('Resource not found in assets');
      }
    } catch (e) {
      appLogger.e('MockServer: [404 Not Found] No JSON for $uriPath. Tried: $candidatePaths');
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
