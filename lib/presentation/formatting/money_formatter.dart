import 'package:intl/intl.dart';
import 'package:pookiebudget/domain/money/currency.dart';
import 'package:pookiebudget/domain/money/money_format.dart';

/// Locale-aware display formatting for monetary amounts.
///
/// **The display half of ARCHITECTURE.md §8.5.** It is built on
/// [MoneyFormat.toDecimalString] and never re-derives decimal placement — there
/// is exactly one implementation of "where does the decimal point go", and it
/// lives in the domain layer where the exporter can reach it too.
///
/// **No code path here accepts or returns a floating-point value**, which is
/// substage 3.6's acceptance criterion. The grouping separators are inserted
/// into the *digit string*, never by handing a number to a numeric formatter —
/// that would reintroduce a `double` on the display path, the exact defect
/// substage 3.6's `common_pitfalls` names.
class MoneyFormatter {
  MoneyFormatter({required this.currency, required this.locale});

  final Currency currency;
  final String locale;

  /// Formats [minorUnits] for display, with grouping separators and symbol.
  ///
  /// ```
  /// en_US, USD exp 2:   123456789 -> "$1,234,567.89"
  /// ja_JP, JPY exp 0:       12345 -> "¥12,345"
  /// ar,    KWD exp 3:     1234567 -> "KWD 1,234.567"
  /// ```
  String format(int minorUnits, {bool showSymbol = true}) {
    final String plain = MoneyFormat.toDecimalString(minorUnits, currency);
    final String grouped = _group(plain);
    if (!showSymbol) return grouped;

    final String symbol = symbolFor(currency.code, locale);
    // A symbol that is really a code reads better with a space: "KWD 1,234.567"
    // rather than "KWD1,234.567".
    final String separator = symbol.length > 1 ? ' ' : '';
    return grouped.startsWith('-')
        ? '-$symbol$separator${grouped.substring(1)}'
        : '$symbol$separator$grouped';
  }

  /// Formats without the currency symbol — for tables and inputs where the
  /// currency is stated once in a header.
  String formatBare(int minorUnits) => format(minorUnits, showSymbol: false);

  /// Inserts locale-appropriate grouping separators into the whole-number part.
  ///
  /// Operates on the **string**, so no numeric conversion occurs at any point.
  String _group(String plain) {
    final bool negative = plain.startsWith('-');
    final String body = negative ? plain.substring(1) : plain;

    final int dot = body.indexOf('.');
    final String whole = dot == -1 ? body : body.substring(0, dot);
    final String fraction = dot == -1 ? '' : body.substring(dot + 1);

    final NumberFormat symbols = NumberFormat.decimalPattern(locale);
    final String groupSep = symbols.symbols.GROUP_SEP;
    final String decimalSep = symbols.symbols.DECIMAL_SEP;

    final StringBuffer grouped = StringBuffer();
    for (int i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) {
        grouped.write(groupSep);
      }
      grouped.write(whole[i]);
    }

    final String result = fraction.isEmpty
        ? grouped.toString()
        : '$grouped$decimalSep$fraction';
    return negative ? '-$result' : result;
  }

  /// The display symbol for a currency code in a locale.
  ///
  /// Falls back to the code itself, which is always intelligible even when no
  /// symbol is known.
  static String symbolFor(String code, String locale) {
    try {
      final NumberFormat f = NumberFormat.simpleCurrency(
        locale: locale,
        name: code,
      );
      final String symbol = f.currencySymbol;
      return symbol.isEmpty ? code : symbol;
    } on Exception {
      return code;
    }
  }
}
