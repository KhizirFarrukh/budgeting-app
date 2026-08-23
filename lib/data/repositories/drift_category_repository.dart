import 'package:drift/drift.dart';
import 'package:pookiebudget/data/database/database.dart';
import 'package:pookiebudget/data/mappers/category_mappers.dart';
import 'package:pookiebudget/data/repositories/repository_support.dart';
import 'package:pookiebudget/domain/entities/category.dart';
import 'package:pookiebudget/domain/entities/category_group.dart';
import 'package:pookiebudget/domain/entities/enums.dart';
import 'package:pookiebudget/domain/entities/redirect_target.dart';
import 'package:pookiebudget/domain/money/clock.dart';
import 'package:pookiebudget/domain/repositories/category_repository.dart';
import 'package:pookiebudget/domain/repositories/repository_failure.dart';
import 'package:pookiebudget/domain/repositories/repository_queries.dart';
import 'package:pookiebudget/domain/result.dart';

/// The database-backed [CategoryRepository].
///
/// ## Why a [Clock] is the only other dependency
///
/// Soft delete is the one write this class *originates* rather than relays: the
/// caller says "delete this", and the repository decides what the row becomes.
/// That needs a deletion timestamp, and INV-09 forbids reading the system clock
/// anywhere but the `Clock` implementation — guard G4 enforces it. Every other
/// write arrives fully formed, sync stamp included, so no clock is involved.
///
/// ## Why partial companions appear here and nowhere else
///
/// `category_mappers.dart` writes every column on every write, so an update
/// cannot leave a stale value behind. The tombstone updates below deliberately
/// break that rule, writing only the three columns that change. That is correct
/// *because* they are originated writes: the repository knows exactly which
/// fields it is changing and has no opinion about the rest, so reading the row,
/// rebuilding the entity and writing it whole would risk overwriting a
/// concurrent change with a value that was already stale when it was read.
class DriftCategoryRepository implements CategoryRepository {
  DriftCategoryRepository(this._db, this._clock);

  final PookieDatabase _db;
  final Clock _clock;

  // ===========================================================================
  // Groups
  // ===========================================================================

  @override
  Future<List<CategoryGroup>> groups({bool includeDeleted = false}) async {
    final List<CategoryGroupRow> rows =
        await (_db.select(_db.categoryGroups)
              ..where(
                (t) => tombstoneTerm(
                  t.isDeleted,
                  includeDeleted: includeDeleted,
                ),
              )
              ..orderBy([
                (t) => OrderingTerm(expression: t.sortOrder),
                (t) => OrderingTerm(expression: t.id),
              ]))
            .get();
    return rows.map(categoryGroupFromRow).toList();
  }

  @override
  Stream<List<CategoryGroup>> watchGroups({bool includeDeleted = false}) =>
      (_db.select(_db.categoryGroups)
            ..where(
              (t) => tombstoneTerm(t.isDeleted, includeDeleted: includeDeleted),
            )
            ..orderBy([
              (t) => OrderingTerm(expression: t.sortOrder),
              (t) => OrderingTerm(expression: t.id),
            ]))
          .watch()
          .map(
            (List<CategoryGroupRow> rows) =>
                rows.map(categoryGroupFromRow).toList(),
          );

  @override
  Future<CategoryGroup?> groupById(
    String id, {
    bool includeDeleted = false,
  }) async {
    final CategoryGroupRow? row = await _groupRow(id, includeDeleted);
    return row == null ? null : categoryGroupFromRow(row);
  }

  @override
  Future<CategoryGroup?> groupByKind(CategoryGroupKind kind) async {
    final CategoryGroupRow? row =
        await (_db.select(_db.categoryGroups)..where(
              (t) =>
                  t.kind.equals(kind.wireName) &
                  tombstoneTerm(t.isDeleted, includeDeleted: false),
            ))
            .getSingleOrNull();
    return row == null ? null : categoryGroupFromRow(row);
  }

  @override
  Future<Result<void, RepositoryFailure>> createGroup(CategoryGroup group) =>
      writeTransaction(_db, () async {
        // U-03 — one live group per kind. Checked here as well as by the
        // partial unique index so the caller learns *which* rule it broke; the
        // index can only report that something collided.
        final CategoryGroup? existing = await groupByKind(group.kind);
        if (existing != null && existing.id != group.id) {
          reject(
            DuplicateName(entity: 'group', name: group.kind.wireName),
          );
        }
        await _db
            .into(_db.categoryGroups)
            .insert(categoryGroupToCompanion(group));
      });

  @override
  Future<Result<void, RepositoryFailure>> updateGroup(CategoryGroup group) =>
      writeTransaction(_db, () async {
        final int changed =
            await (_db.update(_db.categoryGroups)..where(
                  (t) =>
                      t.id.equals(group.id) &
                      tombstoneTerm(t.isDeleted, includeDeleted: false),
                ))
                .write(categoryGroupToCompanion(group));
        if (changed == 0) {
          reject(RecordNotFound(entity: 'group', id: group.id));
        }
      });

  @override
  Future<Result<void, RepositoryFailure>> deleteGroup(String id) =>
      writeTransaction(_db, () async {
        final CategoryGroupRow? row = await _groupRow(id, false);
        if (row == null) {
          reject(RecordNotFound(entity: 'group', id: id));
        }

        // A group whose categories outlived it would leave them unreachable
        // from every picker while their money stayed on the ledger — money
        // present in the totals and absent from the screen.
        final List<CategoryRow> members =
            await (_db.select(_db.categories)..where(
                  (t) =>
                      t.groupId.equals(id) &
                      tombstoneTerm(t.isDeleted, includeDeleted: false),
                ))
                .get();
        if (members.isNotEmpty) {
          reject(
            RecordStillReferenced(
              entity: 'group',
              id: id,
              referenceCount: members.length,
              referencedBy: 'categories',
            ),
          );
        }

        await _tombstone(_db.categoryGroups, id);
      });

  Future<CategoryGroupRow?> _groupRow(String id, bool includeDeleted) =>
      (_db.select(_db.categoryGroups)..where(
            (t) =>
                t.id.equals(id) &
                tombstoneTerm(t.isDeleted, includeDeleted: includeDeleted),
          ))
          .getSingleOrNull();

  // ===========================================================================
  // Categories
  // ===========================================================================

  @override
  Future<List<Category>> categories({
    CategoryQuery query = const CategoryQuery(),
  }) async {
    final List<CategoryRow> rows = await _categorySelect(query).get();
    return rows.map(categoryFromRow).toList();
  }

  @override
  Stream<List<Category>> watchCategories({
    CategoryQuery query = const CategoryQuery(),
  }) => _categorySelect(query).watch().map(
    (List<CategoryRow> rows) => rows.map(categoryFromRow).toList(),
  );

  /// The single place a category list is filtered and ordered.
  ///
  /// Every read of `categories` goes through here — list, stream and the
  /// account-linked lookup alike. That is what makes substage 4.4.3's *"every
  /// read path filters tombstones by default"* a structural property rather
  /// than a habit: there is one read path to get wrong.
  SimpleSelectStatement<$CategoriesTable, CategoryRow> _categorySelect(
    CategoryQuery query,
  ) =>
      _db.select(_db.categories)
        ..where(
          (t) =>
              tombstoneTerm(t.isDeleted, includeDeleted: query.includeDeleted) &
              archivedTerm(t.isArchived, query.archived) &
              optionalEquals(t.groupId, query.groupId) &
              optionalEquals(t.linkedAccountId, query.linkedAccountId),
        )
        // `sort_order` is the first allocation tie-break key
        // (ALLOCATION_ALGORITHM §5.1) and a merge can produce two categories
        // sharing one, so `id` makes the order total and the engine
        // deterministic (INV-08).
        ..orderBy([
          (t) => OrderingTerm(expression: t.sortOrder),
          (t) => OrderingTerm(expression: t.id),
        ]);

  @override
  Future<Category?> categoryById(
    String id, {
    bool includeDeleted = false,
  }) async {
    final CategoryRow? row = await _categoryRow(id, includeDeleted);
    return row == null ? null : categoryFromRow(row);
  }

  @override
  Future<Category?> sinkForGroup(String groupId) async {
    final CategoryRow? row =
        await (_db.select(_db.categories)..where(
              (t) =>
                  t.groupId.equals(groupId) &
                  t.isSink.equals(true) &
                  tombstoneTerm(t.isDeleted, includeDeleted: false),
            ))
            .getSingleOrNull();
    return row == null ? null : categoryFromRow(row);
  }

  @override
  Future<Result<void, RepositoryFailure>> createCategory(Category category) =>
      writeTransaction(_db, () async {
        await _rejectIfNameTaken(category);
        await _db.into(_db.categories).insert(categoryToCompanion(category));
      });

  @override
  Future<Result<void, RepositoryFailure>> updateCategory(Category category) =>
      writeTransaction(_db, () async {
        await _rejectIfNameTaken(category);
        final int changed =
            await (_db.update(_db.categories)..where(
                  (t) =>
                      t.id.equals(category.id) &
                      tombstoneTerm(t.isDeleted, includeDeleted: false),
                ))
                .write(categoryToCompanion(category));
        if (changed == 0) {
          reject(RecordNotFound(entity: 'category', id: category.id));
        }
      });

  @override
  Future<Result<void, RepositoryFailure>> deleteCategory(String id) =>
      writeTransaction(_db, () async {
        final CategoryRow? row = await _categoryRow(id, false);
        if (row == null) {
          reject(RecordNotFound(entity: 'category', id: id));
        }
        // INV-07: the terminal must exist for every unit of income to land
        // somewhere. Deleting it does not fail loudly at allocation time — it
        // leaves the last parcel of a redirect chain with nowhere to go.
        if (row.isSink) {
          reject(SinkProtected(categoryId: id, action: 'deleted'));
        }

        // Overflow aimed at a deleted category is overflow with nowhere to go.
        final List<RedirectTargetRow> incoming =
            await (_db.select(_db.redirectTargets)..where(
                  (t) =>
                      t.targetCategoryId.equals(id) &
                      tombstoneTerm(t.isDeleted, includeDeleted: false),
                ))
                .get();
        if (incoming.isNotEmpty) {
          reject(
            RecordStillReferenced(
              entity: 'category',
              id: id,
              referenceCount: incoming.length,
              referencedBy: 'redirect targets',
            ),
          );
        }

        // NOTE: rule lines pointing at this category are deliberately **not**
        // checked here. A sealed version's lines must survive the deletion or
        // history stops being explainable (INV-11), while a draft version's
        // lines must be redistributed so the shares still total 10000 (V-02) —
        // which is a validator's judgement over the whole set, not a
        // referential check over one row. Substage 4.8 owns it and wires it
        // into this write path.

        await _tombstone(_db.categories, id);
      });

  @override
  Future<Result<void, RepositoryFailure>> setCategoryArchived(
    String id, {
    required bool archived,
  }) => writeTransaction(_db, () async {
    final CategoryRow? row = await _categoryRow(id, false);
    if (row == null) {
      reject(RecordNotFound(entity: 'category', id: id));
    }
    if (row.isSink && archived) {
      reject(SinkProtected(categoryId: id, action: 'archived'));
    }
    await (_db.update(_db.categories)..where((t) => t.id.equals(id))).write(
      CategoriesCompanion(
        isArchived: Value<bool>(archived),
        updatedAtMs: Value<int>(_clock.nowMs()),
      ),
    );
  });

  Future<CategoryRow?> _categoryRow(String id, bool includeDeleted) =>
      (_db.select(_db.categories)..where(
            (t) =>
                t.id.equals(id) &
                tombstoneTerm(t.isDeleted, includeDeleted: includeDeleted),
          ))
          .getSingleOrNull();

  /// U-01 — a category name is unique within its group among live,
  /// non-archived rows.
  ///
  /// The index is partial on `is_archived = 0 AND is_deleted = 0`, and this
  /// check matches it exactly. Archiving deliberately frees the name: a user
  /// who archived last year's "Eid" goal must be able to create this year's.
  Future<void> _rejectIfNameTaken(Category category) async {
    if (category.isArchived) return;
    // `.get()` rather than `.getSingleOrNull()`: the index guarantees at most
    // one clash, but a read that *throws* when its own precondition is violated
    // turns a duplicate-name message into a crash. Asking whether any row
    // matches answers the question either way.
    final List<CategoryRow> clashes =
        await (_db.select(_db.categories)..where(
              (t) =>
                  t.groupId.equals(category.groupId) &
                  t.name.equals(category.name) &
                  t.isArchived.equals(false) &
                  t.isDeleted.equals(false) &
                  t.id.equals(category.id).not(),
            ))
            .get();
    if (clashes.isNotEmpty) {
      reject(DuplicateName(entity: 'category', name: category.name));
    }
  }

  // ===========================================================================
  // Redirect targets (ADR-006)
  // ===========================================================================

  @override
  Future<List<RedirectTarget>> redirectTargetsFor(
    String sourceCategoryId, {
    bool includeDeleted = false,
  }) async {
    final List<RedirectTargetRow> rows =
        await (_db.select(_db.redirectTargets)..where(
              (t) =>
                  t.sourceCategoryId.equals(sourceCategoryId) &
                  tombstoneTerm(t.isDeleted, includeDeleted: includeDeleted),
            ))
            .get();
    // Sorted through the domain extension rather than by SQL, so the engine's
    // contract order (`priority ASC, id ASC`) has exactly one definition. A
    // second one in an ORDER BY clause would be a second thing to keep in step
    // with ALLOCATION_ALGORITHM §3.10.
    return rows.map(redirectTargetFromRow).toList().inOfferOrder;
  }

  @override
  Stream<List<RedirectTarget>> watchRedirectTargetsFor(
    String sourceCategoryId,
  ) =>
      (_db.select(_db.redirectTargets)..where(
            (t) =>
                t.sourceCategoryId.equals(sourceCategoryId) &
                tombstoneTerm(t.isDeleted, includeDeleted: false),
          ))
          .watch()
          .map(
            (List<RedirectTargetRow> rows) =>
                rows.map(redirectTargetFromRow).toList().inOfferOrder,
          );

  @override
  Future<Map<String, List<RedirectTarget>>> redirectGraph() async {
    final List<RedirectTargetRow> rows =
        await (_db.select(_db.redirectTargets)..where(
              (t) => tombstoneTerm(t.isDeleted, includeDeleted: false),
            ))
            .get();

    final Map<String, List<RedirectTarget>> graph =
        <String, List<RedirectTarget>>{};
    for (final RedirectTargetRow row in rows) {
      graph
          .putIfAbsent(row.sourceCategoryId, () => <RedirectTarget>[])
          .add(redirectTargetFromRow(row));
    }
    return graph.map(
      (String source, List<RedirectTarget> targets) =>
          MapEntry<String, List<RedirectTarget>>(source, targets.inOfferOrder),
    );
  }

  @override
  Future<Result<void, RepositoryFailure>> createRedirectTarget(
    RedirectTarget target,
  ) => writeTransaction(_db, () async {
    await _db
        .into(_db.redirectTargets)
        .insert(redirectTargetToCompanion(target));
  });

  @override
  Future<Result<void, RepositoryFailure>> updateRedirectTarget(
    RedirectTarget target,
  ) => writeTransaction(_db, () async {
    final int changed =
        await (_db.update(_db.redirectTargets)..where(
              (t) =>
                  t.id.equals(target.id) &
                  tombstoneTerm(t.isDeleted, includeDeleted: false),
            ))
            .write(redirectTargetToCompanion(target));
    if (changed == 0) {
      reject(RecordNotFound(entity: 'redirect target', id: target.id));
    }
  });

  @override
  Future<Result<void, RepositoryFailure>> deleteRedirectTarget(String id) =>
      writeTransaction(_db, () async {
        final RedirectTargetRow? row =
            await (_db.select(_db.redirectTargets)..where(
                  (t) =>
                      t.id.equals(id) &
                      tombstoneTerm(t.isDeleted, includeDeleted: false),
                ))
                .getSingleOrNull();
        if (row == null) {
          reject(RecordNotFound(entity: 'redirect target', id: id));
        }
        // Removing the last edge is legal: a category with no targets sends its
        // overflow to the sink, which is the documented terminal (INV-07), not
        // an error and not an inference (FR-16).
        await _tombstone(_db.redirectTargets, id);
      });

  // ===========================================================================
  // Shared
  // ===========================================================================

  /// Tombstones one row of a synced configuration table.
  ///
  /// Generic over the table so groups, categories and redirect targets cannot
  /// drift apart in *how* they are deleted. INV-10 has no exceptions among
  /// configuration records, so neither does this.
  ///
  /// `updated_by_device` is left untouched. Stamping the deleting device is
  /// meaningful, but the device identity lives in `sync_metadata` and is
  /// Stage 7's to establish (S07.4.4); inventing one here would put a second,
  /// wrong answer into the column that merge logic reads.
  Future<void> _tombstone<T extends Table, D>(
    TableInfo<T, D> table,
    String id,
  ) async {
    final int nowMs = _clock.nowMs();
    await _db.customUpdate(
      'UPDATE ${table.actualTableName} '
      'SET is_deleted = 1, deleted_at_ms = ?, updated_at_ms = ? '
      'WHERE id = ?',
      variables: <Variable<Object>>[
        Variable<int>(nowMs),
        Variable<int>(nowMs),
        Variable<String>(id),
      ],
      // Declaring the update is what makes every open `.watch()` on this table
      // re-emit. Without it a soft delete would be invisible to the dashboard
      // until something else happened to touch the table — the reactive-query
      // half of substage 4.4.4, and the reason this is `customUpdate` rather
      // than `customStatement`.
      updates: <TableInfo<Table, Object?>>{table},
    );
  }
}
