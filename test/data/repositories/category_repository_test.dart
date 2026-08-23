import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pookiebudget/data/database/database.dart';
import 'package:pookiebudget/data/repositories/drift_category_repository.dart';
import 'package:pookiebudget/domain/entities/category.dart';
import 'package:pookiebudget/domain/entities/category_group.dart';
import 'package:pookiebudget/domain/entities/enums.dart';
import 'package:pookiebudget/domain/entities/redirect_target.dart';
import 'package:pookiebudget/domain/repositories/category_repository.dart';
import 'package:pookiebudget/domain/repositories/repository_failure.dart';
import 'package:pookiebudget/domain/repositories/repository_queries.dart';
import 'package:pookiebudget/domain/result.dart';

import '../../support/builders/config_builders.dart';
import '../../support/fakes/fake_clock.dart';
import '../../support/test_database.dart';

/// Substage 4.4's acceptance criteria for groups, categories and redirect
/// targets.
void main() {
  late PookieDatabase db;
  late FakeClock clock;
  late CategoryRepository repo;

  setUp(() async {
    db = await openTestDatabase();
    clock = FakeClock();
    repo = DriftCategoryRepository(db, clock);
    // Every category needs a group; created once so each test starts from the
    // smallest state that is actually legal.
    await repo.createGroup(buildGroup());
  });

  tearDown(() async => db.close());

  /// Unwraps a write, failing the test with the repository's own message when
  /// it was rejected. Without this every write in the file needs three lines of
  /// ceremony, and the message that explains the failure gets swallowed.
  void expectOk(Result<void, RepositoryFailure> result) {
    expect(
      result.isSuccess,
      isTrue,
      reason: 'expected the write to succeed, got ${result.failureOrNull}',
    );
  }

  RepositoryFailure expectRejected(Result<void, RepositoryFailure> result) {
    expect(
      result.isSuccess,
      isFalse,
      reason: 'expected the write to be rejected, but it succeeded',
    );
    return result.failureOrNull!;
  }

  // ===========================================================================
  // 4.4.2 — CRUD
  // ===========================================================================

  group('4.4.2 CRUD', () {
    test('a created category reads back', () async {
      expectOk(await repo.createCategory(buildCategory()));

      final Category? found = await repo.categoryById('category-groceries');
      expect(found, isNotNull);
      expect(found!.name, 'Groceries');
    });

    test('an update replaces every field, including clearing one', () async {
      expectOk(
        await repo.createCategory(
          buildCategory(
            id: 'category-goal',
            name: 'EV Bike',
            type: CategoryType.accumulatingReserve,
            ceilingMinor: 500000,
            referenceMonthlyAmountMinor: 193000,
          ),
        ),
      );

      // Switching a savings goal to an open envelope must clear the ceiling.
      // This is the case a partial companion write gets wrong: the entity in
      // memory says there is no ceiling while the row still carries one.
      expectOk(
        await repo.updateCategory(
          buildCategory(
            id: 'category-goal',
            name: 'EV Bike',
            type: CategoryType.uncappedFlow,
          ),
        ),
      );

      final Category? found = await repo.categoryById('category-goal');
      expect(found!.type, CategoryType.uncappedFlow);
      expect(found.ceilingMinor, isNull);
      expect(
        found.referenceMonthlyAmountMinor,
        isNull,
        reason:
            'a stale reference amount would violate C-33 on the next write and '
            'misreport the goal in the meantime',
      );
    });

    test('updating a category that does not exist is rejected', () async {
      final RepositoryFailure failure = expectRejected(
        await repo.updateCategory(buildCategory(id: 'never-created')),
      );
      expect(failure, isA<RecordNotFound>());
    });

    test('U-01 — a duplicate live name in the same group is rejected',
        () async {
      expectOk(await repo.createCategory(buildCategory(id: 'a')));

      final RepositoryFailure failure = expectRejected(
        await repo.createCategory(buildCategory(id: 'b')),
      );
      expect(failure, isA<DuplicateName>());
      expect(failure.describe, contains('Groceries'));
    });

    test('U-01 is partial — archiving frees the name for reuse', () async {
      expectOk(await repo.createCategory(buildCategory(id: 'a')));
      expectOk(await repo.setCategoryArchived('a', archived: true));

      // A user who archived last year's goal must be able to create this
      // year's under the same name.
      expectOk(await repo.createCategory(buildCategory(id: 'b')));
      expect(await repo.categories(), hasLength(1));
    });

    test('the same name in a different group is not a duplicate', () async {
      expectOk(
        await repo.createGroup(
          buildGroup(
            id: 'group-savings',
            kind: CategoryGroupKind.savings,
            name: 'Savings',
            sortOrder: 1,
          ),
        ),
      );
      expectOk(await repo.createCategory(buildCategory(id: 'a')));
      expectOk(
        await repo.createCategory(
          buildCategory(id: 'b', groupId: 'group-savings'),
        ),
      );
      expect(await repo.categories(), hasLength(2));
    });
  });

  // ===========================================================================
  // 4.4.3 — soft delete
  // ===========================================================================

  group('4.4.3 deletion is soft, and reads filter tombstones', () {
    test('THE ROW SURVIVES, CARRYING A TOMBSTONE', () async {
      expectOk(await repo.createCategory(buildCategory()));
      clock.advance(const Duration(hours: 3));
      final int deletedAt = clock.peek();

      expectOk(await repo.deleteCategory('category-groceries'));

      // Read past the repository entirely. Through it, a hard delete and a
      // correctly filtered soft delete are indistinguishable.
      final QueryRow? row = await rawRow(
        db,
        'categories',
        'category-groceries',
      );
      expect(row, isNotNull, reason: 'INV-10: the row must not be removed');
      expect(row!.read<int>('is_deleted'), 1);
      expect(row.read<int>('deleted_at_ms'), deletedAt);
      expect(await rawCount(db, 'categories'), 1);
    });

    test('a tombstoned category is absent from every default read', () async {
      expectOk(await repo.createCategory(buildCategory()));
      expectOk(await repo.deleteCategory('category-groceries'));

      expect(await repo.categories(), isEmpty);
      expect(await repo.categoryById('category-groceries'), isNull);
      expect(
        await repo.categories(
          query: const CategoryQuery(groupId: 'group-spending'),
        ),
        isEmpty,
      );
      expect(
        await repo.categories(
          query: const CategoryQuery(archived: ArchivedFilter.any),
        ),
        isEmpty,
        reason:
            'asking for archived rows must not also opt in to deleted ones — '
            'they are different states',
      );
    });

    test('sync opts in explicitly and sees the tombstone', () async {
      expectOk(await repo.createCategory(buildCategory()));
      expectOk(await repo.deleteCategory('category-groceries'));

      final List<Category> all = await repo.categories(
        query: const CategoryQuery(
          includeDeleted: true,
          archived: ArchivedFilter.any,
        ),
      );
      expect(all, hasLength(1));
      expect(all.single.sync.isDeleted, isTrue);
      expect(all.single.sync.deletedAtMs, isNotNull);
    });

    test('INV-07 — the sink cannot be deleted or archived', () async {
      expectOk(await repo.createCategory(buildSink()));

      expect(
        expectRejected(await repo.deleteCategory('category-sink')),
        isA<SinkProtected>(),
      );
      expect(
        expectRejected(
          await repo.setCategoryArchived('category-sink', archived: true),
        ),
        isA<SinkProtected>(),
      );
      expect(await repo.sinkForGroup('group-spending'), isNotNull);
    });

    test('a category others redirect into cannot be deleted', () async {
      expectOk(await repo.createCategory(buildSink()));
      expectOk(
        await repo.createCategory(
          buildCategory(
            id: 'category-goal',
            name: 'EV Bike',
            type: CategoryType.accumulatingReserve,
            ceilingMinor: 500000,
          ),
        ),
      );
      expectOk(await repo.createRedirectTarget(buildRedirectTarget()));

      final RepositoryFailure failure = expectRejected(
        await repo.deleteCategory('category-sink'),
      );
      // The sink check fires first here, which is the stronger rule.
      expect(failure, isA<SinkProtected>());

      // A non-sink target proves the reference check itself.
      expectOk(
        await repo.createCategory(
          buildCategory(id: 'category-hajj', name: 'Hajj'),
        ),
      );
      expectOk(
        await repo.createRedirectTarget(
          // Priority 1, not 0: U-12 allows one row per source at each priority,
          // and `redirect-1` above already holds priority 0 for this source.
          buildRedirectTarget(
            id: 'redirect-2',
            targetCategoryId: 'category-hajj',
            priority: 1,
          ),
        ),
      );
      expect(
        expectRejected(await repo.deleteCategory('category-hajj')),
        isA<RecordStillReferenced>(),
      );
    });

    test('a group with live categories cannot be deleted', () async {
      expectOk(await repo.createCategory(buildCategory()));
      expect(
        expectRejected(await repo.deleteGroup('group-spending')),
        isA<RecordStillReferenced>(),
      );

      expectOk(await repo.deleteCategory('category-groceries'));
      expectOk(await repo.deleteGroup('group-spending'));
      expect(await repo.groups(), isEmpty);
      expect(await rawCount(db, 'category_groups'), 1);
    });
  });

  // ===========================================================================
  // 4.4.4 — reactive queries
  // ===========================================================================

  group('4.4.4 streams emit on changes made through another code path', () {
    /// Subscribes, waits for the initial emission, then returns a recorder.
    ///
    /// The obvious spelling — `stream.take(2).toList()` — races: if the write
    /// lands before the query behind the initial emission has run, the stream
    /// yields one combined emission and the test hangs waiting for a second
    /// that never comes. Draining the event queue between subscribing and
    /// writing removes the race rather than making it rarer.
    Future<_Recorder<T>> record<T>(Stream<T> stream) async {
      final _Recorder<T> recorder = _Recorder<T>(stream);
      await pumpEventQueue();
      expect(
        recorder.emissions,
        hasLength(1),
        reason: 'a reactive query emits its current value on subscription',
      );
      return recorder;
    }

    test('A SECOND REPOSITORY INSTANCE TRIGGERS AN EMISSION', () async {
      // The acceptance criterion verbatim: "mutates through a second path and
      // asserts the stream emits." A stream that only saw its own repository's
      // writes would go stale the moment Stage 7's background sync worker
      // wrote a row.
      final CategoryRepository other = DriftCategoryRepository(db, clock);
      final _Recorder<List<Category>> recorder = await record(
        repo.watchCategories(),
      );
      expect(recorder.latest, isEmpty);

      await other.createCategory(buildCategory());
      await pumpEventQueue();

      expect(recorder.emissions, hasLength(2));
      expect(recorder.latest.single.name, 'Groceries');
      await recorder.cancel();
    });

    test('a raw SQL write through the database triggers an emission', () async {
      expectOk(await repo.createCategory(buildCategory()));
      final _Recorder<List<Category>> recorder = await record(
        repo.watchCategories(),
      );
      expect(recorder.latest.single.name, 'Groceries');

      // Closer still to what a sync writer does: no repository involved at all.
      await db.customUpdate(
        "UPDATE categories SET name = 'Food' WHERE id = ?",
        variables: <Variable<Object>>[Variable<String>('category-groceries')],
        updates: <TableInfo<Table, Object?>>{db.categories},
      );
      await pumpEventQueue();

      expect(recorder.emissions, hasLength(2));
      expect(recorder.latest.single.name, 'Food');
      await recorder.cancel();
    });

    test('a soft delete re-emits, so the dashboard drops the row', () async {
      expectOk(await repo.createCategory(buildCategory()));
      final _Recorder<List<Category>> recorder = await record(
        repo.watchCategories(),
      );
      expect(recorder.latest, hasLength(1));

      await repo.deleteCategory('category-groceries');
      await pumpEventQueue();

      expect(recorder.latest, isEmpty);
      await recorder.cancel();
    });

    test('group and redirect streams emit too', () async {
      final _Recorder<List<CategoryGroup>> groups = await record(
        repo.watchGroups(),
      );
      await repo.createGroup(
        buildGroup(
          id: 'group-savings',
          kind: CategoryGroupKind.savings,
          name: 'Savings',
          sortOrder: 1,
        ),
      );
      await pumpEventQueue();
      expect(groups.latest, hasLength(2));
      await groups.cancel();

      expectOk(await repo.createCategory(buildSink()));
      expectOk(
        await repo.createCategory(
          buildCategory(id: 'category-goal', name: 'EV Bike'),
        ),
      );

      final _Recorder<List<RedirectTarget>> redirects = await record(
        repo.watchRedirectTargetsFor('category-goal'),
      );
      expect(redirects.latest, isEmpty);

      await repo.createRedirectTarget(buildRedirectTarget());
      await pumpEventQueue();
      expect(redirects.latest, hasLength(1));
      await redirects.cancel();
    });
  });

  // ===========================================================================
  // 4.4.5 — list filters
  // ===========================================================================

  group('4.4.5 filters', () {
    setUp(() async {
      expectOk(
        await repo.createGroup(
          buildGroup(
            id: 'group-savings',
            kind: CategoryGroupKind.savings,
            name: 'Savings',
            sortOrder: 1,
          ),
        ),
      );
      expectOk(
        await repo.createCategory(
          buildCategory(id: 'c-1', name: 'Groceries', sortOrder: 2),
        ),
      );
      expectOk(
        await repo.createCategory(
          buildCategory(id: 'c-2', name: 'Transport', sortOrder: 1),
        ),
      );
      expectOk(
        await repo.createCategory(
          buildCategory(
            id: 'c-3',
            name: 'Hajj',
            groupId: 'group-savings',
            sortOrder: 3,
          ),
        ),
      );
      expectOk(
        await repo.createCategory(
          buildCategory(id: 'c-4', name: 'Old goal', isArchived: true),
        ),
      );
    });

    test('by group', () async {
      final List<Category> savings = await repo.categories(
        query: const CategoryQuery(groupId: 'group-savings'),
      );
      expect(savings.map((Category c) => c.id), <String>['c-3']);
    });

    test('by archived state', () async {
      expect(
        (await repo.categories()).map((Category c) => c.id),
        <String>['c-2', 'c-1', 'c-3'],
        reason: 'live only, ordered by sort_order then id',
      );
      expect(
        (await repo.categories(
          query: const CategoryQuery(archived: ArchivedFilter.archivedOnly),
        )).map((Category c) => c.id),
        <String>['c-4'],
      );
      expect(
        await repo.categories(
          query: const CategoryQuery(archived: ArchivedFilter.any),
        ),
        hasLength(4),
      );
    });

    test('by linked account', () async {
      // The account row must exist: the FK is enforced, not decorative.
      await db.customStatement(
        'INSERT INTO accounts (id, name, sort_order, updated_at_ms, '
        "updated_by_device, hlc) VALUES ('acc-1', 'Current', 0, 0, 'd', 'h')",
      );
      expectOk(
        await repo.updateCategory(
          buildCategory(
            id: 'c-1',
            name: 'Groceries',
            sortOrder: 2,
            linkedAccountId: 'acc-1',
          ),
        ),
      );

      final List<Category> linked = await repo.categories(
        query: const CategoryQuery(linkedAccountId: 'acc-1'),
      );
      expect(linked.map((Category c) => c.id), <String>['c-1']);
    });

    test('ordering is total, so it survives equal sort orders', () async {
      // U-01 does not stop two categories sharing a sort_order, and a merge
      // produces it routinely. `id` breaks the tie, which is what keeps the
      // engine deterministic (INV-08).
      expectOk(
        await repo.createCategory(
          buildCategory(id: 'c-0', name: 'Zakat', sortOrder: 1),
        ),
      );
      final List<Category> ordered = await repo.categories();
      expect(ordered.map((Category c) => c.id), <String>[
        'c-0',
        'c-2',
        'c-1',
        'c-3',
      ]);
    });
  });

  // ===========================================================================
  // Redirect targets — ADR-006
  // ===========================================================================

  group('redirect targets', () {
    setUp(() async {
      expectOk(await repo.createCategory(buildSink()));
      expectOk(
        await repo.createCategory(
          buildCategory(id: 'category-goal', name: 'EV Bike'),
        ),
      );
      expectOk(
        await repo.createCategory(
          buildCategory(id: 'category-hajj', name: 'Hajj'),
        ),
      );
    });

    test('are returned in offer order, not insertion order', () async {
      expectOk(
        await repo.createRedirectTarget(
          buildRedirectTarget(
            id: 'r-late',
            targetCategoryId: 'category-sink',
            priority: 5,
          ),
        ),
      );
      expectOk(
        await repo.createRedirectTarget(
          buildRedirectTarget(
            id: 'r-first',
            targetCategoryId: 'category-hajj',
            priority: 1,
          ),
        ),
      );

      final List<RedirectTarget> targets = await repo.redirectTargetsFor(
        'category-goal',
      );
      expect(targets.map((RedirectTarget t) => t.id), <String>[
        'r-first',
        'r-late',
      ]);
    });

    test('the graph loads whole, each list in offer order', () async {
      expectOk(await repo.createRedirectTarget(buildRedirectTarget()));
      expectOk(
        await repo.createRedirectTarget(
          buildRedirectTarget(
            id: 'r-2',
            sourceCategoryId: 'category-hajj',
            targetCategoryId: 'category-sink',
          ),
        ),
      );

      final Map<String, List<RedirectTarget>> graph = await repo
          .redirectGraph();
      expect(graph.keys.toSet(), <String>{'category-goal', 'category-hajj'});
      expect(graph['category-goal'], hasLength(1));
    });

    test('deleting the last edge is legal — overflow falls to the sink',
        () async {
      expectOk(await repo.createRedirectTarget(buildRedirectTarget()));
      expectOk(await repo.deleteRedirectTarget('redirect-1'));

      expect(await repo.redirectTargetsFor('category-goal'), isEmpty);
      final QueryRow? row = await rawRow(db, 'redirect_targets', 'redirect-1');
      expect(row!.read<int>('is_deleted'), 1);
    });

    test('a tombstoned edge is out of the graph the engine walks', () async {
      expectOk(await repo.createRedirectTarget(buildRedirectTarget()));
      expectOk(await repo.deleteRedirectTarget('redirect-1'));
      expect(await repo.redirectGraph(), isEmpty);
    });
  });
}

/// Collects a stream's emissions as they arrive.
///
/// Deliberately not `stream.take(n).toList()`. That form couples the assertion
/// to an exact emission count decided before the test runs, so an extra
/// emission hangs the test instead of failing it — and a hanging test reports
/// as a timeout with no indication of what actually happened.
class _Recorder<T> {
  _Recorder(Stream<T> stream) {
    _subscription = stream.listen(emissions.add);
  }

  final List<T> emissions = <T>[];
  late final StreamSubscription<T> _subscription;

  T get latest => emissions.last;

  Future<void> cancel() => _subscription.cancel();
}
