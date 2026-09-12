import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../core.dart';

/// An in-process, lightweight HTTP server running inside the app process on `localhost:9999`.
///
/// ### Architecture & Development Workflow Rationale:
/// Traditional frontend development is frequently blocked by backend development velocity,
/// unstable network environments, or complex sandbox deployment credentials.
///
/// [LocalMockServer] solves this by embedding an RFC-compliant HTTP server within the Dart VM:
/// 1. **Zero-Backend Offline Development**: Serves real HTTP responses parsed directly
///    from assets (`assets/mock/`), enabling full UI development without cloud dependency.
/// 2. **Real Network Stack Exercise**: Traffic flows through the full [Dio] interceptor pipeline,
///    HTTP socket serialization, and JSON deserialization, testing real production network behaviors.
/// 3. **Distributed Trace Correlation**: Extracts incoming `X-Trace-Id` headers and wraps request
///    handling inside a scoped [ZoneManager] zone, ensuring server and client logs share identical
///    trace IDs inside the in-app APM `LogOverlay`.
/// 4. **Dynamic In-Memory State & Multi-Language**: Dynamically mutates user state for avatar uploads
///    and routes localized assets based on `Accept-Language` (`zh`, `ja`) with graceful fallback.
class LocalMockServer {
  /// Internal [HttpServer] socket handle bound to loopback IPv4.
  static HttpServer? _server;

  /// Default loopback port number (9999).
  static int port = 9999;

  /// Volatile in-memory cache simulating database persistence across mutations (e.g. avatar upload).
  static Map<String, dynamic>? _mockedUserBody;

  /// Supported static image extensions and their corresponding MIME `Content-Type`.
  static Map<String, String> _imageExtensions = {
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
    '.gif': 'image/gif',
    '.webp': 'image/webp',
    '.svg': 'image/svg+xml',
  };

  /// Artificial network latency to realistically exercise UI loading indicators and skeletons.
  static Duration _networkLatency = const Duration(seconds: 1);

  /// Base asset path prefix holding mock JSON structures.
  static String _assetsBasePath = 'assets/mock';

  /// Initializes server configuration parameters from [config].
  static void initConfig(MockServerConfig config) {
    port = config.port;
    _imageExtensions = config.imageExtensions;
    _networkLatency = config.networkLatency;
    _assetsBasePath = config.assetsBasePath;
  }

  /// Binds an HTTP server to `127.0.0.1:9999` and listens for incoming client requests.
  ///
  /// **Trace ID Binding**:
  /// Reads `X-Trace-Id` from request headers and executes `_handleRequest` inside a scoped
  /// [ZoneManager.run] zone so all log statements emitted by the server reflect the client's trace context.
  static Future<void> start() async {
    _mockedUserBody = null;
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

  /// Gracefully terminates the running HTTP server and releases socket resources.
  static Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    appLogger.i('MockServer: Local Mock Server stopped');
  }

  /// Core dispatch loop processing incoming HTTP requests.
  ///
  /// **Processing Pipeline**:
  /// 1. Decodes incoming HTTP headers, URL query parameters, and UTF-8 JSON request body.
  /// 2. Emits a combined, indented audit log to [appLogger] (captured by terminal and APM `LogOverlay`).
  /// 3. Injects simulated network latency ([_networkLatency]) to test client-side async UI states.
  /// 4. Serves binary image files if matching `_imageExtensions` under `/images/`.
  /// 5. Handles dynamic state mutation endpoints (e.g. `POST /v1/user/upload-avatar` updates `_mockedUserBody`).
  /// 6. Parses `Accept-Language` header to prioritize localized assets (e.g. `projects_zh.json` -> `projects.json`).
  /// 7. Loads JSON payload from [rootBundle] and streams HTTP 200 response (or returns HTTP 404).
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
    // Formats request metadata into an indented, human-readable audit log.
    // Captured by both terminal stdout and the in-app APM LogOverlay.
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

    // Artificial network latency simulation:
    // Deliberately suspends request processing for [_networkLatency] (default: 1s)
    // to thoroughly exercise UI loading states, shimmer skeletons, and debounce guards.
    await Future.delayed(_networkLatency);

    // -------------------------------------------------------------------------
    // Handler 1: Static Binary Image Asset Streaming
    // -------------------------------------------------------------------------
    // Detects requests directed at static media assets (e.g. `/v1/images/project1.jpg`).
    // Maps the incoming URL to `assets/mock/images/...`, reads the raw bytes from
    // [rootBundle], sets the appropriate MIME Content-Type, and streams the binary data.
    if (uriPath.contains('/images/')) {
      final ext = _imageExtensions.keys.firstWhere(
        (e) => uriPath.toLowerCase().endsWith(e),
        orElse: () => '',
      );

      if (ext.isNotEmpty) {
        // Map URL: /v1/images/project1.jpg -> assets/mock/images/project1.jpg
        // Strips the API version prefix (e.g. `/v1`) to match the physical directory layout
        final relativePath = uriPath.replaceFirst(RegExp(r'^/v\d+'), '');
        final assetPath = '$_assetsBasePath$relativePath';

        try {
          final ByteData data = await rootBundle.load(assetPath);
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.parse(_imageExtensions[ext]!)
            ..add(data.buffer.asUint8List());

          appLogger.w('MockServer: <<< [200 OK] Returned Image: $assetPath');
          await request.response.close();
          return;
        } catch (e) {
          // Fall through to JSON resolution or 404 handler if asset is not found
          appLogger.e('MockServer: Resource not found in assets: $assetPath');
        }
      }
    }

    // -------------------------------------------------------------------------
    // Handler 2: Dynamic In-Memory State Mutation (User Profile & Avatar)
    // -------------------------------------------------------------------------
    // Simulates dynamic state persistence without an on-disk database.
    // When the client uploads an avatar via `POST /v1/user/upload-avatar`:
    // 1. Reads the base `user.json` asset as the canonical user baseline;
    // 2. Patches `avatarUrl` with the newly uploaded Base64 string;
    // 3. Caches the updated payload into [_mockedUserBody] in memory;
    // 4. Subsequent `GET /v1/user` requests return this mutated state, achieving
    //    a complete CRUD round-trip simulation across the offline app lifecycle.
    if (uriPath == '/v1/user/upload-avatar' && method == 'post') {
      try {
        final Map<String, dynamic> requestBody = jsonDecode(rawBody);
        final String? avatarBase64 = requestBody['avatar'];
        if (avatarBase64 != null) {
          // Load baseline user profile from static asset
          final String baseUserJson = await rootBundle.loadString('assets/mock/v1/get/user.json');
          final Map<String, dynamic> userMap = jsonDecode(baseUserJson);
          if (userMap['body'] != null) {
            userMap['body']['avatarUrl'] = avatarBase64;
          }
          _mockedUserBody = userMap;

          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(userMap));
          
          appLogger.w('MockServer: <<< [200 OK] Simulated Upload Avatar dynamically.');
          await request.response.close();
          return;
        }
      } catch (e) {
        appLogger.e('MockServer: Error simulating upload-avatar: $e');
      }
    }

    if (uriPath == '/v1/user' && method == 'get') {
      if (_mockedUserBody != null) {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(_mockedUserBody));
        
        appLogger.w('MockServer: <<< [200 OK] Returned dynamically mocked user data.');
        await request.response.close();
        return;
      }
    }

    // -------------------------------------------------------------------------
    // Handler 3: Localized Static JSON Routing with Graceful Fallback
    // -------------------------------------------------------------------------
    // 1. Extracts API version prefix (e.g., "v1" from "/v1/projects").
    String versionDir = "";
    if (pathParts.isNotEmpty && RegExp(r'^v\d+$').hasMatch(pathParts[0])) {
      versionDir = pathParts[0];
      pathParts.removeAt(0);
    }

    // 2. Inspects `Accept-Language` header to determine client language preference.
    // Extracts primary language tag (`zh` or `ja`). Defaults to English (empty suffix).
    final acceptLang = request.headers.value('accept-language')?.split(',').first.trim().toLowerCase() ?? '';
    String langSuffix = '';
    if (acceptLang.startsWith('zh')) {
      langSuffix = 'zh';
    } else if (acceptLang.startsWith('ja')) {
      langSuffix = 'ja';
    }

    // 3. Generates candidate asset paths ordered by specificity:
    //    Priority 1: Localized sub-resource (e.g. `v1/get/projects_zh.json`)
    //    Priority 2: Fallback non-localized resource (e.g. `v1/get/projects.json`)
    List<String> candidatePaths = [];
    if (pathParts.length > 1) {
      final baseSingle = _buildPath(versionDir, method, [pathParts[0]]);
      if (langSuffix.isNotEmpty) {
        candidatePaths.add(baseSingle.replaceFirst('.json', '_$langSuffix.json'));
      }
      candidatePaths.add(baseSingle);
    }
    final baseAll = _buildPath(versionDir, method, pathParts);
    if (langSuffix.isNotEmpty) {
      candidatePaths.add(baseAll.replaceFirst('.json', '_$langSuffix.json'));
    }
    candidatePaths.add(baseAll);

    String? jsonData;
    String? matchedPath;

    // 4. Sequentially probes rootBundle assets until the first match is loaded.
    for (final path in candidatePaths) {
      try {
        jsonData = await rootBundle.loadString(path);
        matchedPath = path;
        break;
      } catch (_) {}
    }

    // 5. Streams HTTP 200 response with payload, or falls through to 404.
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

  /// Helper to safely construct normalized asset path segments.
  static String _buildPath(String version, String method, List<String> parts) {
    final segments = [_assetsBasePath, if (version.isNotEmpty) version, method, ...parts];
    return '${segments.join('/')}.json'.replaceAll('//', '/');
  }
}
