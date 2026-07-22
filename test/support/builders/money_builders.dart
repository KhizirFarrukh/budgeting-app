import 'package:pookiebudget/domain/money/currency.dart';

/// Test-data builders with sensible defaults and named overrides.
///
/// Substage 3.8.4: *"A builder pattern keeps tests readable when an entity
/// gains a field in Stage 4."*
///
/// That is the whole point. Stage 4 substage 4.2 adds ten entities, each with
/// many fields. Without builders, every test that constructs one breaks the day
/// a field is added — and the usual response is to loosen the test rather than
/// update it.
///
/// Stage 4 extends this file as entities arrive. Only currency exists today.
class CurrencyBuilder {
  /// Two-decimal default. Most currencies, and the case most likely to hide a
  /// hardcoded assumption.
  static const Currency usd = Currency(code: 'USD', minorUnitExponent: 2);
  static const Currency pkr = Currency(code: 'PKR', minorUnitExponent: 2);

  /// **Exponent 0.** The case a formatter with hardcoded decimals gets wrong.
  static const Currency jpy = Currency(code: 'JPY', minorUnitExponent: 0);

  /// **Exponent 3.** The other end, and the case that breaks a `/100`
  /// assumption.
  static const Currency kwd = Currency(code: 'KWD', minorUnitExponent: 3);

  /// All three exponents, for tests that should run across every shape rather
  /// than only the convenient one.
  static const List<Currency> allExponents = <Currency>[jpy, usd, kwd];
}

/// Amounts that have caused defects in money-handling code, in minor units.
///
/// Substage 4.1.6 requires boundary coverage; keeping the list in one place
/// means a new edge case is added once and picked up everywhere.
class Amounts {
  const Amounts._();

  static const int zero = 0;
  static const int oneMinorUnit = 1;
  static const int negativeOneMinorUnit = -1;

  /// `floor((2^63 - 1) / 10000)` — ALLOCATION_ALGORITHM §5.6. Above this,
  /// `amount * basis_points` overflows int64.
  static const int maxMoneyMinor = 922337203685477;

  /// One beyond the bound. Must be **rejected**, never wrapped.
  static const int overMaximum = 922337203685478;

  /// No positive counterpart in int64, so `.abs()` returns itself.
  static const int intMin = -9223372036854775808;

  /// The awkward ones, for a test that should sweep rather than sample.
  static const List<int> boundary = <int>[
    zero,
    oneMinorUnit,
    negativeOneMinorUnit,
    99,
    100,
    101,
    -100,
    maxMoneyMinor,
  ];
}
