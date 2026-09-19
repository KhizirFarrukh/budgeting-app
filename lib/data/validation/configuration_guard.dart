import 'package:drift/drift.dart';
import 'package:pookiebudget/data/database/database.dart';
import 'package:pookiebudget/data/mappers/account_mappers.dart';
import 'package:pookiebudget/data/mappers/category_mappers.dart';
import 'package:pookiebudget/data/mappers/rule_mappers.dart';
import 'package:pookiebudget/data/mappers/settings_mappers.dart';
import 'package:pookiebudget/data/repositories/repository_support.dart';
import 'package:pookiebudget/domain/entities/account.dart';
import 'package:pookiebudget/domain/entities/category.dart';
import 'package:pookiebudget/domain/entities/category_group.dart';
import 'package:pookiebudget/domain/entities/redirect_target.dart';
import 'package:pookiebudget/domain/entities/rule_line.dart';
import 'package:pookiebudget/domain/repositories/repository_failure.dart';
import 'package:pookiebudget/domain/validation/validation_failure.dart';
import 'package:pookiebudget/domain/validation/validators.dart';

/// Loads the configuration and refuses a write that would invalidate it.
///
/// # This is substage 4.8.4, and it exists because of Stage 7
///
/// SCHEMA §6.1's governing rule: *"no invariant-protecting rule is enforced
/// only in the UI."* A screen can validate perfectly and still be bypassed
/// entirely — by a sync merge, by a restore, by migration repair. Each writes
/// through this layer and none of them opens a form.
///
/// So the check lives **below** every caller, in the repository write path. A
/// caller that forgets to validate still cannot persist invalid state, which is
/// the acceptance criterion and the reason the guard is not a convenience.
///
/// # Scoped, because a write is incremental and a rule is not
///
/// Each write validates only what it could plausibly have broken. Running every
/// rule on every write would make the app impossible to set up: onboarding
/// creates the first category of a group long before that group's shares total
/// 10000, and a guard that refused every step of a legitimate setup is a guard
/// someone removes. See `validators.dart` for the scope table.
///
/// # Called inside the caller's transaction
///
/// Every method here runs within the enclosing `writeTransaction`, so the
/// snapshot it reads is the one the write will land in, and a rejection rolls
/// the write back through [reject]. A guard that validated *before* the
/// transaction opened would be answering a question about a database that had
/// since moved on — which is the same race `recordReversal` closes with
/// `AND reversed_by_event_id IS NULL`.
class ConfigurationGuard {
  ConfigurationGuard(this._db);

  final PookieDatabase _db;

  // ===========================================================================
  // Loading
  // ===========================================================================

  /// Reads the whole configuration as plain data.
  ///
  /// **Archived categories are included.** Archival is a state the validators
  /// must be able to see — V-11 refuses a redirect into an archived category,
  /// V-14 refuses archiving one that is depended on — so filtering them out
  /// before validation would hide exactly what is being validated. Tombstoned
  /// rows are excluded: those are gone, not hidden.
  Future<ConfigurationSnapshot> loadSnapshot({String? ruleVersionId}) async {
    final List<CategoryGroupRow> groupRows =
        await (_db.select(_db.categoryGroups)
              ..where((t) => t.isDeleted.equals(false)))
            .get();

    final List<CategoryRow> categoryRows =
        await (_db.select(_db.categories)
              ..where((t) => t.isDeleted.equals(false)))
            .get();

    final List<RedirectTargetRow> redirectRows =
        await (_db.select(_db.redirectTargets)
              ..where((t) => t.isDeleted.equals(false)))
            .get();

    final List<AccountRow> accountRows =
        await (_db.select(_db.accounts)
              ..where((t) => t.isDeleted.equals(false)))
            .get();

    final AppSettingsRow? settingsRow = await _db
        .select(_db.appSettingsTable)
        .getSingleOrNull();

    // The version to validate: the one named, else the editable draft. A sealed
    // version's lines cannot change, so validating them on a write would report
    // failures about history nobody is editing.
    final String? versionId =
        ruleVersionId ?? await _draftVersionId() ?? settingsRow?.activeRuleVersionId;

    List<RuleLineRow> lineRows = const <RuleLineRow>[];
    int? sealedAtMs;
    if (versionId != null) {
      lineRows =
          await (_db.select(_db.ruleLines)..where(
                (t) =>
                    t.ruleVersionId.equals(versionId) &
                    t.isDeleted.equals(false),
              ))
              .get();
      final DistributionRuleVersionRow? version =
          await (_db.select(_db.distributionRuleVersions)
                ..where((t) => t.id.equals(versionId)))
              .getSingleOrNull();
      sealedAtMs = version?.sealedAtMs;
    }

    final Map<String, List<RedirectTarget>> graph =
        <String, List<RedirectTarget>>{};
    for (final RedirectTargetRow row in redirectRows) {
      graph
          .putIfAbsent(row.sourceCategoryId, () => <RedirectTarget>[])
          .add(redirectTargetFromRow(row));
    }

    return ConfigurationSnapshot(
      groups: groupRows.map(categoryGroupFromRow).toList(),
      categories: categoryRows.map(categoryFromRow).toList(),
      ruleLines: lineRows.map(ruleLineFromRow).toList(),
      redirectGraph: graph.map(
        (String source, List<RedirectTarget> targets) =>
            MapEntry<String, List<RedirectTarget>>(
              source,
              targets.inOfferOrder,
            ),
      ),
      accounts: accountRows.map(accountFromRow).toList(),
      settings: settingsRow == null ? null : appSettingsFromRow(settingsRow),
      ledgerEntryCount: await _ledgerEntryCount(),
      ruleVersionSealedAtMs: sealedAtMs,
    );
  }

  Future<String?> _draftVersionId() async {
    final DistributionRuleVersionRow? row =
        await (_db.select(_db.distributionRuleVersions)..where(
              (t) => t.sealedAtMs.isNull() & t.isDeleted.equals(false),
            ))
            .getSingleOrNull();
    return row?.id;
  }

  Future<int> _ledgerEntryCount() async {
    final QueryRow row = await _db
        .customSelect('SELECT COUNT(*) AS c FROM ledger_entries')
        .getSingle();
    return row.read<int>('c');
  }

  // ===========================================================================
  // Rejecting
  // ===========================================================================

  /// Rejects the enclosing write if [scopes] find anything wrong.
  ///
  /// Reports **every** violation, not the first. A caller that reached here
  /// without validating is exactly the one that benefits from the whole story.
  Future<void> rejectIfInvalid({
    required Set<ValidationScope> scopes,
    String? ruleVersionId,
  }) async {
    final ConfigurationSnapshot snapshot = await loadSnapshot(
      ruleVersionId: ruleVersionId,
    );
    final List<ValidationFailure> failures = validateConfiguration(
      snapshot,
      scopes: scopes,
    );
    if (failures.isNotEmpty) {
      reject(ConfigurationInvalid(failures));
    }
  }

  /// Rejects if the given validator finds anything.
  ///
  /// For the per-subject rules — V-14, V-15, V-21 — which ask about one record
  /// rather than the whole set.
  Future<void> rejectIf(
    List<ValidationFailure> Function(ConfigurationSnapshot) check,
  ) async {
    final ConfigurationSnapshot snapshot = await loadSnapshot();
    final List<ValidationFailure> failures = check(snapshot);
    if (failures.isNotEmpty) {
      reject(ConfigurationInvalid(failures));
    }
  }

  // ===========================================================================
  // 4.8.5 — the post-merge entry point
  // ===========================================================================

  /// Validates the whole configuration and **returns** what is wrong.
  ///
  /// Substage 4.8.5, and what Stage 7's merge calls (SCHEMA §6.8). It returns
  /// rather than rejecting for the same reason the balance verifier does: a
  /// merge produces a state nobody chose, and the response is to repair it —
  /// which requires a list to work from, not an exception that stops at the
  /// first problem.
  ///
  /// Every scope, always. **A merge is never trusted**, so there is no
  /// parameter to narrow this with.
  Future<List<ValidationFailure>> validateAll() async =>
      validateConfiguration(await loadSnapshot());
}
