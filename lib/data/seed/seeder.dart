import 'package:drift/drift.dart';
import 'package:pookiebudget/data/database/database.dart';
import 'package:pookiebudget/data/repositories/repository_support.dart';
import 'package:pookiebudget/data/seed/seed_data.dart';
import 'package:pookiebudget/domain/entities/enums.dart';
import 'package:pookiebudget/domain/money/clock.dart';
import 'package:pookiebudget/domain/money/id_generator.dart';
import 'package:pookiebudget/domain/repositories/repository_failure.dart';
import 'package:pookiebudget/domain/result.dart';

/// Turns `seed_data.dart` into a valid starting configuration.
///
/// # Idempotent and non-destructive — two different promises
///
/// **Idempotent** (4.7.5): running it twice changes nothing. **Non-destructive**
/// (4.7.6): running it after the user has edited a suggestion leaves the edit
/// alone. They sound like the same guarantee and are not — a seeder could be
/// idempotent by writing the same rows every time and still destroy an edit by
/// overwriting it with the original.
///
/// Both fall out of one rule: **the seeder only ever inserts, and only when the
/// group is empty.** It has no update path. The named pitfall is *"a seeder
/// that overwrites user edits on every app launch"*, and the way to not
/// overwrite user edits is to have no code that writes over anything.
///
/// # What "already seeded" means
///
/// Presence of the group, not a flag in settings. A flag can disagree with the
/// database — after a restore, a merge, or a user deleting everything — and
/// when it does, the seeder either refuses to help an empty install or floods a
/// populated one. Asking the database what is actually there cannot be wrong
/// about it.
class Seeder {
  Seeder(this._db, this._ids, this._clock);

  final PookieDatabase _db;
  final IdGenerator _ids;
  final Clock _clock;

  /// Seeds the groups, categories, sinks and the first rule version.
  ///
  /// [currencyMinorExponent] scales the suggested amounts, which
  /// `seed_data.dart` holds in major units so the same seed set is correct in
  /// JPY, PKR and KWD alike.
  ///
  /// [includeBusiness] adds the business group and its sink. A personal-only
  /// user has **no `BUSINESS` row at all** rather than an inactive one
  /// (PRD A-20), so this genuinely omits it.
  ///
  /// Everything happens in one transaction. A half-seeded database is worse
  /// than an empty one: it looks ready and is not, and the second run would
  /// see a non-empty group and decline to finish the job.
  Future<Result<void, RepositoryFailure>> seed({
    required int currencyMinorExponent,
    required String deviceId,
    bool includeBusiness = false,
  }) => writeTransaction(_db, () async {
    final int nowMs = _clock.nowMs();
    final Map<CategoryGroupKind, int> groupShares = includeBusiness
        ? kBusinessGroupShares
        : kPersonalGroupShares;

    // Assert before writing, not after. These are the checks 4.7.3 asks for,
    // and they run against the numbers actually about to be stored rather than
    // against a copy of them in a test.
    _requireTotalsExact(groupShares, includeBusiness: includeBusiness);
    await _requireSettingsRow();

    // Reuse the editable version if there is one, rather than creating a
    // second. U-04 permits **at most one unsealed version at a time**, and
    // enabling business scope after onboarding seeds one more group into an
    // existing draft — a fresh version there would violate the index and abort
    // the whole seed.
    //
    // A *sealed* draft is a different situation: income has already been split
    // by it, so INV-11 forbids adding lines, and a new version is both correct
    // and permitted.
    final String? draftId = await _liveDraftRuleVersionId();
    final String ruleVersionId = draftId ?? _ids.newRandomId();
    final bool needsNewRuleVersion = draftId == null;
    bool wroteAnything = false;

    for (final CategoryGroupKind kind in groupShares.keys) {
      // The idempotency gate, per group rather than globally: enabling business
      // scope later must be able to seed that group alone, without the presence
      // of Spending making the whole call a no-op.
      final String? existingGroupId = await _liveGroupId(kind);
      if (existingGroupId != null) continue;

      wroteAnything = true;
      final String groupId = _ids.newRandomId();
      await _insertGroup(groupId, kind, nowMs, deviceId);

      final List<SuggestedCategory> suggestions = suggestionsFor(kind);
      final Map<String, int> shares = categoryShares(suggestions);
      final Map<String, String> categoryIds = <String, String>{};

      for (int i = 0; i < suggestions.length; i++) {
        final SuggestedCategory suggestion = suggestions[i];
        final String categoryId = _ids.newRandomId();
        categoryIds[suggestion.key] = categoryId;
        await _insertCategory(
          id: categoryId,
          groupId: groupId,
          suggestion: suggestion,
          sortOrder: i,
          exponent: currencyMinorExponent,
          nowMs: nowMs,
          deviceId: deviceId,
        );

        if (suggestion.isSink) {
          await _pointSettingsAtSink(kind, categoryId, nowMs);
        }
      }

      await _insertRuleLines(
        ruleVersionId: ruleVersionId,
        groupId: groupId,
        groupShare: groupShares[kind]!,
        categoryIds: categoryIds,
        shares: shares,
        nowMs: nowMs,
        deviceId: deviceId,
      );
    }

    // Only if something was actually seeded, and only if we minted the id. A
    // rule version with no lines is a configuration that fails V-01 the moment
    // anything reads it.
    if (wroteAnything && needsNewRuleVersion) {
      await _insertRuleVersion(ruleVersionId, nowMs, deviceId);
    }
  });

  /// Whether an empty database would be seeded by a call to [seed].
  Future<bool> needsSeeding({bool includeBusiness = false}) async {
    final Map<CategoryGroupKind, int> shares = includeBusiness
        ? kBusinessGroupShares
        : kPersonalGroupShares;
    for (final CategoryGroupKind kind in shares.keys) {
      if (await _liveGroupId(kind) == null) return true;
    }
    return false;
  }

  // ===========================================================================
  // Validation, before anything is written
  // ===========================================================================

  /// V-01 and V-02, checked at seed time.
  ///
  /// Substage 4.7.3: *"write the test that asserts this before writing the
  /// numbers, so a mistake cannot ship."* There is such a test — and this check
  /// as well, because a test proves the numbers were right when it last ran,
  /// while this refuses to write them if they are ever wrong again.
  void _requireTotalsExact(
    Map<CategoryGroupKind, int> groupShares, {
    required bool includeBusiness,
  }) {
    final int groupTotal = groupShares.values.fold<int>(
      0,
      (int acc, int share) => acc + share,
    );
    if (groupTotal != 10000) {
      reject(
        ConstraintViolation(
          'the seeded group shares total $groupTotal basis points, not 10000 '
          '(V-01). Onboarding would refuse the configuration this seeder '
          'produced.',
        ),
      );
    }

    for (final CategoryGroupKind kind in groupShares.keys) {
      final Map<String, int> shares = categoryShares(suggestionsFor(kind));
      final int total = shares.values.fold<int>(
        0,
        (int acc, int share) => acc + share,
      );
      if (total != 10000) {
        reject(
          ConstraintViolation(
            'the seeded category shares for ${kind.wireName} total $total '
            'basis points, not 10000 (V-02).',
          ),
        );
      }
    }
  }

  // ===========================================================================
  // Writes
  // ===========================================================================

  /// The settings row must already exist.
  ///
  /// Onboarding writes it first — the currency is chosen at step one, and this
  /// seeder needs its exponent to scale the suggested amounts. Making the
  /// dependency explicit here is better than the alternative, which is a seed
  /// that appears to succeed while leaving `personal_sink_category_id` unset:
  /// a configuration with a sink category that nothing points at, and INV-07
  /// silently unwired.
  Future<void> _requireSettingsRow() async {
    final AppSettingsRow? settings = await _db
        .select(_db.appSettingsTable)
        .getSingleOrNull();
    if (settings == null) {
      reject(
        const RecordNotFound(entity: 'settings row', id: 'singleton'),
      );
    }
  }

  /// The editable rule version, if one exists. U-04 permits at most one.
  Future<String?> _liveDraftRuleVersionId() async {
    final DistributionRuleVersionRow? row =
        await (_db.select(_db.distributionRuleVersions)..where(
              (t) => t.sealedAtMs.isNull() & t.isDeleted.equals(false),
            ))
            .getSingleOrNull();
    return row?.id;
  }

  Future<String?> _liveGroupId(CategoryGroupKind kind) async {
    final CategoryGroupRow? row =
        await (_db.select(_db.categoryGroups)..where(
              (t) => t.kind.equals(kind.wireName) & t.isDeleted.equals(false),
            ))
            .getSingleOrNull();
    return row?.id;
  }

  Future<void> _insertGroup(
    String id,
    CategoryGroupKind kind,
    int nowMs,
    String deviceId,
  ) async {
    await _db
        .into(_db.categoryGroups)
        .insert(
          CategoryGroupsCompanion.insert(
            id: id,
            kind: kind.wireName,
            name: kGroupNames[kind]!,
            sortOrder: kind.index,
            updatedAtMs: nowMs,
            updatedByDevice: deviceId,
            hlc: '',
          ),
        );
  }

  Future<void> _insertCategory({
    required String id,
    required String groupId,
    required SuggestedCategory suggestion,
    required int sortOrder,
    required int exponent,
    required int nowMs,
    required String deviceId,
  }) async {
    // INV-07 depends on the sink being able to accept any amount, and C-19
    // enforces it at the database. Asserting here as well means a mistake in
    // `seed_data.dart` names itself instead of surfacing as an opaque
    // constraint violation. 4.7.4: "assert at seed time that the sink is
    // uncapped, since the engine's termination guarantee depends on it."
    if (suggestion.isSink &&
        (suggestion.type != CategoryType.uncappedFlow ||
            suggestion.ceilingMajor != null ||
            suggestion.billMajor != null)) {
      reject(
        ConstraintViolation(
          'the seeded sink "${suggestion.key}" is capped or is not an open '
          'envelope. INV-07 — every unit of income lands somewhere — ends at '
          'the sink, so a capped sink is a termination guarantee that does '
          'not terminate.',
        ),
      );
    }

    await _db
        .into(_db.categories)
        .insert(
          CategoriesCompanion.insert(
            id: id,
            groupId: groupId,
            name: suggestion.name,
            type: suggestion.type.wireName,
            sortOrder: sortOrder,
            updatedAtMs: nowMs,
            updatedByDevice: deviceId,
            hlc: '',
            isSink: Value<bool>(suggestion.isSink),
            // The flag that makes an untouched suggestion distinguishable from
            // a user's own creation (4.7.2). It confers no protection — every
            // seeded category is renameable, retypeable, re-ceilingable and
            // removable, the sink's *existence* excepted.
            isSuggestedSeed: const Value<bool>(true),
            seedVersion: const Value<int>(kSeedVersion),
            ceilingMinor: Value<int?>(
              _toMinor(suggestion.ceilingMajor, exponent),
            ),
            billAmountMinor: Value<int?>(
              _toMinor(suggestion.billMajor, exponent),
            ),
            periodAnchorDay: Value<int?>(suggestion.periodAnchorDay),
          ),
        );
  }

  /// Scales a major-unit amount to minor units for the configured currency.
  ///
  /// Integer arithmetic only — repeated multiplication rather than `pow`, which
  /// returns a floating-point value and is banned on the money path by guard
  /// G3 and INV-01.
  int? _toMinor(int? major, int exponent) {
    if (major == null) return null;
    int scaled = major;
    for (int i = 0; i < exponent; i++) {
      scaled *= 10;
    }
    return scaled;
  }

  Future<void> _insertRuleVersion(
    String id,
    int nowMs,
    String deviceId,
  ) async {
    await _db
        .into(_db.distributionRuleVersions)
        .insert(
          DistributionRuleVersionsCompanion.insert(
            id: id,
            // Effective from the moment it is written, so an income event
            // recorded a second later resolves against it.
            effectiveFromMs: nowMs,
            createdAtMs: nowMs,
            updatedAtMs: nowMs,
            updatedByDevice: deviceId,
            hlc: '',
            // Deliberately left unsealed. The first income event seals it
            // (INV-11); sealing it here would freeze percentages the user has
            // not seen yet, and onboarding's whole job is to change them.
            note: const Value<String?>('Suggested defaults'),
          ),
        );

    // An UPDATE, never an insert. The settings row already exists — the seed
    // refuses to run otherwise — and inserting one here would mean inventing a
    // currency, which is the single value in this app that must never be
    // guessed (V-24 makes it immutable the moment money is recorded).
    //
    // `AND active_rule_version_id IS NULL` keeps it non-destructive: a user who
    // has already moved to a later version must not be dragged back.
    await _db.customUpdate(
      'UPDATE app_settings SET active_rule_version_id = ?, updated_at_ms = ? '
      "WHERE id = 'singleton' AND active_rule_version_id IS NULL",
      variables: <Variable<Object>>[Variable<String>(id), Variable<int>(nowMs)],
      updates: <TableInfo<Table, Object?>>{_db.appSettingsTable},
    );
  }

  Future<void> _insertRuleLines({
    required String ruleVersionId,
    required String groupId,
    required int groupShare,
    required Map<String, String> categoryIds,
    required Map<String, int> shares,
    required int nowMs,
    required String deviceId,
  }) async {
    await _db
        .into(_db.ruleLines)
        .insert(
          RuleLinesCompanion.insert(
            id: _ids.newRandomId(),
            ruleVersionId: ruleVersionId,
            scope: RuleLineScope.group.wireName,
            basisPoints: groupShare,
            updatedAtMs: nowMs,
            updatedByDevice: deviceId,
            hlc: '',
            groupId: Value<String?>(groupId),
          ),
        );

    for (final MapEntry<String, String> entry in categoryIds.entries) {
      await _db
          .into(_db.ruleLines)
          .insert(
            RuleLinesCompanion.insert(
              id: _ids.newRandomId(),
              ruleVersionId: ruleVersionId,
              scope: RuleLineScope.category.wireName,
              basisPoints: shares[entry.key]!,
              updatedAtMs: nowMs,
              updatedByDevice: deviceId,
              hlc: '',
              categoryId: Value<String?>(entry.value),
            ),
          );
    }
  }

  /// Records which category is the sink for its scope.
  ///
  /// OQ-07 was answered *yes to both*: a personal catch-all, and a second for
  /// business so overflowing business money stays in the business rather than
  /// landing in a household category.
  Future<void> _pointSettingsAtSink(
    CategoryGroupKind kind,
    String categoryId,
    int nowMs,
  ) async {
    final String column = kind == CategoryGroupKind.business
        ? 'business_sink_category_id'
        : 'personal_sink_category_id';
    // `AND <column> IS NULL` keeps this non-destructive: if the user has
    // already nominated a different sink, seeding a group must not silently
    // move it.
    await _db.customUpdate(
      'UPDATE app_settings SET $column = ?, updated_at_ms = ? '
      "WHERE id = 'singleton' AND $column IS NULL",
      variables: <Variable<Object>>[
        Variable<String>(categoryId),
        Variable<int>(nowMs),
      ],
      updates: <TableInfo<Table, Object?>>{_db.appSettingsTable},
    );
  }
}
