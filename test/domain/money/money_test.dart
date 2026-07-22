import 'package:flutter_test/flutter_test.dart';
import 'package:pookiebudget/domain/money/basis_points.dart';
import 'package:pookiebudget/domain/money/currency.dart';
import 'package:pookiebudget/domain/money/money.dart';
import 'package:pookiebudget/domain/money/money_failure.dart';
import 'package:pookiebudget/domain/result.dart';

/// Substage 4.1.6: *"unit tests for every operation, including the boundary and
/// failure cases — zero, one minor unit, the documented maximum, one beyond the
/// maximum, negative values, mismatched currencies in an operation, and parsing
/// input with too many decimal places."*
void main() {
  const Currency usd = Currency(code: 'USD', minorUnitExponent: 2);
  const Currency jpy = Currency(code: 'JPY', minorUnitExponent: 0);
  const Currency kwd = Currency(code: 'KWD', minorUnitExponent: 3);
  const Currency pkr = Currency(code: 'PKR', minorUnitExponent: 2);

  Money m(int minor, [Currency c = usd]) => Money.fromMinorUnits(minor, c);

  group('construction', () {
    test('zero, one minor unit, negative', () {
      expect(const Money.zero(usd).minorUnits, 0);
      expect(const Money.zero(usd).isZero, isTrue);
      expect(m(1).minorUnits, 1);
      expect(m(1).isPositive, isTrue);
      expect(m(-1).isNegative, isTrue);
    });

    test('tryFrom accepts exactly the documented maximum', () {
      final Result<Money, MoneyFailure> r = Money.tryFrom(maxMoneyMinor, usd);
      expect(r.isSuccess, isTrue);
      expect(r.valueOrNull!.minorUnits, maxMoneyMinor);
    });

    test('tryFrom REJECTS one beyond the maximum, in both directions', () {
      // The bound is exact and tight (ALLOCATION_ALGORITHM §5.6). One more
      // would make `amount * 10000` overflow int64.
      for (final int beyond in <int>[maxMoneyMinor + 1, -maxMoneyMinor - 1]) {
        final Result<Money, MoneyFailure> r = Money.tryFrom(beyond, usd);
        expect(r.isSuccess, isFalse, reason: 'should reject $beyond');
        expect(r.failureOrNull, isA<MoneyOverflow>());
      }
    });
  });

  group('parsing', () {
    test('parses all three exponents', () {
      expect(Money.parse('1234.56', usd).valueOrNull!.minorUnits, 123456);
      expect(Money.parse('123456', jpy).valueOrNull!.minorUnits, 123456);
      expect(Money.parse('123.456', kwd).valueOrNull!.minorUnits, 123456);
    });

    test('REJECTS more decimals than the currency allows, never truncates', () {
      // Substage 4.1.1: "returns a typed failure rather than truncating."
      // Truncation is how money goes missing.
      final Result<Money, MoneyFailure> r = Money.parse('1.234', usd);
      expect(r.isSuccess, isFalse);
      final MoneyFailure f = r.failureOrNull!;
      expect(f, isA<MoneyUnparseable>());
      expect(
        (f as MoneyUnparseable).reason,
        ParseFailureReason.tooManyDecimals,
      );
    });

    test('a decimal point at all is too many for exponent 0', () {
      final Result<Money, MoneyFailure> r = Money.parse('1.5', jpy);
      expect(
        (r.failureOrNull! as MoneyUnparseable).reason,
        ParseFailureReason.tooManyDecimals,
      );
    });

    test('distinguishes nonsense from too-precise', () {
      // Different messages: one is a correctable mistake, the other is not.
      expect(
        (Money.parse('abc', usd).failureOrNull! as MoneyUnparseable).reason,
        ParseFailureReason.notANumber,
      );
      expect(
        (Money.parse('', usd).failureOrNull! as MoneyUnparseable).reason,
        ParseFailureReason.empty,
      );
      expect(
        (Money.parse('   ', usd).failureOrNull! as MoneyUnparseable).reason,
        ParseFailureReason.empty,
      );
    });

    test('rejects input beyond the maximum', () {
      final Result<Money, MoneyFailure> r = Money.parse(
        '99999999999999999.00',
        usd,
      );
      expect(r.isSuccess, isFalse);
    });
  });

  group('addition and subtraction', () {
    test('adds and subtracts within bounds', () {
      expect(m(100).plus(m(50)).valueOrNull, m(150));
      expect(m(100).minus(m(150)).valueOrNull, m(-50));
    });

    test('overflow on addition is a typed failure, NOT a wrapped value', () {
      // The pitfall: "Silent wrapping on overflow, which turns a large income
      // into a negative balance."
      final Money big = m(maxMoneyMinor);
      final Result<Money, MoneyFailure> r = big.plus(m(1));
      expect(r.isSuccess, isFalse);
      expect(r.failureOrNull, isA<MoneyOverflow>());
      // Crucially: the result is not a negative number.
      expect(r.valueOrNull, isNull);
    });

    test('overflow on subtraction is a typed failure', () {
      final Result<Money, MoneyFailure> r = m(-maxMoneyMinor).minus(m(1));
      expect(r.isSuccess, isFalse);
      expect(r.failureOrNull, isA<MoneyOverflow>());
    });

    test('MISMATCHED CURRENCIES are rejected', () {
      // Substage 4.1's must_not: "Do not allow arithmetic between different
      // currencies." There is no exchange rate in this app (NG-05).
      final Result<Money, MoneyFailure> r = m(100, usd).plus(m(100, pkr));
      expect(r.isSuccess, isFalse);
      expect(r.failureOrNull, isA<CurrencyMismatch>());

      expect(
        m(100, usd).minus(m(1, jpy)).failureOrNull,
        isA<CurrencyMismatch>(),
      );
    });
  });

  group('negation and absolute value', () {
    test('negates symmetrically without overflow', () {
      // The bound is symmetric, so negation can never overflow — unlike
      // negating int minimum, which this type can never hold.
      expect(m(maxMoneyMinor).negated().minorUnits, -maxMoneyMinor);
      expect(m(-maxMoneyMinor).negated().minorUnits, maxMoneyMinor);
      expect(const Money.zero(usd).negated().minorUnits, 0);
    });

    test('abs', () {
      expect(m(-500).abs(), m(500));
      expect(m(500).abs(), m(500));
    });
  });

  group('multiplyByBasisPoints — floor and remainder', () {
    test('returns both outputs the engine needs', () {
      // 300000 * 4000 = 1,200,000,000; / 10000 = 120,000 remainder 0.
      // The V-05 phase A figure (ALLOCATION_ALGORITHM §3.9).
      final BasisPointSplit s = m(
        300000,
      ).multiplyByBasisPoints(4000).valueOrNull!;
      expect(s.floor.minorUnits, 120000);
      expect(s.remainder, 0);
    });

    test('produces the V-03 tie-break remainders exactly', () {
      // income 3 across 3333/3333/3334 → floors 0/0/1, remainders 9999/9999/2.
      final BasisPointSplit a = m(3).multiplyByBasisPoints(3333).valueOrNull!;
      final BasisPointSplit c = m(3).multiplyByBasisPoints(3334).valueOrNull!;
      expect(a.floor.minorUnits, 0);
      expect(a.remainder, 9999);
      expect(c.floor.minorUnits, 1);
      expect(c.remainder, 2);
    });

    test('honours a non-10000 divisor — the override redistribution case', () {
      // V-09: remaining 300000 across 3500/2500, divisor = relative total 6000.
      // Dividing by 10000 here yields 105000 and 75000, losing 120000
      // (ALLOCATION_ALGORITHM §5.2).
      final BasisPointSplit e = m(
        300000,
      ).multiplyByBasisPoints(3500, divisor: 6000).valueOrNull!;
      final BasisPointSplit t = m(
        300000,
      ).multiplyByBasisPoints(2500, divisor: 6000).valueOrNull!;
      expect(e.floor.minorUnits, 175000);
      expect(t.floor.minorUnits, 125000);
      expect(e.floor.minorUnits + t.floor.minorUnits, 300000);
    });

    test('the maximum times 10000 does not overflow', () {
      // This is the bound's entire purpose.
      final Result<BasisPointSplit, MoneyFailure> r = m(
        maxMoneyMinor,
      ).multiplyByBasisPoints(10000);
      expect(r.isSuccess, isTrue);
      expect(r.valueOrNull!.floor.minorUnits, maxMoneyMinor);
    });

    test('rejects a non-positive divisor rather than dividing by zero', () {
      expect(m(100).multiplyByBasisPoints(5000, divisor: 0).isSuccess, isFalse);
    });

    test('remainder is never negative, even for a negative amount', () {
      final BasisPointSplit s = m(-3).multiplyByBasisPoints(3333).valueOrNull!;
      expect(s.remainder, greaterThanOrEqualTo(0));
    });
  });

  group('comparison', () {
    test('orders and compares', () {
      expect(m(100).isGreaterThan(m(50)), isTrue);
      expect(m(50).isLessThan(m(100)), isTrue);
      expect(m(100).isAtLeast(m(100)), isTrue);
      expect(m(100).isAtMost(m(100)), isTrue);
      expect(<Money>[m(300), m(100), m(200)]..sort(), <Money>[
        m(100),
        m(200),
        m(300),
      ]);
    });

    test(
      'comparing across currencies throws, since Comparable cannot fail',
      () {
        expect(() => m(100, usd).compareTo(m(100, pkr)), throwsArgumentError);
      },
    );

    test('equality includes the currency', () {
      expect(m(100, usd), equals(m(100, usd)));
      expect(m(100, usd), isNot(equals(m(100, pkr))));
      expect(m(100, usd), isNot(equals(m(101, usd))));
    });
  });

  group('serialisation', () {
    test('toDecimalString covers all three exponents', () {
      expect(m(123456, usd).toDecimalString(), '1234.56');
      expect(m(123456, jpy).toDecimalString(), '123456');
      expect(m(123456, kwd).toDecimalString(), '123.456');
      expect(m(-1, usd).toDecimalString(), '-0.01');
    });

    test('round-trips through parse for every exponent', () {
      for (final Currency c in <Currency>[jpy, usd, kwd]) {
        for (final int v in <int>[0, 1, -1, 100, -100, 999999, maxMoneyMinor]) {
          final Money original = Money.fromMinorUnits(v, c);
          final Money parsed = Money.parse(
            original.toDecimalString(),
            c,
          ).valueOrNull!;
          expect(parsed, original, reason: '$v in ${c.code}');
        }
      }
    });
  });

  group('BasisPoints', () {
    test('accepts the full range and rejects outside it', () {
      expect(BasisPoints.tryFrom(0).isSuccess, isTrue);
      expect(BasisPoints.tryFrom(10000).isSuccess, isTrue);
      expect(BasisPoints.tryFrom(-1).isSuccess, isFalse);
      expect(BasisPoints.tryFrom(10001).isSuccess, isFalse);
    });

    test('sumsToFull is exact — 9999 and 10001 both fail', () {
      // SCHEMA V-01/V-02: totals must be EXACTLY 10000.
      expect(
        BasisPoints.sumsToFull(<BasisPoints>[
          BasisPoints.checked(5000),
          BasisPoints.checked(3000),
          BasisPoints.checked(2000),
        ]),
        isTrue,
      );
      expect(
        BasisPoints.sumsToFull(<BasisPoints>[BasisPoints.checked(9999)]),
        isFalse,
      );
      expect(
        BasisPoints.sumsToFull(<BasisPoints>[
          BasisPoints.checked(10000),
          BasisPoints.checked(1),
        ]),
        isFalse,
      );
    });

    test('sum gives the divisor for override redistribution', () {
      expect(
        BasisPoints.sum(<BasisPoints>[
          BasisPoints.checked(3500),
          BasisPoints.checked(2500),
        ]),
        6000,
      );
    });

    test('percent formatting uses integer arithmetic, never division', () {
      expect(BasisPoints.checked(10000).asPercentString, '100');
      expect(BasisPoints.checked(3550).asPercentString, '35.50');
      expect(BasisPoints.checked(5).asPercentString, '0.05');
      expect(BasisPoints.checked(0).asPercentString, '0');
    });

    test('wholePercent floors — 9999 bp is 99%, never 100%', () {
      expect(BasisPoints.checked(9999).wholePercent, 99);
      expect(BasisPoints.checked(10000).wholePercent, 100);
    });
  });
}
