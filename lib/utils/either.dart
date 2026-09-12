import 'package:meta/meta.dart';

/// Top-level convenience constructor to create a [Left] instance of [Either].
/// Matches the functional API convention established by fpdart.
///
/// **Example:**
/// ```dart
/// Either<Failure, User> result = left(NetworkFailure('Connection lost'));
/// ```
Either<L, R> left<L, R>(L l) => Left(l);

/// Top-level convenience constructor to create a [Right] instance of [Either].
/// Matches the functional API convention established by fpdart.
///
/// **Example:**
/// ```dart
/// Either<Failure, User> result = right(User(id: '123', name: 'Listen'));
/// ```
Either<L, R> right<L, R>(R r) => Right(r);

/// A lightweight, pure-Dart implementation of the [Either] type to completely replace `fpdart`.
///
/// ### Design Rationale & Background:
/// In Clean Architecture and Domain-Driven Design (DDD), operations such as repository
/// fetches or use-case executions can either fail or succeed. Traditional exception-based
/// flows (try-catch) suffer from hidden side effects, lack of compile-time exhaustiveness,
/// and performance overhead from stack trace capture.
///
/// Previously, the project imported `fpdart` solely to use `Either<L, R>`. However, `fpdart`
/// brings hundreds of unused functional types (Reader, State, IO, Task, Lens), adding
/// unnecessary compilation footprint and dependency version coupling. By implementing
/// a focused, zero-dependency `Either` using Dart 3's `sealed class`, we gain:
/// 1. Zero third-party dependency footprint.
/// 2. Full compile-time pattern matching exhaustiveness checks.
/// 3. Native Dart VM inlining and optimal allocation performance.
///
/// ### Railway-Oriented Programming:
/// By convention:
/// - [Left] represents failure (the "red track" / error domain model).
/// - [Right] represents success (the "green track" / payload data).
@immutable
sealed class Either<L, R> {
  const Either();

  /// Applies the [left] transformation if this is a [Left], or the [right] transformation if this is a [Right].
  ///
  /// This is the primary catamorphism for [Either], collapsing the disjoint union into
  /// a single value of type [T].
  ///
  /// **Example:**
  /// ```dart
  /// final message = result.fold(
  ///   (failure) => 'Error occurred: ${failure.message}',
  ///   (data) => 'Received payload: ${data.name}',
  /// );
  /// ```
  T fold<T>(T Function(L left) left, T Function(R right) right);

  /// Functor map over the [Right] (success) value, preserving the [Left] failure unchanged.
  ///
  /// Follows the monadic "happy path" convention where errors automatically bypass execution.
  ///
  /// **Example:**
  /// ```dart
  /// Either<Failure, int> userIdEither = fetchUser().map((u) => u.id);
  /// ```
  Either<L, NewR> map<NewR>(NewR Function(R right) fn) {
    return fold((l) => Left<L, NewR>(l), (r) => Right<L, NewR>(fn(r)));
  }

  /// Maps the [Left] (failure) value using the given function, preserving the [Right] success unchanged.
  ///
  /// Useful for translating low-level infrastructure failures (e.g. `DioException`)
  /// into high-level domain failures (e.g. `ServerFailure`).
  Either<NewL, R> mapLeft<NewL>(NewL Function(L left) fn) {
    return fold((l) => Left<NewL, R>(fn(l)), (r) => Right<NewL, R>(r));
  }

  /// Returns `true` if this instance holds a [Left] (failure) value.
  bool isLeft() => this is Left<L, R>;

  /// Returns `true` if this instance holds a [Right] (success) value.
  bool isRight() => this is Right<L, R>;

  /// Extracts the success value from [Right], or evaluates and returns [onError] if this is a [Left].
  ///
  /// Provides safe unwrap with fallback handling without throwing exceptions.
  ///
  /// **Example:**
  /// ```dart
  /// final username = userEither.getOrElse((failure) => 'Guest');
  /// ```
  R getOrElse(R Function(L left) onError) {
    return fold(onError, (r) => r);
  }

  /// Converts this [Either] to an [Option] containing the [Right] value if present,
  /// or [None] if this instance is a [Left].
  Option<R> getRight() => fold((_) => const None(), (r) => Some(r));

  /// Converts this [Either] to an [Option] containing the [Left] value if present,
  /// or [None] if this instance is a [Right].
  Option<L> getLeft() => fold((l) => Some(l), (_) => const None());
}

/// Concrete representation of the [Left] side of an [Either], conventionally denoting failure.
///
/// Encapsulates error information (e.g. [Failure], error code, exception context).
class Left<L, R> extends Either<L, R> {
  /// The encapsulated failure payload.
  final L value;

  const Left(this.value);

  @override
  T fold<T>(T Function(L left) left, T Function(R right) right) => left(value);

  @override
  bool operator ==(Object other) => identical(this, other) || (other is Left<L, R> && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Left($value)';
}

/// Concrete representation of the [Right] side of an [Either], conventionally denoting success.
///
/// Encapsulates the successful computation payload (e.g. Entity, DTO, List).
class Right<L, R> extends Either<L, R> {
  /// The encapsulated success payload.
  final R value;

  const Right(this.value);

  @override
  T fold<T>(T Function(L left) left, T Function(R right) right) => right(value);

  @override
  bool operator ==(Object other) => identical(this, other) || (other is Right<L, R> && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Right($value)';
}

/// A lightweight, pure-Dart implementation of the [Option] type.
///
/// Represents optionality explicitly without resorting to nullable types (`T?`)
/// where null may carry ambiguous semantics in functional compositions.
/// An instance of [Option] is either [Some] (value exists) or [None] (absence of value).
@immutable
sealed class Option<T> {
  const Option();

  /// Converts this [Option] to a nullable Dart value (`T?`).
  ///
  /// Returns the wrapped value if [Some], or `null` if [None].
  T? toNullable();
}

/// Concrete representation of an existing value inside an [Option].
class Some<T> extends Option<T> {
  /// The wrapped non-null value.
  final T value;

  const Some(this.value);

  @override
  T? toNullable() => value;

  @override
  bool operator ==(Object other) => identical(this, other) || (other is Some<T> && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Some($value)';
}

/// Concrete representation of the absence of a value inside an [Option].
class None<T> extends Option<T> {
  const None();

  @override
  T? toNullable() => null;

  @override
  bool operator ==(Object other) => other is None<T>;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'None';
}
