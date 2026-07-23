/// Base class for all failures in the application
abstract class Failure {
  final String message;

  const Failure(this.message);

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

class ServerFailure extends Failure {
  const ServerFailure(super.message);

  @override
  String get typeName => 'ServerFailure';
}

class ServerApiFailure extends Failure {
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

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);

  @override
  String get typeName => 'NetworkFailure';
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);

  @override
  String get typeName => 'CacheFailure';
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);

  @override
  String get typeName => 'ValidationFailure';
}

class AuthFailure extends Failure {
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

class ParseFailure extends Failure {
  const ParseFailure(super.message);

  @override
  String get typeName => 'ParseFailure';
}

class UnknownFailure extends Failure {
  const UnknownFailure(super.message);

  @override
  String get typeName => 'UnknownFailure';
}
