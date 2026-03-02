/// Base class for all exceptions in the application
/// Exceptions are thrown at the data layer and converted to Failures at the repository layer
class AppException implements Exception {
  final String message;
  final int? statusCode;

  AppException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class ServerException extends AppException {
  ServerException(super.message, [super.statusCode]);
}

class NetworkException extends AppException {
  NetworkException(super.message);
}

class CacheException extends AppException {
  CacheException(super.message);
}

class AuthException extends AppException {
  AuthException(super.message, [super.statusCode]);
}

class ParseException extends AppException {
  ParseException(super.message);
}
