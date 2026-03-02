import 'package:fpdart/fpdart.dart';
import '../core.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

extension UseCaseRefX on Ref {
  /// Bridges the gap between Riverpod's [Ref] and the [UseCase] abstraction.
  /// Reads an asynchronous UseCase provider and executes it with the given params.
  ///
  /// This extension simplifies the syntax by automatically accessing the `.future`
  /// property of the provider.
  ///
  /// Example:
  /// ```dart
  /// final result = await ref.execute(loginUseCaseProvider, params);
  /// ```
  Future<Either<Failure, T>> execute<T, P>(dynamic provider, P params) async {
    // In Riverpod, async providers (FutureProvider, AsyncNotifierProvider, etc.)
    // expose a .future property which is a ProviderListenable.
    // By using dynamic, we can hide this implementation detail from the caller.
    final uc = await read(provider.future as ProviderListenable<Future<UseCase<T, P>>>);

    // Execute the business logic encapsulated in the UseCase.
    return uc.call(params);
  }
}
