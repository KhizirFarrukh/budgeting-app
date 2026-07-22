import 'package:pookiebudget/domain/entities/entity_failure.dart';
import 'package:pookiebudget/domain/entities/enums.dart';
import 'package:pookiebudget/domain/result.dart';

/// One line of an allocation result — the engine's output, before it becomes a
/// ledger entry.
///
/// ALLOCATION_ALGORITHM §2.2. This is **not** a stored table: it is what the
/// engine returns and what the preview screen renders. Substage 4.5 turns each
/// line into a `LedgerEntry` inside one transaction.
///
/// It carries no sync fields for that reason — an allocation line has no
/// independent existence to sync.
final class AllocationLine {
  const AllocationLine._({
    required this.categoryId,
    required this.amountMinor,
    required this.reason,
    required this.redirectedFromCategoryId,
    required this.hopCount,
  });

  /// Rejects a line that would misrepresent the allocation.
  ///
  /// - **Zero or negative amount.** *"A line item is never zero — a category
  ///   that accepts nothing produces no line, not a zero line."* A zero line
  ///   would write a ledger row recording that no money moved, inflating the
  ///   highest-volume table with rows carrying no information. That a category
  ///   accepted nothing is recorded in diagnostics, where it belongs.
  /// - **A redirect source that disagrees with the reason.** Set iff the reason
  ///   is `REDIRECT` or `SINK_TERMINAL` — this is what lets the UI say where
  ///   overflow came from, so a missing one silently degrades the explanation.
  /// - **A negative hop count.**
  static Result<AllocationLine, EntityFailure> create({
    required String categoryId,
    required int amountMinor,
    required AllocationReason reason,
    String? redirectedFromCategoryId,
    int hopCount = 0,
  }) {
    if (amountMinor <= 0) {
      return Failure<AllocationLine, EntityFailure>(
        NonPositiveAmount(field: 'amount_minor', value: amountMinor),
      );
    }
    if (reason.carriesRedirectSource != (redirectedFromCategoryId != null)) {
      return Failure<AllocationLine, EntityFailure>(
        RedirectSourceMismatch(
          reasonWireName: reason.wireName,
          hasSource: redirectedFromCategoryId != null,
        ),
      );
    }
    if (hopCount < 0) {
      return Failure<AllocationLine, EntityFailure>(NegativeHopCount(hopCount));
    }
    return Success<AllocationLine, EntityFailure>(
      AllocationLine._(
        categoryId: categoryId,
        amountMinor: amountMinor,
        reason: reason,
        redirectedFromCategoryId: redirectedFromCategoryId,
        hopCount: hopCount,
      ),
    );
  }

  final String categoryId;

  /// Always `> 0`.
  final int amountMinor;

  final AllocationReason reason;

  /// Set iff [reason] is `REDIRECT` or `SINK_TERMINAL`.
  final String? redirectedFromCategoryId;

  /// 0 for a base allocation; incremented per redirect.
  final int hopCount;

  Result<AllocationLine, EntityFailure> copyWith({
    String? categoryId,
    int? amountMinor,
    AllocationReason? reason,
    String? redirectedFromCategoryId,
    int? hopCount,
    bool clearRedirectedFrom = false,
  }) => AllocationLine.create(
    categoryId: categoryId ?? this.categoryId,
    amountMinor: amountMinor ?? this.amountMinor,
    reason: reason ?? this.reason,
    redirectedFromCategoryId: clearRedirectedFrom
        ? null
        : (redirectedFromCategoryId ?? this.redirectedFromCategoryId),
    hopCount: hopCount ?? this.hopCount,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AllocationLine &&
          runtimeType == other.runtimeType &&
          categoryId == other.categoryId &&
          amountMinor == other.amountMinor &&
          reason == other.reason &&
          redirectedFromCategoryId == other.redirectedFromCategoryId &&
          hopCount == other.hopCount;

  @override
  int get hashCode => Object.hash(
    categoryId,
    amountMinor,
    reason,
    redirectedFromCategoryId,
    hopCount,
  );

  @override
  String toString() =>
      'AllocationLine($categoryId, $amountMinor, ${reason.wireName}, '
      'hop $hopCount)';
}
