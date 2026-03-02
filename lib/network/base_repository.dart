import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import '../core.dart';

mixin BaseRepository {
  Future<Either<Failure, T>> safeCall<T>({
    required Future<BaseResponseModel<T>> Function() call,
    required NetworkInfo networkInfo,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure('No internet connection'));
    }

    try {
      final response = await call();

      if (response.result == ApiResult.success) {
        return Right(response.body as T);
      } else if (response.result == ApiResult.sessionTimeout) {
        // TODO: Handle global session timeout (e.g., emit logout event or navigate to login)
        return Left(AuthFailure(response.message ?? 'Session expired'));
      } else if (response.result == ApiResult.serverError) {
        return Left(ServerApiFailure(response.message ?? 'Server API Error'));
      } else {
        return Left(ServerFailure(response.message ?? 'Unknown Server Error'));
      }
    } on DioException catch (e) {
      if (e.error is AppException) {
        final appEx = e.error as AppException;
        if (appEx is AuthException) return Left(AuthFailure(appEx.message));
        return Left(ServerFailure(appEx.message));
      }
      return Left(ServerFailure(e.message ?? 'Network Error'));
    } on TypeError catch (e) {
      appLogger.e('Data type mismatch: $e');
      return Left(ParseFailure('Unexpected data format from server'));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }
}
