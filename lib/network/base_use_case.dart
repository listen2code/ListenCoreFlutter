import 'package:fpdart/fpdart.dart';
import '../core.dart';

/// Base interface for all use cases in the application
/// Use cases encapsulate business logic and are the entry point to the domain layer
/// T: The return type of the use case
/// Params: The parameters required by the use case
abstract class UseCase<T, Params> {
  Future<Either<Failure, T>> call(Params params);
}

/// Used for use cases that don't require any parameters
class NoParams {
  const NoParams();
}
