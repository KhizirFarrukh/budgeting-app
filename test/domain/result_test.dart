import 'package:flutter_test/flutter_test.dart';
import 'package:pookiebudget/domain/result.dart';

/// Tests for the `Result` type that carries every expected failure in the
/// domain layer (ARCHITECTURE.md §8.1).
///
/// Added during substage 3.5 because the pipeline cannot be verified green
/// without at least one test. Substage 3.8 builds the full harness — fakes,
/// builders and the golden-vector loader.
///
/// This is deliberately a **real** test of a **real** type rather than a
/// placeholder that asserts nothing. Substage 9.1's `must_not` — "do not write
/// a test that asserts only that a widget rendered" — applies from the first
/// test onward, not from Stage 9.
void main() {
  group('Result', () {
    test('Success carries its value and reports no failure', () {
      const Result<int, String> r = Success<int, String>(42);

      expect(r.isSuccess, isTrue);
      expect(r.valueOrNull, 42);
      expect(r.failureOrNull, isNull);
    });

    test('Failure carries its failure and reports no value', () {
      const Result<int, String> r = Failure<int, String>('IncomeNotPositive');

      expect(r.isSuccess, isFalse);
      expect(r.valueOrNull, isNull);
      expect(r.failureOrNull, 'IncomeNotPositive');
    });

    test('compares by value, so tests can assert on results directly', () {
      expect(
        const Success<int, String>(1),
        equals(const Success<int, String>(1)),
      );
      expect(
        const Failure<int, String>('a'),
        equals(const Failure<int, String>('a')),
      );
      expect(
        const Success<int, String>(1),
        isNot(equals(const Success<int, String>(2))),
      );
    });

    test('a success and a failure are never equal', () {
      expect(
        const Success<int, String>(1),
        isNot(equals(const Failure<int, String>('1'))),
      );
    });

    test('exhaustive switch compiles, so no failure case can be forgotten', () {
      // The sealed hierarchy is what makes this exhaustive without a default
      // clause. Adding a third subtype would break compilation here rather than
      // silently falling through — which is the point of sealing it.
      String describe(Result<int, String> r) => switch (r) {
        Success<int, String>(:final int value) => 'ok:$value',
        Failure<int, String>(:final String failure) => 'err:$failure',
      };

      expect(describe(const Success<int, String>(7)), 'ok:7');
      expect(describe(const Failure<int, String>('bad')), 'err:bad');
    });
  });
}
