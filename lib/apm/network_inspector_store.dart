import 'package:flutter/foundation.dart';

/// Represents a captured network HTTP request life-cycle log.
class NetworkRequestEntry {
  final String id;
  final String traceId;
  final String method;
  final String url;
  final String path;
  final Map<String, dynamic> headers;
  final dynamic requestBody;
  final DateTime requestTime;

  final int? statusCode;
  final dynamic responseBody;
  final String? errorMessage;
  final int durationMs;
  final DateTime? responseTime;

  const NetworkRequestEntry({
    required this.id,
    required this.traceId,
    required this.method,
    required this.url,
    required this.path,
    required this.headers,
    this.requestBody,
    required this.requestTime,
    this.statusCode,
    this.responseBody,
    this.errorMessage,
    this.durationMs = 0,
    this.responseTime,
  });

  NetworkRequestEntry copyWith({
    int? statusCode,
    dynamic responseBody,
    String? errorMessage,
    int? durationMs,
    DateTime? responseTime,
  }) {
    return NetworkRequestEntry(
      id: id,
      traceId: traceId,
      method: method,
      url: url,
      path: path,
      headers: headers,
      requestBody: requestBody,
      requestTime: requestTime,
      statusCode: statusCode ?? this.statusCode,
      responseBody: responseBody ?? this.responseBody,
      errorMessage: errorMessage ?? this.errorMessage,
      durationMs: durationMs ?? this.durationMs,
      responseTime: responseTime ?? this.responseTime,
    );
  }
}

/// Dynamic in-memory storage holding captured network transactions.
///
/// Drives reactive updates for the visual network inspector and ensures
/// memory overhead remains bounded.
class NetworkInspectorStore {
  static final NetworkInspectorStore _instance = NetworkInspectorStore._();
  static NetworkInspectorStore get instance => _instance;

  NetworkInspectorStore._();

  static const int maxEntries = 100;
  final List<NetworkRequestEntry> _requests = [];

  /// Notifier powering UI elements listening to network telemetry
  final ValueNotifier<List<NetworkRequestEntry>> requestsNotifier = ValueNotifier([]);

  /// Appends a newly started request to the buffer.
  void addRequest(NetworkRequestEntry entry) {
    if (_requests.length >= maxEntries) {
      _requests.removeAt(0); // Bounded memory management (FIFO)
    }
    _requests.add(entry);
    requestsNotifier.value = List.unmodifiable(_requests);
  }

  /// Updates an existing request record by unique ID (e.g. response arrival or failure).
  void updateRequest(String id, NetworkRequestEntry Function(NetworkRequestEntry) update) {
    final index = _requests.indexWhere((r) => r.id == id);
    if (index != -1) {
      _requests[index] = update(_requests[index]);
      requestsNotifier.value = List.unmodifiable(_requests);
    }
  }

  /// Clears all recorded HTTP transactions.
  void clear() {
    _requests.clear();
    requestsNotifier.value = [];
  }
}
