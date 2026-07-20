import 'package:dio/dio.dart';
import '../core.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'interceptors/network_inspector_interceptor.dart';
import 'interceptors/zone_context_interceptor.dart';

/// This class provides a centralized HTTP client with built-in features:
/// - Automatic token refresh and request queuing
/// - X-Trace-Id correlation for distributed tracing
/// - Request/response interceptors for logging and error handling
/// - Configurable timeouts and retry logic
///
/// **Example:**
/// ```dart
/// // Initialize with custom delegate
/// final apiClient = ApiClient(
///   baseUrl: 'https://api.example.com',
///   delegate: CustomApiDelegate(),
/// );
///
/// // Make a request
/// final response = await apiClient.get('/users/123');
/// final user = User.fromJson(response.data);
///
/// // Post data
/// final result = await apiClient.post('/users', data: {
///   'name': 'John Doe',
///   'email': 'john@example.com',
/// });
/// ```
///
/// **See Also:**
/// - [IApiInterceptorDelegate] for custom request handling
/// - [NetworkConfig] for HTTP client configuration
/// - [BaseUseCase] for functional error handling
class ApiClient {
  ApiClient._();

  /// Key to specify that a request does not require authentication.
  ///
  /// This constant can be used in the `extra` field of request options
  /// to bypass authentication for specific endpoints like public APIs.
  ///
  /// **Example:**
  /// ```dart
  /// dio.get('/public/data', options: Options(extra: {ApiClient.kNoAuthKey: true}));
  /// ```
  static const String kNoAuthKey = 'no_auth';

  /// The delegate instance for handling API request lifecycle.
  ///
  /// This delegate is used for authentication, tracing, and token refresh.
  /// Defaults to [DefaultApiDelegate] if no custom delegate is set.
  static IApiInterceptorDelegate _delegate = DefaultApiDelegate();

  /// Network configuration for HTTP client settings.
  ///
  /// Contains timeout values, base URLs, and other network-related settings.
  static NetworkConfig? _networkConfig;

  /// Gets the current delegate instance.
  ///
  /// Returns the delegate used for handling API request lifecycle events.
  static IApiInterceptorDelegate get delegate => _delegate;

  /// Gets the current network configuration.
  ///
  /// Returns the network configuration, or null if not initialized.
  static NetworkConfig? get networkConfig => _networkConfig;

  /// Initializes the ApiClient with a concrete delegate implementation.
  ///
  /// This method should be called once during app initialization to set up
  /// custom authentication and request handling behavior.
  ///
  /// [delegate] is the custom delegate implementation for API request handling.
  ///
  /// **Example:**
  /// ```dart
  /// ApiClient.init(CustomApiDelegate());
  /// ```
  static void init(IApiInterceptorDelegate delegate) {
    _delegate = delegate;
  }

  /// Initializes network configuration.
  ///
  /// This method configures HTTP client settings like timeouts and base URLs.
  /// It also updates the HTTP status codes based on the provided configuration.
  ///
  /// [config] is the network configuration containing HTTP client settings.
  ///
  /// **Example:**
  /// ```dart
  /// ApiClient.initNetworkConfig(NetworkConfig(
  ///   connectTimeout: 30000,
  ///   receiveTimeout: 30000,
  /// ));
  /// ```
  static void initNetworkConfig(NetworkConfig config) {
    _networkConfig = config;
    HttpCode.updateConfig(config);
  }

  /// The singleton Dio instance used for all HTTP requests.
  ///
  /// This instance is configured with interceptors for authentication,
  /// logging, error handling, and zone management. It's initialized once
  /// when the class is first accessed.
  static final Dio _dio = _initDio();

  /// Gets the singleton Dio instance.
  ///
  /// Returns the configured Dio instance for making HTTP requests.
  ///
  /// **Example:**
  /// ```dart
  /// final response = await ApiClient.dio.get('/users');
  /// ```
  static Dio get dio => _dio;

  /// Initializes and configures the Dio instance with interceptors.
  ///
  /// This method sets up the HTTP client with:
  /// - Timeouts from environment configuration
  /// - Default headers for JSON content
  /// - Interceptors for request/response processing
  ///
  /// The interceptor order is critical for proper request/response flow:
  /// - Request: Zone -> Error -> Auth -> Logging (in order)
  /// - Error: Logging -> Auth -> Error -> Zone (reverse order)
  ///
  /// Returns a configured Dio instance ready for use.
  static Dio _initDio() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      ),
    );

    // Order matters for logic flow:
    // onRequest: runs in order added (Zone -> Error -> Auth -> Logging)
    // onError: runs in REVERSE order (Logging -> Auth -> Error -> Zone)
    // This ensures:
    // 1. AuthInterceptor is the FIRST to handle onError, allowing it to retry before mapping to AppException.
    // 2. LoggingInterceptor records all attempts.
    // 3. ErrorInterceptor maps the final failed result to domain AppException.
    dio.interceptors.addAll([
      ZoneContextInterceptor(),
      ErrorInterceptor(),
      AuthInterceptor(),
      LoggingInterceptor(),
      NetworkInspectorInterceptor(),
    ]);

    return dio;
  }
}
