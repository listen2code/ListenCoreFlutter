/// Base class for all operational and infrastructure exceptions across the application.
///
/// ### Clean Architecture Boundary
/// In Clean Architecture:
/// - **Data Sources** (HTTP clients, local databases, device sensors) throw [AppException] subtypes.
/// - **Repositories** catch [AppException] (along with [TypeError] and [DioException]) and
///   transform them into domain-level [Failure] abstractions.
/// - **Use Cases** and **ViewModels** only deal with `Either<Failure, T>`, never catching raw exceptions.
///
/// This boundary guarantees that low-level I/O details and external package exceptions do not
/// leak into business logic or UI presentation states.
class AppException implements Exception {
  /// Human-readable diagnostic or fallback message describing the error.
  final String message;

  /// Optional backend-assigned error contract code (e.g., `NET_0001`, `AUTH_0300`, `VAL_0400`).
  /// Used by [ErrorMapper] to look up localized translations in the current user locale.
  final String? messageId;

  /// Optional HTTP status code associated with the failure (e.g., 401, 403, 413, 500).
  final int? statusCode;

  AppException(this.message, [this.messageId, this.statusCode]);

  /// Canonical type name identifier for structured logging and APM telemetry.
  String get typeName => 'AppException';

  @override
  String toString() => message;
}

/// Thrown when the remote server returns an HTTP 5xx error or an unexpected business failure.
class ServerException extends AppException {
  ServerException(super.message, [super.messageId, super.statusCode]);

  @override
  String get typeName => 'ServerException';
}

/// Thrown when network connectivity is lost, DNS resolution fails, or socket connections time out.
class NetworkException extends AppException {
  NetworkException(super.message);

  @override
  String get typeName => 'NetworkException';
}

/// Thrown when local persistent cache (SQLite, SharedPreferences, file storage) read/write fails.
class CacheException extends AppException {
  CacheException(super.message);

  @override
  String get typeName => 'CacheException';
}

/// Thrown when authentication or authorization fails (e.g., HTTP 401 Unauthorized or HTTP 403 Forbidden).
class AuthException extends AppException {
  AuthException(super.message, [super.messageId, super.statusCode]);

  @override
  String get typeName => 'AuthException';
}

/// Thrown when response JSON or binary payload fails deserialization (e.g. schema mutation or type mismatch).
class ParseException extends AppException {
  ParseException(super.message);

  @override
  String get typeName => 'ParseException';
}
