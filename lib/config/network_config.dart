/// Configuration for network-related settings and HTTP behavior.
/// 
/// This class provides centralized configuration for:
/// - HTTP status code mappings
/// - Public endpoint authentication bypassing
/// - Network client behavior customization
/// 
/// **Example:**
/// ```dart
/// final networkConfig = NetworkConfig(
///   ok: 200,
///   unauthorized: 401,
///   forbidden: 403,
///   internalServerError: 500,
///   visitorPaths: ['/public/data', '/health'],
/// );
/// 
/// ApiClient.initNetworkConfig(networkConfig);
/// ```
/// 
/// **See Also:**
/// - [ApiClient] for HTTP client configuration
/// - [HttpCode] for status code management
class NetworkConfig {
  /// HTTP status code for successful requests.
  /// 
  /// Default: 200 (OK)
  /// Can be customized for APIs that use different success codes.
  final int ok;
  
  /// HTTP status code for unauthorized requests.
  /// 
  /// Default: 401 (Unauthorized)
  /// Triggers token refresh logic when encountered.
  final int unauthorized;
  
  /// HTTP status code for forbidden requests.
  /// 
  /// Default: 403 (Forbidden)
  /// Used when the user lacks permission for a resource.
  final int forbidden;
  
  /// HTTP status code for server errors.
  /// 
  /// Default: 500 (Internal Server Error)
  /// Used for unexpected server-side failures.
  final int internalServerError;

  /// List of public endpoints that don't require authentication.
  /// 
  /// These paths will bypass authentication checks and can be accessed
  /// without valid authentication tokens. Useful for public APIs,
  /// health checks, and public resources.
  /// 
  /// **Example:**
  /// ```dart
  /// visitorPaths: [
  ///   '/public/data',
  ///   '/health',
  ///   '/version',
  ///   '/login',
  /// ]
  /// ```
  final List<String> visitorPaths;

  /// Creates a new network configuration.
  /// 
  /// [ok] HTTP status code for successful requests (default: 200).
  /// [unauthorized] HTTP status code for unauthorized requests (default: 401).
  /// [forbidden] HTTP status code for forbidden requests (default: 403).
  /// [internalServerError] HTTP status code for server errors (default: 500).
  /// [visitorPaths] List of paths that don't require authentication (default: empty).
  /// 
  /// **Example:**
  /// ```dart
  /// const NetworkConfig(
  ///   visitorPaths: ['/public', '/health'],
  /// );
  /// ```
  const NetworkConfig({
    this.ok = 200,
    this.unauthorized = 401,
    this.forbidden = 403,
    this.internalServerError = 500,
    this.visitorPaths = const [],
  });
}
