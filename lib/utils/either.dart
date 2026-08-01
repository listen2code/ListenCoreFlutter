import 'package:meta/meta.dart';

/// Top-level helpers to construct Left and Right, matching fpdart.
Either<L, R> left<L, R>(L l) => Left(l);
Either<L, R> right<L, R>(R r) => Right(r);

/// A lightweight, custom implementation of the [Either] type to replace fpdart.
/// Represents a value of one of two possible types (a disjoint union).
/// An instance of [Either] is either an instance of [Left] or [Right].
///
/// Convention dictates that [Left] is used for failure and [Right] is used for success.
@immutable
sealed class Either<L, R> {
  const Either();

  /// Applies the [left] function if this is a [Left], or the [right] function if this is a [Right].
  T fold<T>(T Function(L left) left, T Function(R right) right);

  /// Maps the [Right] value using the given function, leaving a [Left] untouched.
  Either<L, NewR> map<NewR>(NewR Function(R right) fn) {
    return fold(
      (l) => Left<L, NewR>(l),
      (r) => Right<L, NewR>(fn(r)),
    );
  }

  /// Maps the [Left] value using the given function, leaving a [Right] untouched.
  Either<NewL, R> mapLeft<NewL>(NewL Function(L left) fn) {
    return fold(
      (l) => Left<NewL, R>(fn(l)),
      (r) => Right<NewL, R>(r),
    );
  }

  /// Check if this is a Left instance.
  bool isLeft() => this is Left<L, R>;

  /// Check if this is a Right instance.
  bool isRight() => this is Right<L, R>;

  /// Returns the value from [Right] or the result of [onError] if this is a [Left].
  R getOrElse(R Function(L left) onError) {
    return fold(onError, (r) => r);
  }

  /// Returns a [Some] containing the [Right] value, or [None] if this is a [Left].
  Option<R> getRight() => fold((_) => const None(), (r) => Some(r));

  /// Returns a [Some] containing the [Left] value, or [None] if this is a [Right].
  Option<L> getLeft() => fold((l) => Some(l), (_) => const None());
}

class Left<L, R> extends Either<L, R> {
  final L value;
  const Left(this.value);

  @override
  T fold<T>(T Function(L left) left, T Function(R right) right) => left(value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Left<L, R> && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Left($value)';
}

class Right<L, R> extends Either<L, R> {
  final R value;
  const Right(this.value);

  @override
  T fold<T>(T Function(L left) left, T Function(R right) right) => right(value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Right<L, R> && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Right($value)';
}

/// A lightweight custom implementation of the [Option] type, representing the presence or absence of a value.
@immutable
sealed class Option<T> {
  const Option();

  T? toNullable();
}

class Some<T> extends Option<T> {
  final T value;
  const Some(this.value);

  @override
  T? toNullable() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Some<T> && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Some($value)';
}

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
