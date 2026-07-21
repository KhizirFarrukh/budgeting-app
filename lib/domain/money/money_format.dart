import 'package:pookiebudget/domain/money/currency.dart';

/// Serialisation of monetary amounts: minor units to an exact decimal string.
///
/// **This is the serialisation half of ARCHITECTURE.md §8.5.** It lives in the
/// domain layer, not presentation, because the CSV exporter and the JSON backup
/// (both in `lib/data`) need it and must not import the presentation layer.
///
/// It produces a *plain* decimal string — no locale, no grouping separators, no
/// currency symbol. The locale-aware display formatter in
/// `lib/presentation/formatting/` is built on top of this and never re-derives
/// decimal placement.
///
/// Every operation here is integer arithmetic. **No `double` appears at any
/// point, including intermediates** (INV-01, guard G3). The obvious
/// implementation — `amount / 100` — is exactly the defect substage 3.6's
/// `common_pitfalls` names: *"A formatter that divides by 100 in a double,
/// reintroducing floating point on the display path."*
class MoneyFormat {
  const MoneyFormat._();

  /// Formats [minorUnits] as an exact decimal string for [currency].
  ///
  /// ```
  /// exp 2:  123456  -> "1234.56"    -50 -> "-0.50"
  /// exp 0:  123456  -> "123456"      -5 -> "-5"
  /// exp 3:  123456  -> "123.456"     -5 -> "-0.005"
  /// ```
  ///
  /// Handles [int] minimum correctly: negating it would overflow, so the sign
  /// is taken first and the digits are read from the unsigned string form.
  static String toDecimalString(int minorUnits, Currency currency) {
    final int exponent = currency.minorUnitExponent;
    final bool negative = minorUnits < 0;

    // `-9223372036854775808` has no positive counterpart in int64, so `.abs()`
    // would return itself. Taking the digits from toString() sidesteps that
    // without arithmetic.
    final String digits = negative
        ? minorUnits.toString().substring(1)
        : minorUnits.toString();

    if (exponent == 0) {
      return negative ? '-$digits' : digits;
    }

    final String padded = digits.padLeft(exponent + 1, '0');
    final int split = padded.length - exponent;
    final String whole = padded.substring(0, split);
    final String fraction = padded.substring(split);

    return negative ? '-$whole.$fraction' : '$whole.$fraction';
  }

  /// Parses a plain decimal string into minor units.
  ///
  /// Returns null when the input is malformed **or carries more decimal places
  /// than the currency allows** — it never truncates silently, because silently
  /// dropping a digit is how money goes missing.
  ///
  /// Accepts an optional leading sign, and accepts fewer decimal places than
  /// the exponent (`"1.5"` at exponent 2 is 150 minor units).
  static int? tryParse(String input, Currency currency) {
    final String trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    bool negative = false;
    String body = trimmed;
    if (body.startsWith('-')) {
      negative = true;
      body = body.substring(1);
    } else if (body.startsWith('+')) {
      body = body.substring(1);
    }
    if (body.isEmpty) return null;

    final List<String> parts = body.split('.');
    if (parts.length > 2) return null;

    final String wholePart = parts[0].isEmpty ? '0' : parts[0];
    final String fractionPart = parts.length == 2 ? parts[1] : '';

    if (!_isDigits(wholePart)) return null;
    if (fractionPart.isNotEmpty && !_isDigits(fractionPart)) return null;

    // Too much precision for this currency: refuse rather than round.
    if (fractionPart.length > currency.minorUnitExponent) return null;

    final String paddedFraction = fractionPart.padRight(
      currency.minorUnitExponent,
      '0',
    );

    final int? whole = int.tryParse(wholePart);
    if (whole == null) return null;

    final int fraction = paddedFraction.isEmpty
        ? 0
        : int.tryParse(paddedFraction) ?? -1;
    if (fraction < 0) return null;

    // Integer multiply-and-add; overflow surfaces as a wrapped value, which the
    // caller bounds against MAX_MONEY_MINOR (ALLOCATION_ALGORITHM §5.6).
    final int magnitude = whole * currency.minorUnitsPerMajor + fraction;
    return negative ? -magnitude : magnitude;
  }

  static bool _isDigits(String s) {
    if (s.isEmpty) return false;
    for (int i = 0; i < s.length; i++) {
      final int c = s.codeUnitAt(i);
      if (c < 0x30 || c > 0x39) return false;
    }
    return true;
  }
}
