/// Configuration for network-related settings
class NetworkConfig {
  // HTTP Status Codes
  final int ok;
  final int unauthorized;
  final int forbidden;
  final int internalServerError;

  // Public endpoints that don't require authentication
  final List<String> visitorPaths;

  const NetworkConfig({
    this.ok = 200,
    this.unauthorized = 401,
    this.forbidden = 403,
    this.internalServerError = 500,
    this.visitorPaths = const [],
  });
}
