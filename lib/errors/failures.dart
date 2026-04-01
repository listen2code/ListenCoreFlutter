/// Base class for all failures in the application
abstract class Failure {
  final String message;

  const Failure(this.message);

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
}

class ServerApiFailure extends Failure {
  final String? messageId;

  const ServerApiFailure(super.message, {this.messageId});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ServerApiFailure && other.message == message && other.messageId == messageId;
  }

  @override
  int get hashCode => message.hashCode ^ messageId.hashCode;

  @override
  String toString() => 'ServerApiFailure(message: $message, messageId: $messageId)';
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

class ParseFailure extends Failure {
  const ParseFailure(super.message);
}

class UnknownFailure extends Failure {
  const UnknownFailure(super.message);
}
