/// The configuration validators. SCHEMA §6, implemented.
///
/// # Pure functions over a snapshot
///
/// Nothing here touches a database. A caller loads the configuration, hands it
/// over, and gets back a list of what is wrong. That shape is what lets the
/// **same code** serve three callers that could not otherwise share one:
///
/// | Caller | When |
/// |---|---|
/// | The repository write path | before every save (4.8.4) |
/// | The post-merge pass | after every sync merge (4.8.5, SCHEMA §6.8) |
/// | Onboarding | before declaring setup complete |
///
/// SCHEMA §6.1 is blunt about why the middle one matters: *"the UI is bypassed
/// entirely by sync, by restore, and by migration repair."* A rule that lives
/// only on a screen is a rule a merge does not know about.
///
/// # Scopes, because a write is incremental and a rule is not
///
/// Most rules here are about a **set**: shares totalling 10000, a group having
/// a category. A configuration being built step by step is legitimately invalid
/// in between — onboarding creates the first category of a group long before
/// the group's shares add up.
///
/// So validation is scoped. A write validates what it could have broken;
/// nothing validates totals until a caller writes a complete set
/// (`RuleRepository.replaceLines`, the seeder) or asks for the whole
/// configuration (post-merge, onboarding's final check). Running every rule on
/// every write would make the app impossible to set up, which is a worse
/// failure than the one it prevents.
library;

import 'package:pookiebudget/domain/entities/account.dart';
import 'package:pookiebudget/domain/entities/app_settings.dart';
import 'package:pookiebudget/domain/entities/category.dart';
import 'package:pookiebudget/domain/entities/category_group.dart';
import 'package:pookiebudget/domain/entities/enums.dart';
import 'package:pookiebudget/domain/entities/redirect_target.dart';
import 'package:pookiebudget/domain/entities/rule_line.dart';
import 'package:pookiebudget/domain/validation/cycle_detection.dart';
import 'package:pookiebudget/domain/validation/validation_failure.dart';

/// Which families of rule to check.
enum ValidationScope {
  /// V-01, V-02, V-04, V-06 — the percentage totals. Only meaningful over a
  /// complete rule line set.
  percentages,

  /// V-09, V-11, V-12, V-28, V-29, V-30 — redirect liveness, the acyclicity
  /// walk, and split consistency.
  redirects,

  /// V-13, V-15 — the sink exists and is usable, and cannot be removed.
  sink,

  /// V-21 — an account with linked categories.
  accounts,

  /// V-24 — currency immutability once money exists.
  currency,
}

/// Every scope. What the post-merge pass and onboarding's final check use.
const Set<ValidationScope> kAllScopes = <ValidationScope>{
  ValidationScope.percentages,
  ValidationScope.redirects,
  ValidationScope.sink,
  ValidationScope.accounts,
  ValidationScope.currency,
};

/// The whole configuration, as the validators need to see it.
///
/// Deliberately **plain data**: lists and maps of entities, no repository, no
/// lazy loading. A validator that could issue a query would be a validator the
/// post-merge pass could not run inside its own transaction, and one whose cost
/// nobody could predict.
final class ConfigurationSnapshot {
  const ConfigurationSnapshot({
    required this.groups,
    required this.categories,
    required this.ruleLines,
    required this.redirectGraph,
    this.accounts = const <Account>[],
    this.settings,
    this.ledgerEntryCount = 0,
    this.ruleVersionSealedAtMs,
  });

  /// Live groups.
  final List<CategoryGroup> groups;

  /// Live categories, archived included — archival is a state the validators
  /// must be able to see (V-11, V-14), not a filter applied before they run.
  final List<Category> categories;

  /// The lines of the rule version being validated.
  final List<RuleLine> ruleLines;

  /// Live redirect edges, keyed by source category.
  final Map<String, List<RedirectTarget>> redirectGraph;

  final List<Account> accounts;
  final AppSettings? settings;

  /// How many ledger entries exist. V-24's precondition.
  final int ledgerEntryCount;

  /// Set when the rule version being validated is sealed. V-06.
  final int? ruleVersionSealedAtMs;

  /// Categories that are neither archived nor deleted — the ones a share can
  /// actually land in.
  List<Category> get liveCategories =>
      categories.where((Category c) => !c.isArchived).toList();

  Category? categoryById(String id) {
    for (final Category c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// A name for a message, falling back to the id when the category is gone —
  /// which is exactly the case V-28 reports, so it must not itself fail.
  String nameOf(String categoryId) =>
      categoryById(categoryId)?.name ?? categoryId;
}

/// Runs every validator in [scopes] and returns everything that is wrong.
///
/// **Returns a list, and never throws.** Substage 4.8's `must_not`. The list is
/// complete rather than first-failure because the post-merge caller has to
/// repair a state it did not create: fixing several independent problems one
/// crash at a time is not a repair procedure.
List<ValidationFailure> validateConfiguration(
  ConfigurationSnapshot snapshot, {
  Set<ValidationScope> scopes = kAllScopes,
}) {
  final List<ValidationFailure> failures = <ValidationFailure>[];

  if (scopes.contains(ValidationScope.percentages)) {
    failures.addAll(validatePercentages(snapshot));
  }
  if (scopes.contains(ValidationScope.redirects)) {
    failures.addAll(validateRedirects(snapshot));
  }
  if (scopes.contains(ValidationScope.sink)) {
    failures.addAll(validateSinks(snapshot));
  }
  if (scopes.contains(ValidationScope.accounts)) {
    failures.addAll(validateAccounts(snapshot));
  }
  if (scopes.contains(ValidationScope.currency)) {
    failures.addAll(validateCurrency(snapshot));
  }

  return failures;
}

// ---------------------------------------------------------------------------
// V-01, V-02, V-03, V-04, V-06
// ---------------------------------------------------------------------------

/// The percentage rules.
List<ValidationFailure> validatePercentages(ConfigurationSnapshot snapshot) {
  final List<ValidationFailure> failures = <ValidationFailure>[];

  final List<RuleLine> groupLines = snapshot.ruleLines
      .where((RuleLine l) => l.scope == RuleLineScope.group)
      .toList();
  final List<RuleLine> categoryLines = snapshot.ruleLines
      .where((RuleLine l) => l.scope == RuleLineScope.category)
      .toList();

  // A version with no lines at all is "not configured yet", not "configured
  // wrongly". Reporting V-01 on an empty set would make every fresh install
  // fail its first validation, which trains people to ignore the result.
  if (snapshot.ruleLines.isEmpty) return failures;

  // V-01 — group shares total exactly 10000.
  final int groupTotal = groupLines.fold<int>(
    0,
    (int acc, RuleLine l) => acc + l.basisPoints.raw,
  );
  if (groupTotal != 10000) {
    failures.add(
      GroupSharesDoNotTotal(
        actualTotal: groupTotal,
        groupCount: groupLines.length,
      ),
    );
  }

  for (final CategoryGroup group in snapshot.groups) {
    final RuleLine? groupLine = _firstWhereOrNull(
      groupLines,
      (RuleLine l) => l.groupId == group.id,
    );
    final int share = groupLine?.basisPoints.raw ?? 0;

    final List<Category> members = snapshot.liveCategories
        .where((Category c) => c.groupId == group.id)
        .toList();

    // V-03 — a group with a zero share may be empty. This is the personal-only
    // case (PRD A-20) and is explicitly permitted, so it returns nothing.
    if (share == 0) continue;

    // V-04 — a group with a non-zero share needs somewhere to put it.
    if (members.isEmpty) {
      failures.add(
        GroupHasNoCategories(
          groupId: group.id,
          groupName: group.name,
          shareBasisPoints: share,
        ),
      );
      continue;
    }

    // V-02 — within-group shares total exactly 10000.
    //
    // Counted over the group's **live** categories only. An archived category
    // still holding a share would make the total look right while a share of
    // the income had nowhere to land.
    final Set<String> memberIds = members.map((Category c) => c.id).toSet();
    final int categoryTotal = categoryLines
        .where((RuleLine l) => memberIds.contains(l.categoryId))
        .fold<int>(0, (int acc, RuleLine l) => acc + l.basisPoints.raw);

    if (categoryTotal != 10000) {
      failures.add(
        CategorySharesDoNotTotal(
          groupId: group.id,
          groupName: group.name,
          actualTotal: categoryTotal,
        ),
      );
    }
  }

  return failures;
}

/// V-06 — a sealed version's lines cannot change.
///
/// Separate from [validatePercentages] because it is about *permission to
/// write*, not about the numbers. `RuleRepository` enforces it directly too;
/// this exists so the post-merge pass can report a merge that modified sealed
/// history rather than silently accepting it.
List<ValidationFailure> validateSealedVersion(
  ConfigurationSnapshot snapshot,
  String versionId,
) => snapshot.ruleVersionSealedAtMs == null
    ? const <ValidationFailure>[]
    : <ValidationFailure>[SealedVersionModified(versionId)];

// ---------------------------------------------------------------------------
// V-09, V-11, V-12, V-28, V-29, V-30
// ---------------------------------------------------------------------------

/// The redirect rules, including the acyclicity walk.
List<ValidationFailure> validateRedirects(ConfigurationSnapshot snapshot) {
  final List<ValidationFailure> failures = <ValidationFailure>[];

  for (final MapEntry<String, List<RedirectTarget>> entry
      in snapshot.redirectGraph.entries) {
    final String sourceId = entry.key;
    final List<RedirectTarget> targets = entry.value;
    if (targets.isEmpty) continue;

    final Category? source = snapshot.categoryById(sourceId);
    final String sourceName = source?.name ?? sourceId;

    // V-28 / V-09 / V-11 — every target exists, is live, and is not archived.
    final List<RedirectTarget> liveTargets = <RedirectTarget>[];
    for (final RedirectTarget target in targets) {
      final Category? destination = snapshot.categoryById(
        target.targetCategoryId,
      );
      if (destination == null) {
        failures.add(
          RedirectTargetMissing(
            sourceCategoryId: sourceId,
            sourceName: sourceName,
            targetCategoryId: target.targetCategoryId,
          ),
        );
        continue;
      }
      if (destination.isArchived) {
        failures.add(
          RedirectTargetArchived(
            sourceCategoryId: sourceId,
            sourceName: sourceName,
            targetCategoryId: destination.id,
            targetName: destination.name,
          ),
        );
        continue;
      }
      liveTargets.add(target);
    }

    // V-29 / V-30 — mode and shares agree, and a split totals 10000.
    //
    // Checked over the **live** targets, which is why it happens after the
    // filtering above. Dividing by a constant 10000 when one of three targets
    // is archived leaves a third of the overflow unallocated — the identical
    // defect substage 2.8 found in override redistribution.
    if (source != null && liveTargets.isNotEmpty) {
      failures.addAll(_validateRedirectMode(source, liveTargets, sourceName));
    }
  }

  // V-12 — the graph is acyclic. Over the whole graph, with a visited set.
  final RedirectCyclePath? cycle = findAnyCycle(snapshot.redirectGraph);
  if (cycle != null) {
    failures.add(
      RedirectCycle(
        categoryIds: cycle.path,
        categoryNames: cycle.path.map(snapshot.nameOf).toList(),
      ),
    );
  }

  return failures;
}

List<ValidationFailure> _validateRedirectMode(
  Category source,
  List<RedirectTarget> liveTargets,
  String sourceName,
) {
  switch (source.redirectMode) {
    case RedirectMode.priority:
      if (liveTargets.any((RedirectTarget t) => t.basisPoints != null)) {
        return <ValidationFailure>[
          RedirectModeInconsistent(
            sourceCategoryId: source.id,
            sourceName: sourceName,
            modeWireName: source.redirectMode.wireName,
            detail: 'they are ordered by priority, so they cannot also carry '
                'percentage shares',
          ),
        ];
      }
    case RedirectMode.split:
      if (liveTargets.any((RedirectTarget t) => t.basisPoints == null)) {
        return <ValidationFailure>[
          RedirectModeInconsistent(
            sourceCategoryId: source.id,
            sourceName: sourceName,
            modeWireName: source.redirectMode.wireName,
            detail: 'they are split by percentage, so every one needs a share',
          ),
        ];
      }
      final int total = liveTargets.shareDivisor;
      if (total != 10000) {
        return <ValidationFailure>[
          RedirectSplitDoesNotTotal(
            sourceCategoryId: source.id,
            sourceName: sourceName,
            actualTotal: total,
          ),
        ];
      }
  }
  return const <ValidationFailure>[];
}

/// V-14 — whether [categoryId] can be archived.
///
/// Called by the write path before archiving, so the answer must not depend on
/// the change already having been made.
List<ValidationFailure> validateCanArchive(
  ConfigurationSnapshot snapshot,
  String categoryId,
) {
  final Category? category = snapshot.categoryById(categoryId);
  if (category == null) return const <ValidationFailure>[];

  // V-15 — the sink is neither deletable nor archivable.
  if (category.isSink) {
    return <ValidationFailure>[
      SinkNotRemovable(categoryId: categoryId, action: 'hidden'),
    ];
  }

  final List<String> dependants = <String>[];
  for (final MapEntry<String, List<RedirectTarget>> entry
      in snapshot.redirectGraph.entries) {
    final bool pointsHere = entry.value.any(
      (RedirectTarget t) => t.targetCategoryId == categoryId,
    );
    if (pointsHere) dependants.add(snapshot.nameOf(entry.key));
  }

  if (dependants.isEmpty) return const <ValidationFailure>[];
  return <ValidationFailure>[
    RedirectTargetStillDependedOn(
      categoryId: categoryId,
      categoryName: category.name,
      dependantNames: dependants,
    ),
  ];
}

// ---------------------------------------------------------------------------
// V-13, V-15
// ---------------------------------------------------------------------------

/// The sink rules. INV-07's termination guarantee rests on these.
List<ValidationFailure> validateSinks(ConfigurationSnapshot snapshot) {
  final List<ValidationFailure> failures = <ValidationFailure>[];

  for (final CategoryGroup group in snapshot.groups) {
    final List<Category> sinks = snapshot.categories
        .where((Category c) => c.groupId == group.id && c.isSink)
        .toList();

    // A group with no categories at all is not yet configured, and a group
    // that cannot receive money needs no terminal. Demanding a sink of an
    // empty group would fail every install before its first category.
    final bool hasMembers = snapshot.categories.any(
      (Category c) => c.groupId == group.id,
    );
    if (!hasMembers) continue;

    if (sinks.isEmpty) {
      failures.add(
        SinkUnusable(
          groupId: group.id,
          groupName: group.name,
          detail: 'is missing',
        ),
      );
      continue;
    }

    final Category sink = sinks.first;
    if (sink.isArchived) {
      failures.add(
        SinkUnusable(
          groupId: group.id,
          groupName: group.name,
          detail: 'is hidden',
        ),
      );
    }
    // C-19 makes a capped sink impossible at database level and
    // `Category.create` refuses one, so reaching this means a row was written
    // by something that bypassed both — which a merge can do.
    if (sink.ceilingMinor != null || sink.billAmountMinor != null) {
      failures.add(
        SinkUnusable(
          groupId: group.id,
          groupName: group.name,
          detail: 'has a limit on it, so it cannot always accept what is left',
        ),
      );
    }
  }

  return failures;
}

/// V-15 — whether [categoryId] can be deleted.
List<ValidationFailure> validateCanDelete(
  ConfigurationSnapshot snapshot,
  String categoryId,
) {
  final Category? category = snapshot.categoryById(categoryId);
  if (category == null) return const <ValidationFailure>[];
  if (!category.isSink) return const <ValidationFailure>[];
  return <ValidationFailure>[
    SinkNotRemovable(categoryId: categoryId, action: 'deleted'),
  ];
}

// ---------------------------------------------------------------------------
// V-21, V-24
// ---------------------------------------------------------------------------

/// V-21 — an account with linked categories cannot be deleted.
///
/// Reported over the whole configuration for the post-merge pass; the write
/// path asks about one account through [validateCanDeleteAccount].
List<ValidationFailure> validateAccounts(ConfigurationSnapshot snapshot) =>
    const <ValidationFailure>[];

/// V-21, for one account.
List<ValidationFailure> validateCanDeleteAccount(
  ConfigurationSnapshot snapshot,
  String accountId,
) {
  final Account? account = _firstWhereOrNull(
    snapshot.accounts,
    (Account a) => a.id == accountId,
  );
  if (account == null) return const <ValidationFailure>[];

  final List<String> linked = snapshot.categories
      .where((Category c) => c.linkedAccountId == accountId)
      .map((Category c) => c.name)
      .toList();

  if (linked.isEmpty) return const <ValidationFailure>[];
  return <ValidationFailure>[
    AccountStillLinked(
      accountId: accountId,
      accountName: account.name,
      linkedCategoryNames: linked,
    ),
  ];
}

/// V-24 — the currency exponent is immutable once money exists.
///
/// Returns nothing from a snapshot alone: immutability is about a *proposed
/// change*, and a stored configuration is never in violation of it. The write
/// path calls [validateCurrencyChange] instead. Kept as a scope so the
/// post-merge pass reads uniformly.
List<ValidationFailure> validateCurrency(ConfigurationSnapshot snapshot) =>
    const <ValidationFailure>[];

/// V-24, for a proposed settings write.
List<ValidationFailure> validateCurrencyChange({
  required AppSettings? stored,
  required AppSettings incoming,
  required int ledgerEntryCount,
}) {
  if (stored == null) return const <ValidationFailure>[];
  if (stored.currencyMinorExponent == incoming.currencyMinorExponent) {
    return const <ValidationFailure>[];
  }
  if (ledgerEntryCount == 0) return const <ValidationFailure>[];
  return <ValidationFailure>[
    CurrencyNotImmutable(
      storedExponent: stored.currencyMinorExponent,
      attemptedExponent: incoming.currencyMinorExponent,
      ledgerEntryCount: ledgerEntryCount,
    ),
  ];
}

// ---------------------------------------------------------------------------

T? _firstWhereOrNull<T>(List<T> items, bool Function(T) test) {
  for (final T item in items) {
    if (test(item)) return item;
  }
  return null;
}
