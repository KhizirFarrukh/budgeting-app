/// Why a configuration is invalid.
///
/// The third failure taxonomy in this codebase, and the three divide by **what
/// can see the problem**:
///
/// | Taxonomy | Sees | Example |
/// |---|---|---|
/// | `EntityFailure` | one row | a ceiling on a category that is not a reserve |
/// | `ValidationFailure` | **the whole configuration** | shares that total 9999; a redirect cycle |
/// | `RepositoryFailure` | storage | a duplicate name; a sealed version |
///
/// A rule lands here when no single row can decide it. `RuleLine` cannot know
/// whether its siblings total 10000; `RedirectTarget` cannot know whether it
/// closes a loop three hops away. Those rules need the set, so they live where
/// the set is visible.
///
/// ## Every failure names its rule, and that is load-bearing
///
/// [rule] carries the `SCHEMA.md` §6 identifier — `V-01`, `V-12`, `V-29` — so a
/// failure reaching a log or a screen can be traced to the document that
/// required it without reading this file. ADR-008 exists because that stopped
/// being true: `V-28` named two different rules, and an identifier that names
/// two rules cannot do this job.
///
/// ## Nothing here throws
///
/// Substage 4.8's `must_not` is one line: *"do not throw from a validator —
/// return a typed failure."* Validators return **lists** of these, because the
/// post-merge entry point (4.8.5) must report everything wrong at once rather
/// than the first thing it noticed. A merge can produce several independent
/// problems, and fixing them one crash at a time is not a repair procedure.
library;

/// The base of the configuration validation taxonomy.
sealed class ValidationFailure {
  const ValidationFailure();

  /// The `SCHEMA.md` §6 rule identifier, e.g. `'V-12'`.
  String get rule;

  /// Plain-language explanation, **written for the user**, naming the offending
  /// value and what to change.
  ///
  /// SCHEMA §6.9 sets that bar for every blocking rule: *"the message names the
  /// offending value and what to change."* A message that says only "invalid
  /// configuration" leaves the user to guess which of thirty categories is
  /// wrong.
  String get describe;

  /// Which category, account or group the problem is attached to, when there is
  /// one. Stage 6 routes the user to the screen that fixes it.
  String? get subjectId => null;

  @override
  String toString() => '$rule: $describe';
}

// ---------------------------------------------------------------------------
// Percentages — V-01, V-02, V-04, V-06
// ---------------------------------------------------------------------------

/// Group shares do not total exactly 10000. SCHEMA V-01.
final class GroupSharesDoNotTotal extends ValidationFailure {
  const GroupSharesDoNotTotal({
    required this.actualTotal,
    required this.groupCount,
  });

  final int actualTotal;
  final int groupCount;

  /// Signed distance from 10000. Negative means short.
  int get difference => actualTotal - 10000;

  @override
  String get rule => 'V-01';

  @override
  String get describe {
    final int off = difference.abs();
    final String direction = difference < 0 ? 'short of' : 'over';
    return 'Your top-level percentages add up to ${_percent(actualTotal)}, '
        'which is ${_percent(off)} $direction 100%. Adjust one of the '
        '$groupCount groups.';
  }
}

/// One group's category shares do not total exactly 10000. SCHEMA V-02.
final class CategorySharesDoNotTotal extends ValidationFailure {
  const CategorySharesDoNotTotal({
    required this.groupId,
    required this.groupName,
    required this.actualTotal,
  });

  final String groupId;
  final String groupName;
  final int actualTotal;

  int get difference => actualTotal - 10000;

  @override
  String get rule => 'V-02';

  @override
  String? get subjectId => groupId;

  @override
  String get describe {
    final int off = difference.abs();
    final String direction = difference < 0 ? 'short of' : 'over';
    return 'The percentages inside $groupName add up to '
        '${_percent(actualTotal)}, which is ${_percent(off)} $direction 100%.';
  }
}

/// A group with a non-zero share has no live category to receive it.
/// SCHEMA V-04.
///
/// V-03 permits a group with a **zero** share to be empty — that is the
/// personal-only case (PRD A-20), and it is not a failure, which is why there
/// is no type for it.
final class GroupHasNoCategories extends ValidationFailure {
  const GroupHasNoCategories({
    required this.groupId,
    required this.groupName,
    required this.shareBasisPoints,
  });

  final String groupId;
  final String groupName;
  final int shareBasisPoints;

  @override
  String get rule => 'V-04';

  @override
  String? get subjectId => groupId;

  @override
  String get describe =>
      '$groupName is set to receive ${_percent(shareBasisPoints)} of your '
      'income but has no categories to put it in. Add one, or set the group '
      'to 0%.';
}

/// An attempt to change the lines of a sealed rule version. SCHEMA V-06.
final class SealedVersionModified extends ValidationFailure {
  const SealedVersionModified(this.versionId);

  final String versionId;

  @override
  String get rule => 'V-06';

  @override
  String? get subjectId => versionId;

  @override
  String get describe =>
      'These percentages have already been used to split income, so they can '
      'no longer be edited. Create a new version instead.';
}

// ---------------------------------------------------------------------------
// Redirects — V-09, V-11, V-12, V-28, V-29, V-30
// ---------------------------------------------------------------------------

/// A redirect points at a category that does not exist or is tombstoned.
/// SCHEMA V-09 / V-28.
///
/// **Blocking here and merely a warning at allocation time is deliberate.**
/// SCHEMA V-09: *"a save can refuse, an allocation cannot."* A user editing a
/// redirect can be told to fix it; money already in hand has to land somewhere,
/// so the engine routes it to the sink and reports a diagnostic instead.
final class RedirectTargetMissing extends ValidationFailure {
  const RedirectTargetMissing({
    required this.sourceCategoryId,
    required this.sourceName,
    required this.targetCategoryId,
  });

  final String sourceCategoryId;
  final String sourceName;
  final String targetCategoryId;

  @override
  String get rule => 'V-28';

  @override
  String? get subjectId => sourceCategoryId;

  @override
  String get describe =>
      'When $sourceName is full, its overflow is set to go to a category that '
      'no longer exists. Choose a different one, or remove the rule to use '
      'the catch-all.';
}

/// A redirect points at an archived category. SCHEMA V-11 / V-28.
final class RedirectTargetArchived extends ValidationFailure {
  const RedirectTargetArchived({
    required this.sourceCategoryId,
    required this.sourceName,
    required this.targetCategoryId,
    required this.targetName,
  });

  final String sourceCategoryId;
  final String sourceName;
  final String targetCategoryId;
  final String targetName;

  @override
  String get rule => 'V-11';

  @override
  String? get subjectId => sourceCategoryId;

  @override
  String get describe =>
      'When $sourceName is full, its overflow is set to go to $targetName, '
      'which is hidden. Un-hide $targetName or choose a different category.';
}

/// The redirect graph contains a cycle. SCHEMA V-12.
///
/// **Names the cycle.** SCHEMA V-12's disposition is *"block; name the cycle by
/// listing the categories in it"* — the user has to know which loop to break,
/// and a message that says only "cycle detected" makes them find it themselves
/// across a graph they cannot see.
final class RedirectCycle extends ValidationFailure {
  const RedirectCycle({required this.categoryIds, required this.categoryNames});

  /// The categories in the loop, in traversal order, **first repeated last** —
  /// so `[A, B, C, A]` reads as the path it is.
  final List<String> categoryIds;

  /// The same loop, as names.
  final List<String> categoryNames;

  @override
  String get rule => 'V-12';

  @override
  String? get subjectId => categoryIds.isEmpty ? null : categoryIds.first;

  @override
  String get describe =>
      'These categories send their overflow round in a circle: '
      '${categoryNames.join(" → ")}. Money would have nowhere to settle. '
      'Change one of them.';
}

/// Under `SPLIT`, a source's live targets' shares do not total 10000.
/// SCHEMA V-29.
final class RedirectSplitDoesNotTotal extends ValidationFailure {
  const RedirectSplitDoesNotTotal({
    required this.sourceCategoryId,
    required this.sourceName,
    required this.actualTotal,
  });

  final String sourceCategoryId;
  final String sourceName;
  final int actualTotal;

  @override
  String get rule => 'V-29';

  @override
  String? get subjectId => sourceCategoryId;

  @override
  String get describe =>
      'The split of $sourceName\'s overflow adds up to '
      '${_percent(actualTotal)} instead of 100%.';
}

/// Shares present under `PRIORITY`, or absent under `SPLIT`. SCHEMA V-30.
final class RedirectModeInconsistent extends ValidationFailure {
  const RedirectModeInconsistent({
    required this.sourceCategoryId,
    required this.sourceName,
    required this.modeWireName,
    required this.detail,
  });

  final String sourceCategoryId;
  final String sourceName;
  final String modeWireName;
  final String detail;

  @override
  String get rule => 'V-30';

  @override
  String? get subjectId => sourceCategoryId;

  @override
  String get describe =>
      'The overflow settings for $sourceName are inconsistent: $detail.';
}

// ---------------------------------------------------------------------------
// The sink — V-13, V-14, V-15
// ---------------------------------------------------------------------------

/// A group that can receive money has no sink, or its sink is unusable.
/// SCHEMA V-13.
final class SinkUnusable extends ValidationFailure {
  const SinkUnusable({
    required this.groupId,
    required this.groupName,
    required this.detail,
  });

  final String groupId;
  final String groupName;
  final String detail;

  @override
  String get rule => 'V-13';

  @override
  String? get subjectId => groupId;

  @override
  String get describe =>
      'The catch-all for $groupName $detail. Without one, overflowing money '
      'has nowhere to go.';
}

/// An attempt to archive a category another category redirects into.
/// SCHEMA V-14.
///
/// **Names the dependant**, which substage 4.8.3 requires explicitly. Telling
/// the user they cannot archive something without saying what depends on it
/// leaves them to search for it.
final class RedirectTargetStillDependedOn extends ValidationFailure {
  const RedirectTargetStillDependedOn({
    required this.categoryId,
    required this.categoryName,
    required this.dependantNames,
  });

  final String categoryId;
  final String categoryName;

  /// Every category whose overflow points here.
  final List<String> dependantNames;

  @override
  String get rule => 'V-14';

  @override
  String? get subjectId => categoryId;

  @override
  String get describe {
    final String dependants = dependantNames.length == 1
        ? dependantNames.single
        : '${dependantNames.take(dependantNames.length - 1).join(", ")} and '
              '${dependantNames.last}';
    return '$categoryName cannot be hidden: $dependants '
        '${dependantNames.length == 1 ? "sends its" : "send their"} overflow '
        'there. Change that first.';
  }
}

/// An attempt to delete or archive the sink. SCHEMA V-15.
final class SinkNotRemovable extends ValidationFailure {
  const SinkNotRemovable({required this.categoryId, required this.action});

  final String categoryId;

  /// `'deleted'` or `'hidden'`.
  final String action;

  @override
  String get rule => 'V-15';

  @override
  String? get subjectId => categoryId;

  @override
  String get describe =>
      'The catch-all category cannot be $action — it is where leftover money '
      'goes when everything else is full.';
}

// ---------------------------------------------------------------------------
// Accounts and currency — V-21, V-24
// ---------------------------------------------------------------------------

/// An account still linked to categories. SCHEMA V-21.
final class AccountStillLinked extends ValidationFailure {
  const AccountStillLinked({
    required this.accountId,
    required this.accountName,
    required this.linkedCategoryNames,
  });

  final String accountId;
  final String accountName;
  final List<String> linkedCategoryNames;

  @override
  String get rule => 'V-21';

  @override
  String? get subjectId => accountId;

  @override
  String get describe =>
      '$accountName still holds ${linkedCategoryNames.length} '
      '${linkedCategoryNames.length == 1 ? "category" : "categories"}: '
      '${linkedCategoryNames.join(", ")}. Move or unlink them first.';
}

/// The currency configuration changed after money was recorded. SCHEMA V-24.
final class CurrencyNotImmutable extends ValidationFailure {
  const CurrencyNotImmutable({
    required this.storedExponent,
    required this.attemptedExponent,
    required this.ledgerEntryCount,
  });

  final int storedExponent;
  final int attemptedExponent;
  final int ledgerEntryCount;

  @override
  String get rule => 'V-24';

  @override
  String get describe =>
      'The currency cannot be changed once money has been recorded. All '
      '$ledgerEntryCount saved amounts are stored in it.';
}

// ---------------------------------------------------------------------------

/// Renders basis points as a percentage string, by **integer arithmetic**.
///
/// Never `raw / 100` — that returns a floating-point value, and INV-01 admits
/// no exception for numbers that are "only for display". Guard G3 bans the
/// tokens outright. Same discipline as `BasisPoints.asPercentString`.
String _percent(int basisPoints) {
  final int whole = basisPoints ~/ 100;
  final int fraction = basisPoints % 100;
  if (fraction == 0) return '$whole%';
  return '$whole.${fraction.toString().padLeft(2, '0')}%';
}
