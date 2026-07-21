import 'package:flutter_test/flutter_test.dart';
import 'package:pookiebudget/domain/money/currency.dart';
import 'package:pookiebudget/domain/money/money_format.dart';

/// Substage 3.6.5 requires: exponent 0, 2 and 3; zero; one minor unit;
/// negative; a value near the documented maximum.
///
/// The documented maximum is `MAX_MONEY_MINOR = 922,337,203,685,477`, derived
/// in ALLOCATION_ALGORITHM.md §5.6 as `floor((2^63 - 1) / 10000)`.
void main() {
  const Currency jpy = Currency(code: 'JPY', minorUnitExponent: 0);
  const Currency usd = Currency(code: 'USD', minorUnitExponent: 2);
  const Currency pkr = Currency(code: 'PKR', minorUnitExponent: 2);
  const Currency kwd = Currency(code: 'KWD', minorUnitExponent: 3);

  const int maxMoneyMinor = 922337203685477;

  group('Currency.minorUnitsPerMajor', () {
    test('computes 10^exponent by integer multiplication', () {
      expect(jpy.minorUnitsPerMajor, 1);
      expect(usd.minorUnitsPerMajor, 100);
      expect(kwd.minorUnitsPerMajor, 1000);
    });
  });

  group('toDecimalString — exponent 0 (JPY)', () {
    test('has no decimal point at all', () {
      expect(MoneyFormat.toDecimalString(123456, jpy), '123456');
      expect(MoneyFormat.toDecimalString(0, jpy), '0');
      expect(MoneyFormat.toDecimalString(1, jpy), '1');
      expect(MoneyFormat.toDecimalString(-5, jpy), '-5');
    });
  });

  group('toDecimalString — exponent 2 (USD, PKR)', () {
    test('places two decimals', () {
      expect(MoneyFormat.toDecimalString(123456, usd), '1234.56');
      expect(MoneyFormat.toDecimalString(100, usd), '1.00');
    });

    test('zero and one minor unit', () {
      expect(MoneyFormat.toDecimalString(0, usd), '0.00');
      expect(MoneyFormat.toDecimalString(1, usd), '0.01');
    });

    test('pads amounts smaller than one major unit', () {
      expect(MoneyFormat.toDecimalString(5, pkr), '0.05');
      expect(MoneyFormat.toDecimalString(50, pkr), '0.50');
    });

    test('negatives keep the sign outside the padding', () {
      expect(MoneyFormat.toDecimalString(-1, usd), '-0.01');
      expect(MoneyFormat.toDecimalString(-50, usd), '-0.50');
      expect(MoneyFormat.toDecimalString(-123456, usd), '-1234.56');
    });
  });

  group('toDecimalString — exponent 3 (KWD)', () {
    test('places three decimals', () {
      expect(MoneyFormat.toDecimalString(123456, kwd), '123.456');
      expect(MoneyFormat.toDecimalString(1000, kwd), '1.000');
      expect(MoneyFormat.toDecimalString(1, kwd), '0.001');
      expect(MoneyFormat.toDecimalString(-5, kwd), '-0.005');
    });
  });

  group('toDecimalString — extremes', () {
    test('formats the documented maximum exactly', () {
      // Nine trillion in a 2-decimal currency. No precision is lost, which is
      // the whole point of never touching a double: a double cannot represent
      // this value exactly.
      expect(
        MoneyFormat.toDecimalString(maxMoneyMinor, usd),
        '9223372036854.77',
      );
      expect(
        MoneyFormat.toDecimalString(maxMoneyMinor, jpy),
        '922337203685477',
      );
    });

    test('handles int minimum without overflowing on negation', () {
      // -9223372036854775808 has no positive counterpart in int64, so `.abs()`
      // returns itself. The implementation takes digits from the string form to
      // avoid that trap entirely.
      const int intMin = -9223372036854775808;
      expect(MoneyFormat.toDecimalString(intMin, usd), '-92233720368547758.08');
    });
  });

  group('tryParse', () {
    test('round-trips every formatted value', () {
      const List<int> values = <int>[
        0,
        1,
        -1,
        5,
        -5,
        100,
        -100,
        123456,
        -123456,
        999999999,
        maxMoneyMinor,
      ];
      for (final Currency c in <Currency>[jpy, usd, kwd]) {
        for (final int v in values) {
          final String s = MoneyFormat.toDecimalString(v, c);
          expect(
            MoneyFormat.tryParse(s, c),
            v,
            reason: 'round-trip failed for $v in ${c.code} via "$s"',
          );
        }
      }
    });

    test('accepts fewer decimals than the exponent', () {
      expect(MoneyFormat.tryParse('1.5', usd), 150);
      expect(MoneyFormat.tryParse('1', usd), 100);
      expect(MoneyFormat.tryParse('.5', usd), 50);
    });

    test('REFUSES more decimals than the currency allows', () {
      // Substage 4.1.1: parsing "returns a typed failure rather than
      // truncating". Silently dropping a digit is how money goes missing.
      expect(MoneyFormat.tryParse('1.234', usd), isNull);
      expect(MoneyFormat.tryParse('1.5', jpy), isNull);
      expect(MoneyFormat.tryParse('1.2345', kwd), isNull);
    });

    test('rejects malformed input rather than guessing', () {
      for (final String bad in <String>[
        '',
        '   ',
        'abc',
        '1.2.3',
        '1,234.56',
        '1 234',
        '--1',
        '1-',
        '+',
        '-',
        r'$1.00',
        '1.2a',
      ]) {
        expect(
          MoneyFormat.tryParse(bad, usd),
          isNull,
          reason: 'should have rejected "$bad"',
        );
      }
    });

    test('accepts explicit signs and surrounding whitespace', () {
      expect(MoneyFormat.tryParse('  1.00  ', usd), 100);
      expect(MoneyFormat.tryParse('+1.00', usd), 100);
      expect(MoneyFormat.tryParse('-1.00', usd), -100);
    });
  });
}
