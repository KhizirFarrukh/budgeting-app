/// The result type used for **expected** failures throughout the domain layer.
///
/// ARCHITECTURE.md §8.1: the domain layer returns typed results for expected
/// failures and reserves exceptions for programmer error. An invalid
/// configuration, an over-maximum income, a bad override — all are values, not
/// exceptions.
///
/// Exceptions remain appropriate for states that indicate a bug: a conservation
/// assertion failing inside the engine (INV-02), or a mapper receiving a row
/// with an impossible enum value.
sealed class Result<T, F> {
  const Result();

  /// True when this is a [Success].
  bool get isSuccess => this is Success<T, F>;

  /// The value, or null when this is a [Failure].
  T? get valueOrNull => switch (this) {
        Success<T, F>(:final value) => value,
        Failure<T, F>() => null,
      };

  /// The failure, or null when this is a [Success].
  F? get failureOrNull => switch (this) {
        Success<T, F>() => null,
        Failure<T, F>(:final failure) => failure,
      };
}

/// A successful result carrying its value.
final class Success<T, F> extends Result<T, F> {
  const Success(this.value);

  final T value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T, F> &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Success($value)';
}

/// An expected failure carrying enough context for a specific message.
///
/// "Something went wrong" is not an acceptable terminal state — every
/// user-visible failure names the offending value and a recovery action.
final class Failure<T, F> extends Result<T, F> {
  const Failure(this.failure);

  final F failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure<T, F> &&
          runtimeType == other.runtimeType &&
          failure == other.failure;

  @override
  int get hashCode => failure.hashCode;

  @override
  String toString() => 'Failure($failure)';
}
