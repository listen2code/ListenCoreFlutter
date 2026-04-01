import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../core.dart';

mixin BaseRepository {
  /// Internal access to network info without injecting it into every repository.
  NetworkInfo get _networkInfo => NetworkInfoImpl(Connectivity());

  /// Unified network call wrapper with optional caching support.
  /// - [call]: The primary remote data source execution.
  /// - [saveCache]: Optional callback to persist data upon successful network response.
  /// - [getCached]: Optional callback to retrieve stale data if the network fails.
  /// - [useCacheCondition]: Optional filter to decide if specific Failures should trigger cache fallback.
  Future<Either<Failure, T>> safeCall<T>({
    required Future<BaseResponseModel<T>> Function() call,
    Future<void> Function(T data)? saveCache,
    Future<T?> Function()? getCached,
    bool Function(Failure failure)? useCacheCondition,
  }) async {
    // 1. Connectivity Check & Immediate Cache Fallback
    if (!await _networkInfo.isConnected) {
      if (getCached != null) {
        final cached = await getCached();
        if (cached != null) {
          appLogger.d('Repository: No connection, returning cached data.');
          return Right(cached);
        }
      }
      return const Left(NetworkFailure('No internet connection'));
    }

    try {
      final response = await call();

      // 2. Handle Success
      if (response.result == ApiResult.success) {
        final data = response.body as T;
        if (saveCache != null) await saveCache(data);
        return Right(data);
      }

      // 3. Map Business Error to Failure
      Failure failure;
      if (response.result == ApiResult.sessionTimeout) {
        failure = AuthFailure(response.message ?? 'Session expired');
      } else if (response.result == ApiResult.serverError) {
        failure = ServerApiFailure(response.message ?? 'Server API Error', messageId: response.messageId);
      } else {
        failure = ServerFailure(response.message ?? 'Unknown Server Error');
      }

      return await _handleFailureFallback(failure, getCached, useCacheCondition);
    } on DioException catch (e) {
      return await _handleFailureFallback(_mapDioException(e), getCached, useCacheCondition);
    } on TypeError catch (e, t) {
      appLogger.e('Repository Data Type Mismatch: $e \n$t');
      return const Left(ParseFailure('Unexpected data format from server'));
    } catch (e, t) {
      appLogger.e('Unexpected Repository Error: $e \n$t');
      return Left(UnknownFailure(e.toString()));
    }
  }

  /// Internal helper to map DioException to domain Failure.
  Failure _mapDioException(DioException e) {
    if (e.error is AppException) {
      final appEx = e.error as AppException;
      if (appEx is AuthException) return AuthFailure(appEx.message);
      return ServerFailure(appEx.message);
    }
    return ServerFailure(e.message ?? 'Network Error');
  }

  /// Decides whether to return cached data based on the type of failure.
  Future<Either<Failure, T>> _handleFailureFallback<T>(
    Failure failure,
    Future<T?> Function()? getCached,
    bool Function(Failure failure)? useCacheCondition,
  ) async {
    if (getCached != null) {
      // By default, we fallback to cache for non-critical errors (Network, Auth timeouts, etc.)
      // but skip for critical ServerFailures (500s) unless explicitly overridden.
      final shouldTryCache = useCacheCondition?.call(failure) ?? (failure is! ServerFailure);
      if (shouldTryCache) {
        final cachedData = await getCached();
        if (cachedData != null) {
          appLogger.d('Repository: Network failed ($failure), falling back to local cache.');
          return Right(cachedData);
        }
      }
    }
    return Left(failure);
  }
}
