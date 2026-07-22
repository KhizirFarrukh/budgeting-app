/// Typed failures from money operations.
///
/// ARCHITECTURE §8.1: the domain layer returns typed results for expected
/// failures. An overflow, a currency mismatch, or unparseable input are all
/// *values* — the caller decides what to tell the user.
///
/// Substage 4.1's `common_pitfalls` names the alternative: *"Silent wrapping on
/// overflow, which turns a large income into a negative balance."*
sealed class MoneyFailure {
  const MoneyFailure();

  /// A message intent for the UI. Not user-facing copy — Stage 6 writes that —
  /// but enough context that a specific message can be written.
  String get describe;
}

/// An operation would exceed [maxMoneyMinor].
///
/// The bound is `MAX_MONEY_MINOR` from ALLOCATION_ALGORITHM §5.6, derived as
/// `floor((2^63 - 1) / 10000)`. It applies to **every** money value, not only
/// income, so that `amount * basisPoints` can never overflow.
final class MoneyOverflow extends MoneyFailure {
  const MoneyOverflow({required this.operation, required this.operands});

  final String operation;
  final List<int> operands;

  @override
  String get describe =>
      'Amount too large: $operation on ${operands.join(', ')} exceeds the '
      'maximum of $maxMoneyMinor minor units';

  @override
  String toString() => 'MoneyOverflow($operation, $operands)';
}

/// Arithmetic was attempted between two different currencies.
///
/// Substage 4.1's `must_not`: *"Do not allow arithmetic between different
/// currencies."* There is no exchange rate in this app (NG-05 forbids multi-
/// currency), so such an operation is always a programming error surfaced as a
/// value rather than a silent nonsense result.
final class CurrencyMismatch extends MoneyFailure {
  const CurrencyMismatch({required this.left, required this.right});

  final String left;
  final String right;

  @override
  String get describe => 'Cannot combine $left and $right amounts';

  @override
  String toString() => 'CurrencyMismatch($left, $right)';
}

/// Input could not be parsed as a monetary amount.
final class MoneyUnparseable extends MoneyFailure {
  const MoneyUnparseable({required this.input, required this.reason});

  final String input;
  final ParseFailureReason reason;

  @override
  String get describe => switch (reason) {
    ParseFailureReason.empty => 'Enter an amount',
    ParseFailureReason.notANumber => '"$input" is not a number',
    ParseFailureReason.tooManyDecimals =>
      '"$input" has more decimal places than this currency uses',
    ParseFailureReason.tooLarge => '"$input" is larger than the maximum amount',
  };

  @override
  String toString() => 'MoneyUnparseable($input, $reason)';
}

enum ParseFailureReason {
  empty,
  notANumber,

  /// More decimals than the currency exponent allows.
  ///
  /// **Rejected, never truncated** — substage 4.1.1 requires "a typed failure
  /// rather than truncating", because silently dropping a digit is how money
  /// goes missing.
  tooManyDecimals,
  tooLarge,
}

/// `MAX_MONEY_MINOR`, derived in ALLOCATION_ALGORITHM §5.6.
///
/// ```
/// floor((2^63 - 1) / 10000) = floor(9223372036854775807 / 10000)
///                           = 922337203685477
/// ```
///
/// Exact and tight: `922337203685477 * 10000` fits int64, and one more does
/// not. Bounding **every** money value by this means the worst arithmetic case
/// in the engine — three bounded values summed — reaches ≈2.77 × 10¹⁵ against
/// an int64 ceiling of ≈9.22 × 10¹⁸, a margin of roughly 3,300×.
const int maxMoneyMinor = 922337203685477;
