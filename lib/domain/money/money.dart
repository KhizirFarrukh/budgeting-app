import 'package:pookiebudget/domain/money/currency.dart';
import 'package:pookiebudget/domain/money/money_failure.dart';
import 'package:pookiebudget/domain/money/money_format.dart';
import 'package:pookiebudget/domain/result.dart';

/// A monetary amount: **int64 minor units plus its currency**.
///
/// INV-01 is the invariant every other correctness property rests on, and this
/// type is where it is enforced. Substage 4.1's `why_it_matters`: *"Enforcing
/// it in a type is stronger than enforcing it in review."*
///
/// ## What this type deliberately does not have
///
/// - **No `toDouble()`.** Substage 4.1's `must_not` is explicit: *"Do not add a
///   convenience toDouble method — it will be used."*
/// - **No constructor, factory or setter taking a `double` or `num`.** The
///   `common_pitfalls` entry: *"A fromDouble factory added for test
///   convenience, which then appears in production code."*
/// - **No silent overflow.** Every operation that can exceed [maxMoneyMinor]
///   returns a typed failure instead of wrapping. A wrapped overflow turns a
///   large income into a negative balance.
/// - **No cross-currency arithmetic.** There is no exchange rate in this app
///   (NG-05), so combining two currencies is always an error.
///
/// Guard **G3** additionally forbids the words `double`, `float` and `num`
/// anywhere in `lib/domain` and `lib/data`, so the prohibition holds even for
/// code that never touches this class.
final class Money implements Comparable<Money> {
  const Money._(this.minorUnits, this.currency);

  /// Zero in [currency].
  const Money.zero(Currency currency) : this._(0, currency);

  /// From an already-validated minor-unit amount.
  ///
  /// Asserts the bound in debug builds. Use [tryFrom] where the value could
  /// exceed it — from a file, a sync payload, or user input.
  factory Money.fromMinorUnits(int minorUnits, Currency currency) {
    assert(
      minorUnits.abs() <= maxMoneyMinor,
      'Money.fromMinorUnits given $minorUnits, beyond MAX_MONEY_MINOR. '
      'Use Money.tryFrom for values that could exceed the bound.',
    );
    return Money._(minorUnits, currency);
  }

  /// From a minor-unit amount that might exceed the bound.
  static Result<Money, MoneyFailure> tryFrom(
    int minorUnits,
    Currency currency,
  ) {
    if (minorUnits.abs() > maxMoneyMinor) {
      return Failure<Money, MoneyFailure>(
        MoneyOverflow(operation: 'fromMinorUnits', operands: <int>[minorUnits]),
      );
    }
    return Success<Money, MoneyFailure>(Money._(minorUnits, currency));
  }

  /// Parses user input such as `"1234.56"`.
  ///
  /// **Rejects more decimal places than the currency allows rather than
  /// truncating** (substage 4.1.1). Silently dropping a digit is how money goes
  /// missing.
  static Result<Money, MoneyFailure> parse(String input, Currency currency) {
    final String trimmed = input.trim();
    if (trimmed.isEmpty) {
      return Failure<Money, MoneyFailure>(
        MoneyUnparseable(input: input, reason: ParseFailureReason.empty),
      );
    }

    final int? parsed = MoneyFormat.tryParse(trimmed, currency);
    if (parsed == null) {
      // Distinguish "too many decimals" from "not a number", because the two
      // need different messages: one is a correctable mistake, the other is
      // nonsense input.
      final int dot = trimmed.indexOf('.');
      final bool tooManyDecimals =
          dot >= 0 && trimmed.length - dot - 1 > currency.minorUnitExponent;
      return Failure<Money, MoneyFailure>(
        MoneyUnparseable(
          input: input,
          reason: tooManyDecimals
              ? ParseFailureReason.tooManyDecimals
              : ParseFailureReason.notANumber,
        ),
      );
    }

    if (parsed.abs() > maxMoneyMinor) {
      return Failure<Money, MoneyFailure>(
        MoneyUnparseable(input: input, reason: ParseFailureReason.tooLarge),
      );
    }
    return Success<Money, MoneyFailure>(Money._(parsed, currency));
  }

  /// The amount in the currency's smallest unit. Always an `int`.
  final int minorUnits;

  final Currency currency;

  bool get isZero => minorUnits == 0;
  bool get isNegative => minorUnits < 0;
  bool get isPositive => minorUnits > 0;

  // -------------------------------------------------------------------------
  // Arithmetic — every operation that can overflow returns a typed failure
  // -------------------------------------------------------------------------

  Result<Money, MoneyFailure> plus(Money other) {
    final MoneyFailure? mismatch = _requireSameCurrency(other);
    if (mismatch != null) return Failure<Money, MoneyFailure>(mismatch);
    return _bounded(minorUnits + other.minorUnits, 'plus', <int>[
      minorUnits,
      other.minorUnits,
    ]);
  }

  Result<Money, MoneyFailure> minus(Money other) {
    final MoneyFailure? mismatch = _requireSameCurrency(other);
    if (mismatch != null) return Failure<Money, MoneyFailure>(mismatch);
    return _bounded(minorUnits - other.minorUnits, 'minus', <int>[
      minorUnits,
      other.minorUnits,
    ]);
  }

  /// Negation. Cannot overflow, because the bound is symmetric — unlike
  /// negating `int` minimum, which this type can never hold.
  Money negated() => Money._(-minorUnits, currency);

  Money abs() => minorUnits < 0 ? negated() : this;

  /// Multiplies by a basis-point weight, returning **both** the floor and the
  /// remainder.
  ///
  /// Substage 4.1.2 requires both outputs *"because the allocation engine needs
  /// both"* — the largest-remainder method (ALLOCATION_ALGORITHM §5.1) floors
  /// each share, then distributes leftover units by remainder.
  ///
  /// [divisor] is the **sum of the weights**, not a constant. Phase A passes
  /// 10000; override redistribution passes the relative total. §5.2 records why
  /// hardcoding 10000 passes every phase A vector and fails only under
  /// override.
  Result<BasisPointSplit, MoneyFailure> multiplyByBasisPoints(
    int basisPoints, {
    int divisor = 10000,
  }) {
    if (divisor <= 0) {
      return Failure<BasisPointSplit, MoneyFailure>(
        MoneyOverflow(
          operation: 'multiplyByBasisPoints',
          operands: <int>[divisor],
        ),
      );
    }
    // Bounded inputs make this product safe: |minorUnits| <= MAX_MONEY_MINOR
    // and basisPoints <= 10000, which is exactly the bound's derivation.
    if (minorUnits.abs() > maxMoneyMinor || basisPoints.abs() > 10000) {
      return Failure<BasisPointSplit, MoneyFailure>(
        MoneyOverflow(
          operation: 'multiplyByBasisPoints',
          operands: <int>[minorUnits, basisPoints],
        ),
      );
    }

    final int product = minorUnits * basisPoints;
    return Success<BasisPointSplit, MoneyFailure>(
      BasisPointSplit(
        floor: Money._(product ~/ divisor, currency),
        remainder: product.remainder(divisor).abs(),
        divisor: divisor,
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Comparison
  // -------------------------------------------------------------------------

  /// Orders two amounts of the **same** currency.
  ///
  /// Throws on a mismatch rather than returning a failure, because
  /// [Comparable] cannot express one — and sorting a mixed-currency list is a
  /// programmer error, not a user-correctable condition (ARCHITECTURE §8.1
  /// reserves exceptions for exactly that).
  @override
  int compareTo(Money other) {
    if (currency != other.currency) {
      throw ArgumentError(
        'Cannot compare ${currency.code} with ${other.currency.code}',
      );
    }
    return minorUnits.compareTo(other.minorUnits);
  }

  bool isGreaterThan(Money other) => compareTo(other) > 0;
  bool isLessThan(Money other) => compareTo(other) < 0;
  bool isAtLeast(Money other) => compareTo(other) >= 0;
  bool isAtMost(Money other) => compareTo(other) <= 0;

  // -------------------------------------------------------------------------
  // Serialisation — the ARCHITECTURE §8.5 split
  // -------------------------------------------------------------------------

  /// An exact decimal string: `"1234.56"`. No locale, no separators, no symbol.
  ///
  /// Used by the CSV exporter and JSON backup, which live in `lib/data` and
  /// must not import the presentation layer. The locale-aware display formatter
  /// is built on this and never re-derives decimal placement.
  String toDecimalString() => MoneyFormat.toDecimalString(minorUnits, currency);

  MoneyFailure? _requireSameCurrency(Money other) => currency == other.currency
      ? null
      : CurrencyMismatch(left: currency.code, right: other.currency.code);

  Result<Money, MoneyFailure> _bounded(
    int value,
    String operation,
    List<int> operands,
  ) {
    if (value.abs() > maxMoneyMinor) {
      return Failure<Money, MoneyFailure>(
        MoneyOverflow(operation: operation, operands: operands),
      );
    }
    return Success<Money, MoneyFailure>(Money._(value, currency));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Money &&
          runtimeType == other.runtimeType &&
          minorUnits == other.minorUnits &&
          currency == other.currency;

  @override
  int get hashCode => Object.hash(minorUnits, currency);

  @override
  String toString() => '${currency.code} ${toDecimalString()}';
}

/// The floor and remainder of a basis-point multiplication.
///
/// The largest-remainder method needs both: floors are assigned first, then
/// leftover units go to the largest remainders (ALLOCATION_ALGORITHM §5.1).
final class BasisPointSplit {
  const BasisPointSplit({
    required this.floor,
    required this.remainder,
    required this.divisor,
  });

  /// `(amount * basisPoints) ~/ divisor`.
  final Money floor;

  /// `(amount * basisPoints) % divisor`, always non-negative. Ranges
  /// `0 .. divisor-1`, and is the tie-break key for leftover distribution.
  final int remainder;

  /// The divisor used — 10000 in phase A, the relative total under override.
  final int divisor;

  @override
  String toString() =>
      'BasisPointSplit(floor: $floor, remainder: $remainder/$divisor)';
}
