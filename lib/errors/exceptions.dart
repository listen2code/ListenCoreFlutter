/// Base class for all exceptions in the application
/// Exceptions are thrown at the data layer and converted to Failures at the repository layer
class AppException implements Exception {
  final String message;
  final String? messageId;
  final int? statusCode;

  AppException(this.message, [this.messageId, this.statusCode]);

  String get typeName => 'AppException';

  @override
  String toString() => message;
}

class ServerException extends AppException {
  ServerException(super.message, [super.messageId, super.statusCode]);

  @override
  String get typeName => 'ServerException';
}

class NetworkException extends AppException {
  NetworkException(super.message);

  @override
  String get typeName => 'NetworkException';
}

class CacheException extends AppException {
  CacheException(super.message);

  @override
  String get typeName => 'CacheException';
}

class AuthException extends AppException {
  AuthException(super.message, [super.messageId, super.statusCode]);

  @override
  String get typeName => 'AuthException';
}

class ParseException extends AppException {
  ParseException(super.message);

  @override
  String get typeName => 'ParseException';
}
