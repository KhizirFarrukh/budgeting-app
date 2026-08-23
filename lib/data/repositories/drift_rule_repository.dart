import 'package:drift/drift.dart';
import 'package:pookiebudget/data/database/database.dart';
import 'package:pookiebudget/data/mappers/rule_mappers.dart';
import 'package:pookiebudget/data/repositories/repository_support.dart';
import 'package:pookiebudget/domain/entities/distribution_rule_version.dart';
import 'package:pookiebudget/domain/entities/enums.dart';
import 'package:pookiebudget/domain/entities/rule_line.dart';
import 'package:pookiebudget/domain/money/clock.dart';
import 'package:pookiebudget/domain/repositories/repository_failure.dart';
import 'package:pookiebudget/domain/repositories/repository_queries.dart';
import 'package:pookiebudget/domain/repositories/rule_repository.dart';
import 'package:pookiebudget/domain/result.dart';

/// The database-backed [RuleRepository].
///
/// Every mutating path here passes through [_rejectIfSealed] first. That is the
/// whole design: INV-11 holds only if *no* code path can edit a version an
/// income event has already used, and the reliable way to achieve that is one
/// gate that every path is forced through, rather than the same check written
/// out at seven call sites where the eighth will eventually be missed.
class DriftRuleRepository implements RuleRepository {
  DriftRuleRepository(this._db, this._clock);

  final PookieDatabase _db;
  final Clock _clock;

  // ===========================================================================
  // Versions
  // ===========================================================================

  @override
  Future<List<DistributionRuleVersion>> versions({
    RuleVersionQuery query = const RuleVersionQuery(),
  }) async {
    final List<DistributionRuleVersionRow> rows = await _versionSelect(
      query,
    ).get();
    return rows.map(ruleVersionFromRow).toList();
  }

  @override
  Stream<List<DistributionRuleVersion>> watchVersions({
    RuleVersionQuery query = const RuleVersionQuery(),
  }) => _versionSelect(query).watch().map(
    (List<DistributionRuleVersionRow> rows) =>
        rows.map(ruleVersionFromRow).toList(),
  );

  /// The single place a version list is filtered and ordered.
  ///
  /// Newest effective instant first, `id` breaking the tie — U-05 should
  /// prevent two versions sharing an instant, but a merge can produce it, and a
  /// history screen whose order changed between reads would be a bug report
  /// nobody could reproduce.
  SimpleSelectStatement<$DistributionRuleVersionsTable,
      DistributionRuleVersionRow> _versionSelect(RuleVersionQuery query) {
    final DateRange? range = query.effectiveWithin;
    return _db.select(_db.distributionRuleVersions)
      ..where(
        (t) =>
            tombstoneTerm(t.isDeleted, includeDeleted: query.includeDeleted) &
            (range == null
                ? matchAll
                : t.effectiveFromMs.isBiggerOrEqualValue(range.fromMs) &
                      // Half-open: `toMs` belongs to the next range, never this
                      // one. See `DateRange`.
                      t.effectiveFromMs.isSmallerThanValue(range.toMs)) &
            switch (query.sealed) {
              null => matchAll,
              true => t.sealedAtMs.isNotNull(),
              false => t.sealedAtMs.isNull(),
            },
      )
      ..orderBy([
        (t) => OrderingTerm(
          expression: t.effectiveFromMs,
          mode: OrderingMode.desc,
        ),
        (t) => OrderingTerm(expression: t.id),
      ]);
  }

  @override
  Future<DistributionRuleVersion?> versionById(
    String id, {
    bool includeDeleted = false,
  }) async {
    final DistributionRuleVersionRow? row = await _versionRow(
      id,
      includeDeleted,
    );
    return row == null ? null : ruleVersionFromRow(row);
  }

  @override
  Future<DistributionRuleVersion?> draftVersion() async {
    final List<DistributionRuleVersion> drafts = await versions(
      query: const RuleVersionQuery(sealed: false),
    );
    return drafts.isEmpty ? null : drafts.first;
  }

  @override
  Future<DistributionRuleVersion?> versionEffectiveAt(int atMs) async {
    final DistributionRuleVersionRow? row =
        await (_db.select(_db.distributionRuleVersions)
              ..where(
                (t) =>
                    t.effectiveFromMs.isSmallerOrEqualValue(atMs) &
                    tombstoneTerm(t.isDeleted, includeDeleted: false),
              )
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.effectiveFromMs,
                  mode: OrderingMode.desc,
                ),
                (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
              ])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : ruleVersionFromRow(row);
  }

  @override
  Future<Result<void, RepositoryFailure>> createVersion(
    DistributionRuleVersion version,
  ) => writeTransaction(_db, () async {
    await _db
        .into(_db.distributionRuleVersions)
        .insert(ruleVersionToCompanion(version));
  });

  @override
  Future<Result<void, RepositoryFailure>> updateVersion(
    DistributionRuleVersion version,
  ) => writeTransaction(_db, () async {
    await _rejectIfSealed(version.id);
    final int changed =
        await (_db.update(_db.distributionRuleVersions)..where(
              (t) =>
                  t.id.equals(version.id) &
                  tombstoneTerm(t.isDeleted, includeDeleted: false),
            ))
            .write(ruleVersionToCompanion(version));
    if (changed == 0) {
      reject(RecordNotFound(entity: 'rule version', id: version.id));
    }
  });

  @override
  Future<Result<void, RepositoryFailure>> sealVersion(
    String id, {
    required int atMs,
  }) => writeTransaction(_db, () async {
    final DistributionRuleVersionRow? row = await _versionRow(id, false);
    if (row == null) {
      reject(RecordNotFound(entity: 'rule version', id: id));
    }
    // Idempotent, and the timestamp is never refreshed. The moment history
    // became fixed is the moment of the *first* income event; overwriting it
    // with the latest would misreport when the rules stopped being editable.
    if (row.sealedAtMs != null) return;

    await (_db.update(
      _db.distributionRuleVersions,
    )..where((t) => t.id.equals(id))).write(
      DistributionRuleVersionsCompanion(
        sealedAtMs: Value<int?>(atMs),
        updatedAtMs: Value<int>(_clock.nowMs()),
      ),
    );
  });

  @override
  Future<Result<void, RepositoryFailure>> deleteVersion(String id) =>
      writeTransaction(_db, () async {
        final DistributionRuleVersionRow? row = await _versionRow(id, false);
        if (row == null) {
          reject(RecordNotFound(entity: 'rule version', id: id));
        }
        // A sealed version is referenced by income events. Hiding it would make
        // their history unexplainable, which is precisely what INV-11 forbids.
        if (row.sealedAtMs != null) {
          reject(
            RuleVersionSealed(versionId: id, sealedAtMs: row.sealedAtMs!),
          );
        }

        final int nowMs = _clock.nowMs();
        // The version and its lines go together. A tombstoned version whose
        // lines stayed live would leave shares that still total 10000 attached
        // to nothing, which every later validator would have to learn to
        // ignore.
        await _db.customUpdate(
          'UPDATE rule_lines '
          'SET is_deleted = 1, deleted_at_ms = ?, updated_at_ms = ? '
          'WHERE rule_version_id = ? AND is_deleted = 0',
          variables: <Variable<Object>>[
            Variable<int>(nowMs),
            Variable<int>(nowMs),
            Variable<String>(id),
          ],
          updates: <TableInfo<Table, Object?>>{_db.ruleLines},
        );
        await _db.customUpdate(
          'UPDATE distribution_rule_versions '
          'SET is_deleted = 1, deleted_at_ms = ?, updated_at_ms = ? '
          'WHERE id = ?',
          variables: <Variable<Object>>[
            Variable<int>(nowMs),
            Variable<int>(nowMs),
            Variable<String>(id),
          ],
          updates: <TableInfo<Table, Object?>>{_db.distributionRuleVersions},
        );
      });

  Future<DistributionRuleVersionRow?> _versionRow(
    String id,
    bool includeDeleted,
  ) => (_db.select(_db.distributionRuleVersions)..where(
        (t) =>
            t.id.equals(id) &
            tombstoneTerm(t.isDeleted, includeDeleted: includeDeleted),
      ))
      .getSingleOrNull();

  /// The gate every mutating path passes through.
  ///
  /// Rejects with [RecordNotFound] when the version is gone and with
  /// [RuleVersionSealed] when it has been used to split income.
  Future<void> _rejectIfSealed(String versionId) async {
    final DistributionRuleVersionRow? row = await _versionRow(versionId, false);
    if (row == null) {
      reject(RecordNotFound(entity: 'rule version', id: versionId));
    }
    if (row.sealedAtMs != null) {
      reject(
        RuleVersionSealed(versionId: versionId, sealedAtMs: row.sealedAtMs!),
      );
    }
  }

  // ===========================================================================
  // Lines
  // ===========================================================================

  @override
  Future<List<RuleLine>> linesFor(
    String versionId, {
    RuleLineScope? scope,
    bool includeDeleted = false,
  }) async {
    final List<RuleLineRow> rows = await _lineSelect(
      versionId,
      scope: scope,
      includeDeleted: includeDeleted,
    ).get();
    return rows.map(ruleLineFromRow).toList();
  }

  @override
  Stream<List<RuleLine>> watchLinesFor(String versionId) =>
      _lineSelect(versionId).watch().map(
        (List<RuleLineRow> rows) => rows.map(ruleLineFromRow).toList(),
      );

  SimpleSelectStatement<$RuleLinesTable, RuleLineRow> _lineSelect(
    String versionId, {
    RuleLineScope? scope,
    bool includeDeleted = false,
  }) =>
      _db.select(_db.ruleLines)
        ..where(
          (t) =>
              t.ruleVersionId.equals(versionId) &
              tombstoneTerm(t.isDeleted, includeDeleted: includeDeleted) &
              (scope == null ? matchAll : t.scope.equals(scope.wireName)),
        )
        // Stable across devices, so the engine's group pass and category pass
        // iterate identically wherever they run (INV-08).
        ..orderBy([
          (t) => OrderingTerm(expression: t.scope),
          (t) => OrderingTerm(expression: t.id),
        ]);

  @override
  Future<Result<void, RepositoryFailure>> createLine(RuleLine line) =>
      writeTransaction(_db, () async {
        await _rejectIfSealed(line.ruleVersionId);
        await _db.into(_db.ruleLines).insert(ruleLineToCompanion(line));
      });

  @override
  Future<Result<void, RepositoryFailure>> updateLine(RuleLine line) =>
      writeTransaction(_db, () async {
        await _rejectIfSealed(line.ruleVersionId);
        final int changed =
            await (_db.update(_db.ruleLines)..where(
                  (t) =>
                      t.id.equals(line.id) &
                      tombstoneTerm(t.isDeleted, includeDeleted: false),
                ))
                .write(ruleLineToCompanion(line));
        if (changed == 0) {
          reject(RecordNotFound(entity: 'rule line', id: line.id));
        }
      });

  @override
  Future<Result<void, RepositoryFailure>> deleteLine(String id) =>
      writeTransaction(_db, () async {
        final RuleLineRow? row =
            await (_db.select(_db.ruleLines)..where(
                  (t) =>
                      t.id.equals(id) &
                      tombstoneTerm(t.isDeleted, includeDeleted: false),
                ))
                .getSingleOrNull();
        if (row == null) {
          reject(RecordNotFound(entity: 'rule line', id: id));
        }
        await _rejectIfSealed(row.ruleVersionId);

        final int nowMs = _clock.nowMs();
        await _db.customUpdate(
          'UPDATE rule_lines '
          'SET is_deleted = 1, deleted_at_ms = ?, updated_at_ms = ? '
          'WHERE id = ?',
          variables: <Variable<Object>>[
            Variable<int>(nowMs),
            Variable<int>(nowMs),
            Variable<String>(id),
          ],
          updates: <TableInfo<Table, Object?>>{_db.ruleLines},
        );
      });

  @override
  Future<Result<void, RepositoryFailure>> replaceLines(
    String versionId,
    List<RuleLine> lines,
  ) => writeTransaction(_db, () async {
    await _rejectIfSealed(versionId);

    final Set<String> kept = lines.map((RuleLine l) => l.id).toSet();
    final List<RuleLineRow> existing = await _lineSelect(versionId).get();
    final int nowMs = _clock.nowMs();

    // Tombstone what the new set drops, rather than deleting every line and
    // re-inserting. A line that survives an edit keeps its id, so the other
    // device merges an *update* to a share it already knows about instead of a
    // delete racing a create — the case Stage 7 has the least room to get
    // right.
    for (final RuleLineRow row in existing) {
      if (kept.contains(row.id)) continue;
      await _db.customUpdate(
        'UPDATE rule_lines '
        'SET is_deleted = 1, deleted_at_ms = ?, updated_at_ms = ? '
        'WHERE id = ?',
        variables: <Variable<Object>>[
          Variable<int>(nowMs),
          Variable<int>(nowMs),
          Variable<String>(row.id),
        ],
        updates: <TableInfo<Table, Object?>>{_db.ruleLines},
      );
    }

    for (final RuleLine line in lines) {
      await _db
          .into(_db.ruleLines)
          .insertOnConflictUpdate(ruleLineToCompanion(line));
    }
  });
}
