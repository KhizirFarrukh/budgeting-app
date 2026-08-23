/// The filters the PRD journeys actually ask for, as domain value objects.
///
/// Substage 4.4.5 names them: *"by group, by account, by archived state, by
/// date range"*. They live in one file, and every list method takes one of
/// these rather than a widening parameter list, for two reasons.
///
/// **A filter object cannot be half-applied.** A method with six optional
/// named parameters grows a seventh, and the one read path that was not
/// updated silently returns unfiltered rows. Here the filter is a single
/// value threaded to a single predicate builder in the data layer, so adding
/// a field is a compile-time visit to one place.
///
/// **Tombstone filtering is a field, not a caller's memory.** Substage 4.4.3
/// requires every read path to exclude tombstones by default, *"with an
/// explicit opt-in to include them for sync"*. Defaulting
/// [includeDeleted] to false on the query object means a caller who thinks
/// about nothing gets the safe answer — the pitfall named for this substage is
/// *"read paths that forget to filter tombstones, so deleted categories
/// reappear in pickers"*.
library;

/// Whether a list covers live rows, archived rows, or both.
///
/// A three-state enum rather than a nullable `bool` because *"archived: null"*
/// reads as *unknown* at the call site when it means *both*. Archiving is
/// distinct from deleting throughout the schema — an archived category is
/// hidden from pickers with its history intact — so the two are separate
/// fields here as well, never collapsed into one flag.
enum ArchivedFilter {
  /// Not archived. The default everywhere a user picks a category or account.
  liveOnly,

  /// Archived only — the "show hidden" view.
  archivedOnly,

  /// Both, for reports and history, where a hidden category's past still
  /// counts.
  any,
}

/// A half-open interval in UTC epoch milliseconds: `[fromMs, toMs)`.
///
/// **Half-open, and stated in the type.** SCHEMA period boundaries are
/// half-open so consecutive periods neither overlap nor leave a gap; a range
/// that was inclusive at both ends would double-count the entry that lands
/// exactly on a boundary, which is how a monthly report and a yearly report
/// stop agreeing (substage 8.7 reconciles them and would find it there
/// instead).
final class DateRange {
  const DateRange({required this.fromMs, required this.toMs});

  /// Inclusive lower bound, UTC epoch ms.
  final int fromMs;

  /// **Exclusive** upper bound, UTC epoch ms.
  final int toMs;

  /// Whether [atMs] falls inside this range.
  bool contains(int atMs) => atMs >= fromMs && atMs < toMs;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DateRange &&
          runtimeType == other.runtimeType &&
          fromMs == other.fromMs &&
          toMs == other.toMs;

  @override
  int get hashCode => Object.hash(fromMs, toMs);

  @override
  String toString() => 'DateRange([$fromMs, $toMs))';
}

/// Which categories to list.
///
/// Serves Q7 (*categories in a group, live, in sort order* — every picker) and
/// Q12 (*categories linked to an account, for its derived total*).
final class CategoryQuery {
  const CategoryQuery({
    this.groupId,
    this.linkedAccountId,
    this.archived = ArchivedFilter.liveOnly,
    this.includeDeleted = false,
  });

  /// Q7. Null lists across every group.
  final String? groupId;

  /// Q12. Null lists regardless of account link.
  final String? linkedAccountId;

  final ArchivedFilter archived;

  /// **Sync only.** True includes tombstoned rows, which no user-facing screen
  /// should ever ask for.
  final bool includeDeleted;

  @override
  String toString() =>
      'CategoryQuery(group: $groupId, account: $linkedAccountId, '
      '$archived, deleted: $includeDeleted)';
}

/// Which accounts to list.
final class AccountQuery {
  const AccountQuery({
    this.scopeWireName,
    this.archived = ArchivedFilter.liveOnly,
    this.includeDeleted = false,
  });

  /// `'PERSONAL'` or `'BUSINESS'`; null lists both.
  ///
  /// The wire name rather than the enum keeps this file importable from
  /// anywhere without dragging the whole enum library along, and matches what
  /// is actually stored.
  final String? scopeWireName;

  final ArchivedFilter archived;

  /// **Sync only.**
  final bool includeDeleted;

  @override
  String toString() =>
      'AccountQuery(scope: $scopeWireName, $archived, '
      'deleted: $includeDeleted)';
}

/// Which distribution rule versions to list.
///
/// [effectiveWithin] is substage 4.4.5's date-range filter for configuration
/// records: *"which percentages were in force last March"* is the question
/// US-034 asks when it displays a rule change alongside the income it
/// affected.
final class RuleVersionQuery {
  const RuleVersionQuery({
    this.effectiveWithin,
    this.sealed,
    this.includeDeleted = false,
  });

  /// Filters on `effective_from_ms`. Null lists every version.
  final DateRange? effectiveWithin;

  /// True lists only sealed versions, false only the editable draft, null
  /// both. U-04 permits at most one unsealed version at a time.
  final bool? sealed;

  /// **Sync only.**
  final bool includeDeleted;

  @override
  String toString() =>
      'RuleVersionQuery($effectiveWithin, sealed: $sealed, '
      'deleted: $includeDeleted)';
}
