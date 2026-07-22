import 'package:pookiebudget/domain/result.dart';

/// A percentage share, stored as an integer in basis points.
///
/// One basis point is one hundredth of one percent, so 10000 bp is exactly
/// 100%. Percentages are integers so that a group's shares total **exactly**
/// 10000 with no floating-point representation anywhere (INV-01, SCHEMA S-02).
///
/// Substage 4.1.4: *"constrained to 0 through 10000, rejecting out-of-range
/// values at construction."* An out-of-range value cannot exist, so no
/// downstream code has to defend against one.
final class BasisPoints implements Comparable<BasisPoints> {
  const BasisPoints._(this.raw);

  /// For literals known to be in range at compile time.
  ///
  /// Asserts in debug builds. Use [tryFrom] for anything arriving from a file,
  /// a sync payload, or user input.
  factory BasisPoints.checked(int value) {
    assert(
      value >= 0 && value <= 10000,
      'BasisPoints given $value, outside 0..10000. Use tryFrom for untrusted '
      'values.',
    );
    return BasisPoints._(value);
  }

  /// Rejects anything outside 0–10000 with a typed failure.
  static Result<BasisPoints, BasisPointsFailure> tryFrom(int value) {
    if (value < 0) {
      return Failure<BasisPoints, BasisPointsFailure>(
        BasisPointsFailure.negative(value),
      );
    }
    if (value > 10000) {
      return Failure<BasisPoints, BasisPointsFailure>(
        BasisPointsFailure.aboveMaximum(value),
      );
    }
    return Success<BasisPoints, BasisPointsFailure>(BasisPoints._(value));
  }

  /// 0% — a group that receives nothing.
  ///
  /// Valid, not an error: a personal-only user has no business group, and a
  /// group with a zero share may have no categories (SCHEMA V-03).
  static const BasisPoints zero = BasisPoints._(0);

  /// 100% — the total every level must reach exactly.
  static const BasisPoints full = BasisPoints._(10000);

  /// The raw integer, for arithmetic and storage.
  final int raw;

  bool get isZero => raw == 0;

  /// Formatted as a percentage for display, e.g. `3550` → `'35.50'`.
  ///
  /// **Built by integer arithmetic and string assembly**, never `raw / 100` —
  /// that returns a `double`, which is forbidden on the money path even in a
  /// message (INV-01). The same rule the money formatter follows
  /// (ARCHITECTURE §8.5).
  String get asPercentString {
    final int whole = raw ~/ 100;
    final int fraction = raw % 100;
    if (fraction == 0) return '$whole';
    return '$whole.${fraction.toString().padLeft(2, '0')}';
  }

  /// Whole percent, **floored**.
  ///
  /// Floored deliberately: 9999 bp reads as 99%, never 100%. The same reason
  /// `CeilingProgressBar` never rounds up to complete — showing 100% when
  /// something is not quite whole is a small lie that costs trust.
  int get wholePercent => raw ~/ 100;

  /// Whether a set of shares totals exactly 10000.
  ///
  /// The rule SCHEMA V-01 and V-02 enforce, and the precondition
  /// ALLOCATION_ALGORITHM §5.1 assumes for phase A.
  static bool sumsToFull(Iterable<BasisPoints> shares) => sum(shares) == 10000;

  /// The total of a set of shares — the split primitive's **divisor**.
  ///
  /// 10000 in phase A; the *relative* total under override redistribution.
  /// ALLOCATION_ALGORITHM §5.2 records why hardcoding 10000 passes every phase
  /// A vector and fails only under override.
  static int sum(Iterable<BasisPoints> shares) =>
      shares.fold<int>(0, (int acc, BasisPoints b) => acc + b.raw);

  @override
  int compareTo(BasisPoints other) => raw.compareTo(other.raw);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BasisPoints &&
          runtimeType == other.runtimeType &&
          raw == other.raw;

  @override
  int get hashCode => raw.hashCode;

  @override
  String toString() => '$asPercentString% ($raw bp)';
}

/// Why a basis-point value was rejected.
sealed class BasisPointsFailure {
  const BasisPointsFailure();

  const factory BasisPointsFailure.negative(int value) = _Negative;
  const factory BasisPointsFailure.aboveMaximum(int value) = _AboveMaximum;

  String get describe;
}

final class _Negative extends BasisPointsFailure {
  const _Negative(this.value);

  final int value;

  @override
  String get describe => 'A share cannot be negative (got $value)';

  @override
  String toString() => 'BasisPointsFailure.negative($value)';
}

final class _AboveMaximum extends BasisPointsFailure {
  const _AboveMaximum(this.value);

  final int value;

  @override
  String get describe =>
      'A share cannot exceed 100% (got $value basis points, maximum 10000)';

  @override
  String toString() => 'BasisPointsFailure.aboveMaximum($value)';
}
