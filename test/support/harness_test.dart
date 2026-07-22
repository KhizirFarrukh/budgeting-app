import 'package:flutter_test/flutter_test.dart';
import 'package:pookiebudget/domain/money/currency.dart';
import 'package:pookiebudget/domain/money/money_format.dart';

import 'builders/money_builders.dart';
import 'fakes/fake_clock.dart';
import 'fakes/fake_id_generator.dart';
import 'vector_loader.dart';

/// Exercises the harness itself.
///
/// Substage 3.8.6 requires trivial tests that *actually use* the fake clock and
/// deterministic id generator, on the grounds that **"a fake nobody exercises
/// is a fake nobody has tested."**
///
/// Stages 4 and 5 are test-first and build directly on all of this, so a defect
/// here would surface as a confusing failure in code that is actually correct.
void main() {
  group('FakeClock', () {
    test('returns a fixed instant and records every read', () {
      final FakeClock clock = FakeClock();
      final int a = clock.nowMs();
      final int b = clock.nowMs();

      expect(a, b, reason: 'time must not move on its own');
      expect(clock.reads, <int>[a, b]);
    });

    test('advances only when told to', () {
      final FakeClock clock = FakeClock(1000);
      expect(clock.peek(), 1000);

      clock.advance(const Duration(milliseconds: 500));
      expect(clock.peek(), 1500);

      clock.advance(const Duration(days: 1));
      expect(clock.peek(), 1500 + Duration.millisecondsPerDay);
    });

    test('peek does not count as a read', () {
      final FakeClock clock = FakeClock();
      clock.peek();
      expect(
        clock.reads,
        isEmpty,
        reason:
            'peek exists so a test can inspect time without perturbing '
            'the read count it may be asserting on',
      );
    });

    test('refuses to advance backwards', () {
      // A clock that silently goes backwards hides HLC ordering defects rather
      // than exposing them. Stage 7 tests skew deliberately, via setTo.
      final FakeClock clock = FakeClock();
      expect(
        () => clock.advance(const Duration(milliseconds: -1)),
        throwsArgumentError,
      );
    });

    test('setTo allows a deliberate backwards jump', () {
      final FakeClock clock = FakeClock(5000);
      clock.setTo(1000);
      expect(clock.peek(), 1000);
    });
  });

  group('FakeIdGenerator', () {
    test('produces stable, predictable ids across runs', () {
      final FakeIdGenerator gen = FakeIdGenerator();
      expect(gen.newTimeSortableId(), 'id-t-000001');
      expect(gen.newTimeSortableId(), 'id-t-000002');
      expect(gen.newRandomId(), 'id-r-000001');

      // A second generator produces the same sequence — this is what lets
      // Stage 5's golden vectors assert exact ids.
      final FakeIdGenerator other = FakeIdGenerator();
      expect(other.newTimeSortableId(), 'id-t-000001');
    });

    test('time-sortable ids sort lexicographically in issue order', () {
      // Mirrors the property real UUID v7 provides (ARCHITECTURE §8.6), so a
      // test relying on ordering behaves the same with fakes and in production.
      final FakeIdGenerator gen = FakeIdGenerator();
      final List<String> ids = <String>[
        for (int i = 0; i < 12; i++) gen.newTimeSortableId(),
      ];
      final List<String> sorted = <String>[...ids]..sort();
      expect(sorted, ids);
    });

    test('the two id kinds never collide', () {
      final FakeIdGenerator gen = FakeIdGenerator();
      final Set<String> seen = <String>{};
      for (int i = 0; i < 50; i++) {
        expect(seen.add(gen.newTimeSortableId()), isTrue);
        expect(seen.add(gen.newRandomId()), isTrue);
      }
    });

    test('reset restores the initial state', () {
      final FakeIdGenerator gen = FakeIdGenerator()..newTimeSortableId();
      gen.reset();
      expect(gen.newTimeSortableId(), 'id-t-000001');
      expect(gen.issued, hasLength(1));
    });
  });

  group('VectorLoader', () {
    test('loads every fixture in the directory with no code change', () {
      // The pitfall this guards: "A fixture loader hardcoded to a list of
      // filenames, which then requires a code change per vector in Stage 5."
      final List<AllocationVector> vectors = VectorLoader.loadAll();
      expect(vectors, isNotEmpty);
      expect(
        vectors.map((AllocationVector v) => v.id),
        containsAll(<String>['V-01', 'V-11a']),
      );
    });

    test('returns vectors sorted by id, so runs are reproducible', () {
      final List<AllocationVector> vectors = VectorLoader.loadAll();
      final List<String> ids = vectors
          .map((AllocationVector v) => v.id)
          .toList();
      expect(ids, ids.toList()..sort());
    });

    test('parses a success vector', () {
      final AllocationVector v = VectorLoader.load('V-01');
      expect(v.expectsFailure, isFalse);
      expect(v.expectedAllocations, hasLength(3));
      expect(v.expectedTotalMinor, 1000000);
      expect(v.request['income_amount_minor'], 1000000);
    });

    test('parses a FAILURE vector', () {
      // The shape substage 5.8's pitfall says gets quietly omitted when the
      // format cannot express it.
      final AllocationVector v = VectorLoader.load('V-11a');
      expect(v.expectsFailure, isTrue);
      expect(v.expectedFailure, 'IncomeNotPositive');
      expect(v.expectedAllocations, isNull);
    });

    test('every fixture amount is an integer, never a decimal', () {
      // INV-01 applies to test data as strictly as to production code
      // (ALLOCATION_ALGORITHM §9.1).
      for (final AllocationVector v in VectorLoader.loadAll()) {
        expect(
          v.request['income_amount_minor'],
          isA<int>(),
          reason: '${v.id} has a non-integer income amount',
        );
        for (final Map<String, Object?> line
            in v.expectedAllocations ?? const <Map<String, Object?>>[]) {
          expect(
            line['amount_minor'],
            isA<int>(),
            reason: '${v.id} has a non-integer line amount',
          );
        }
      }
    });

    test('a missing id fails loudly rather than silently skipping', () {
      expect(() => VectorLoader.load('V-99'), throwsStateError);
    });
  });

  group('builders', () {
    test('cover all three currency exponents', () {
      expect(
        CurrencyBuilder.allExponents
            .map((Currency c) => c.minorUnitExponent)
            .toList(),
        <int>[0, 2, 3],
      );
    });

    test('boundary amounts round-trip through the money format', () {
      for (final Currency currency in CurrencyBuilder.allExponents) {
        for (final int amount in Amounts.boundary) {
          final String s = MoneyFormat.toDecimalString(amount, currency);
          expect(
            MoneyFormat.tryParse(s, currency),
            amount,
            reason: '$amount in ${currency.code} via "$s"',
          );
        }
      }
    });
  });
}
