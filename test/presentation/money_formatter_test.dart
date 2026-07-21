import 'package:flutter_test/flutter_test.dart';
import 'package:pookiebudget/domain/money/currency.dart';
import 'package:pookiebudget/presentation/formatting/money_formatter.dart';

/// Substage 3.6.5, including *"a locale with a different grouping separator"*.
void main() {
  const Currency usd = Currency(code: 'USD', minorUnitExponent: 2);
  const Currency jpy = Currency(code: 'JPY', minorUnitExponent: 0);
  const Currency kwd = Currency(code: 'KWD', minorUnitExponent: 3);
  const Currency pkr = Currency(code: 'PKR', minorUnitExponent: 2);

  group('grouping separators', () {
    test('en_US groups with commas', () {
      final MoneyFormatter f = MoneyFormatter(currency: usd, locale: 'en_US');
      expect(f.formatBare(123456789), '1,234,567.89');
      expect(f.formatBare(100000), '1,000.00');
      expect(f.formatBare(99999), '999.99');
    });

    test('de_DE groups with dots and decimalises with a comma', () {
      // The locale-different-separator case substage 3.6.5 asks for. A
      // formatter that hardcoded "," for grouping and "." for the decimal would
      // pass every en_US test and be wrong for most of Europe.
      final MoneyFormatter f = MoneyFormatter(currency: usd, locale: 'de_DE');
      expect(f.formatBare(123456789), '1.234.567,89');
    });

    test('grouping applies to the whole part only, never the fraction', () {
      final MoneyFormatter f = MoneyFormatter(currency: kwd, locale: 'en_US');
      // Three decimals must stay "123.456", not become "123.456" grouped again.
      expect(f.formatBare(123456), '123.456');
      expect(f.formatBare(1234567), '1,234.567');
    });
  });

  group('exponents', () {
    test('exponent 0 has no decimal separator', () {
      final MoneyFormatter f = MoneyFormatter(currency: jpy, locale: 'en_US');
      expect(f.formatBare(1234567), '1,234,567');
      expect(f.formatBare(0), '0');
    });

    test('exponent 3 keeps all three decimals', () {
      final MoneyFormatter f = MoneyFormatter(currency: kwd, locale: 'en_US');
      expect(f.formatBare(1), '0.001');
    });
  });

  group('negatives', () {
    test('the sign precedes the symbol, not the digits', () {
      final MoneyFormatter f = MoneyFormatter(currency: usd, locale: 'en_US');
      expect(f.formatBare(-123456), '-1,234.56');
      expect(f.format(-123456).startsWith('-'), isTrue);
    });

    test('a small negative keeps its padding', () {
      final MoneyFormatter f = MoneyFormatter(currency: usd, locale: 'en_US');
      expect(f.formatBare(-1), '-0.01');
    });
  });

  group('extremes', () {
    test('formats the documented maximum without loss', () {
      final MoneyFormatter f = MoneyFormatter(currency: usd, locale: 'en_US');
      expect(f.formatBare(922337203685477), '9,223,372,036,854.77');
    });
  });

  group('symbol', () {
    test('a symbol is attached and a code falls back to itself', () {
      final MoneyFormatter usdF = MoneyFormatter(
        currency: usd,
        locale: 'en_US',
      );
      expect(usdF.format(100), contains('1.00'));
      expect(usdF.format(100).length, greaterThan('1.00'.length));

      // PKR has no widely-used single-character symbol; the code must still
      // produce something intelligible rather than an empty prefix.
      final MoneyFormatter pkrF = MoneyFormatter(
        currency: pkr,
        locale: 'en_US',
      );
      expect(pkrF.format(100), contains('1.00'));
      expect(pkrF.format(100).trim().isNotEmpty, isTrue);
    });

    test('formatBare omits the symbol entirely', () {
      final MoneyFormatter f = MoneyFormatter(currency: usd, locale: 'en_US');
      expect(f.formatBare(100), '1.00');
    });
  });
}
