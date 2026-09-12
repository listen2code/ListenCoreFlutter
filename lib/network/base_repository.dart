import 'package:dio/dio.dart';
import '../core.dart';

/// Generic contract for offline caching and persistence data sources.
///
/// Implemented by local data sources (e.g. `ProjectsLocalDataSource`, `AboutMeLocalDataSource`)
/// using persistent storage engines such as SharedPreferences, SQLite, or Hive.
///
/// ### Clean Architecture Role:
/// Resides in the network foundation layer of `ListenCore`. Enables [BaseRepository]
/// to automatically manage two-way cache synchronization without coupling itself
/// to concrete storage mechanisms.
abstract class CacheDataSource<T> {
  /// Persists a clean snapshot of [data] to local storage.
  Future<void> cache(T data);

  /// Retrieves and deserializes the cached snapshot from local storage.
  ///
  /// Returns `null` if no cache exists, the cache has expired, or deserialization fails.
  Future<T?> getCached();
}

/// Architectural mixin providing unified network execution, error normalization,
/// and selective two-level offline cache fallbacks across all domain repositories.
///
/// ### Architectural Rationale:
/// In distributed mobile applications, network requests are susceptible to transient drops,
/// server outages, and intermittent DNS issues. Repeating connectivity checks, try-catch blocks,
/// and cache retrieval in every single repository creates severe boilerplate and drift.
///
/// [BaseRepository] encapsulates this entire resilience lifecycle inside [safeCall]:
/// 1. **Zero-Latency Offline-First**: Instantly serves cached data when offline without invoking Dio.
/// 2. **Transparent Cache Write-Behind**: Automatically persists successful responses.
/// 3. **Defensive Error Demarcation**: Permits cache fallbacks for transient network/timeout errors,
///    but intentionally blocks fallbacks for critical 500 server defects and JSON schema breakages
///    (`TypeError`) to prevent masking server bugs.
mixin BaseRepository {
  /// Internal access to network info without injecting it into every repository.
  NetworkInfo get _networkInfo => Core.networkInfo;

  /// Unified network call wrapper with optional caching support.
  ///
  /// - [call]: The primary remote data source execution closure.
  /// - [saveCache]: Optional callback to execute custom cache/persistence side-effects upon success.
  /// - [cacheDataSource]: Generic [CacheDataSource] to handle get/save logic automatically.
  /// - [useCacheCondition]: Optional predicate to override default fallback rules (e.g., forcing
  ///   cache fallback even during HTTP 500 server errors for static display pages).
  ///
  /// Returns a [Right] with payload [T] upon success or fallback, or a [Left] with a domain [Failure].
  Future<Either<Failure, T>> safeCall<T>({
    required Future<BaseResponseModel<T>> Function() call,
    Future<void> Function(T data)? saveCache,
    CacheDataSource<T>? cacheDataSource,
    bool Function(Failure failure)? useCacheCondition,
  }) async {
    final cachedGetter = cacheDataSource?.getCached;

    // ------------------------------------------------------------------------
    // Phase 1: Pre-flight Connectivity Probe & Zero-RTT Instant Offline Return
    // ------------------------------------------------------------------------
    // In mobile network stacks (Android/iOS), attempting an HTTP socket handshake
    // when completely offline or in flight mode can incur a 10-30 second OS TCP
    // SYN retransmit timeout before throwing a SocketException.
    // By pre-checking [_networkInfo.isConnected], we bypass the network stack
    // entirely and return local cached data with 0ms round-trip latency.
    if (!await _networkInfo.isConnected) {
      if (cachedGetter != null) {
        final cached = await cachedGetter();
        if (cached != null) {
          appLogger.d('${LogManager.repositoryTag}: No connection, returning cached data.');
          return Right(cached);
        }
      }
      return const Left(NetworkFailure('No internet connection'));
    }

    try {
      final response = await call();

      // ----------------------------------------------------------------------
      // Phase 2: Handle Remote Success & Transparent Write-Behind Caching
      // ----------------------------------------------------------------------
      // When the backend returns ApiResult.success, we automatically persist
      // the fresh payload to local storage. This eliminates boilerplate glue code
      // in domain repositories and prevents cache drift.
      if (response.result == ApiResult.success) {
        final data = response.body as T;
        if (saveCache != null) {
          // Priority A: Custom fine-grained persistence closure (e.g. Auth tokens)
          await saveCache(data);
        } else if (cacheDataSource != null) {
          // Priority B: Standardized CacheDataSource contract
          await cacheDataSource.cache(data);
        }
        return Right(data);
      }

      // ----------------------------------------------------------------------
      // Phase 3: Contractual Business Error Normalization
      // ----------------------------------------------------------------------
      // Maps the standard BaseResponseModel envelopes into immutable Failure objects:
      // - sessionTimeout -> AuthFailure (triggers token refresh / login guard)
      // - serverError -> ServerApiFailure (carries backend error messageId for i18n)
      // - other -> generic ServerFailure
      Failure failure;
      if (response.result == ApiResult.sessionTimeout) {
        failure = AuthFailure(response.message ?? 'Session expired');
      } else if (response.result == ApiResult.serverError) {
        failure = ServerApiFailure(response.message ?? 'Server API Error', messageId: response.messageId);
      } else {
        failure = ServerFailure(response.message ?? 'Unknown Server Error');
      }

      return await _handleFailureFallback(failure, cachedGetter, useCacheCondition);
    } on DioException catch (e) {
      // ----------------------------------------------------------------------
      // Phase 4: Network & Transport Error Unrolling
      // ----------------------------------------------------------------------
      final innerError = e.error;
      final errorInfo = innerError is AppException
          ? '${innerError.typeName}: ${innerError.message}'
          : '${e.type}: ${e.message ?? e.error ?? "Unknown network error"}';
      appLogger.e('${LogManager.repositoryTag} API Error [${e.requestOptions.path}]: $errorInfo');
      return await _handleFailureFallback(_mapDioException(e), cachedGetter, useCacheCondition);
    } on TypeError catch (e, t) {
      // ----------------------------------------------------------------------
      // Phase 5: Anti-Corruption Boundary (Zero Tolerance for TypeError)
      // ----------------------------------------------------------------------
      // [CRITICAL DEFENSIVE RULE]: If JSON schema deserialization fails due to a
      // Dart TypeError (e.g. backend altered field types without versioning), we
      // MUST NOT fall back to stale cache. Stale cache masking a schema breakage
      // will lead to severe secondary state crashes downstream.
      appLogger.e('${LogManager.repositoryTag} Data Type Mismatch: $e \n$t');
      return const Left(ParseFailure('Unexpected data format from server'));
    } catch (e, t) {
      // ----------------------------------------------------------------------
      // Phase 6: Unhandled Panic Catch-All
      // ----------------------------------------------------------------------
      appLogger.e('${LogManager.repositoryTag} Unexpected Error: $e \n$t');
      return Left(UnknownFailure(e.toString()));
    }
  }

  /// Internal helper to unwrap and normalize DioException to domain Failure.
  Failure _mapDioException(DioException e) {
    if (e.error is AppException) {
      final appEx = e.error as AppException;
      if (appEx is AuthException) {
        return AuthFailure(appEx.message, messageId: appEx.messageId);
      }
      if (appEx.messageId != null) {
        return ServerApiFailure(appEx.message, messageId: appEx.messageId);
      }
      return ServerFailure(appEx.message);
    }
    return ServerFailure(e.message ?? 'Network Error');
  }

  /// Decides whether to return cached data based on the type of failure.
  ///
  /// ### Defensive Fallback Policy:
  /// - **Transient network drops / timeouts**: Safe to serve stale cache to preserve UX.
  /// - **Business API errors ([ServerApiFailure])**: Allowed to fall back if cached data exists.
  /// - **Critical Infrastructure 500s ([ServerFailure])**: BLOCKED by default! Serving stale
  ///   data during severe backend outages masks critical outages from telemetry and APM alerts.
  ///   Can be explicitly overridden via [useCacheCondition] for static display pages.
  Future<Either<Failure, T>> _handleFailureFallback<T>(
    Failure failure,
    Future<T?> Function()? getCached,
    bool Function(Failure failure)? useCacheCondition,
  ) async {
    if (getCached != null) {
      // Evaluate override condition first, then apply default safety rule:
      final shouldTryCache = useCacheCondition?.call(failure) ?? (failure is! ServerFailure);
      if (shouldTryCache) {
        final cachedData = await getCached();
        if (cachedData != null) {
          appLogger.d('${LogManager.repositoryTag}: Network failed ($failure), falling back to local cache.');
          return Right(cachedData);
        }
      }
    }
    return Left(failure);
  }
}
