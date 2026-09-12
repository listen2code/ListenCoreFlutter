/// Abstract base class for domain-level failure representations in Clean Architecture.
///
/// In contrast to low-level exceptions (which carry stack traces and runtime execution halts),
/// [Failure] models are lightweight, immutable data structures returned inside `Left(failure)`
/// of an `Either<Failure, T>`.
///
/// All [Failure] instances implement value equality (`==` and `hashCode`) based on their
/// error content, making them straightforward to assert in unit tests and verify in state transitions.
abstract class Failure {
  /// The user-facing or technical diagnostic message describing the failure.
  final String message;

  const Failure(this.message);

  /// Canonical type name identifier for debugging and APM logging.
  String get typeName => 'Failure';

  @override
  String toString() => '$typeName: $message';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Failure && other.message == message;
  }

  @override
  int get hashCode => message.hashCode;
}

/// Represents a generic remote server or infrastructure failure (HTTP 5xx, gateway timeouts).
class ServerFailure extends Failure {
  const ServerFailure(super.message);

  @override
  String get typeName => 'ServerFailure';
}

/// Represents a business API error explicitly signaled by backend contract JSON envelopes.
///
/// Contains a structured [messageId] (e.g., `BIZ_0500`, `VAL_0401`, `SRV_0100`), which allows
/// [ErrorMapper] to perform localized dictionary translation across languages without coupling
/// presentation code to hardcoded server strings.
class ServerApiFailure extends Failure {
  /// The backend contract error code.
  final String? messageId;

  const ServerApiFailure(super.message, {this.messageId});

  @override
  String get typeName => 'ServerApiFailure';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ServerApiFailure && other.message == message && other.messageId == messageId;
  }

  @override
  int get hashCode => message.hashCode ^ messageId.hashCode;

  @override
  String toString() => '$typeName(message: $message, messageId: $messageId)';
}

/// Represents a physical network or connectivity disruption (offline, timeout, DNS failure).
class NetworkFailure extends Failure {
  const NetworkFailure(super.message);

  @override
  String get typeName => 'NetworkFailure';
}

/// Represents a local cache read/write or deserialization failure.
class CacheFailure extends Failure {
  const CacheFailure(super.message);

  @override
  String get typeName => 'CacheFailure';
}

/// Represents a client-side form or payload validation failure (e.g. invalid email regex).
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);

  @override
  String get typeName => 'ValidationFailure';
}

/// Represents an authentication or authorization failure (e.g. HTTP 401/403, expired session).
///
/// Includes an optional [messageId] for fine-grained login/session localization.
class AuthFailure extends Failure {
  /// The backend contract error code (e.g., `AUTH_0300`, `AUTH_0303`).
  final String? messageId;

  const AuthFailure(super.message, {this.messageId});

  @override
  String get typeName => 'AuthFailure';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthFailure && other.message == message && other.messageId == messageId;
  }

  @override
  int get hashCode => message.hashCode ^ messageId.hashCode;

  @override
  String toString() => '$typeName(message: $message, messageId: $messageId)';
}

/// Represents a JSON or binary data deserialization failure (type mismatch or corrupted payload).
class ParseFailure extends Failure {
  const ParseFailure(super.message);

  @override
  String get typeName => 'ParseFailure';
}

/// Fallback failure when an unclassified exception is encountered in the repository.
class UnknownFailure extends Failure {
  const UnknownFailure(super.message);

  @override
  String get typeName => 'UnknownFailure';
}
