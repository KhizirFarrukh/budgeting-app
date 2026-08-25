import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pookiebudget/data/balances/balance_queries.dart';
import 'package:pookiebudget/data/balances/balance_verifier.dart';
import 'package:pookiebudget/data/database/database.dart';
import 'package:pookiebudget/data/repositories/drift_category_repository.dart';
import 'package:pookiebudget/data/repositories/drift_ledger_repository.dart';
import 'package:pookiebudget/domain/allocation/period.dart';
import 'package:pookiebudget/domain/entities/enums.dart';
import 'package:pookiebudget/domain/entities/ledger_entry.dart';
import 'package:pookiebudget/domain/repositories/balance_repository.dart';
import 'package:pookiebudget/domain/repositories/ledger_repository.dart';
import 'package:pookiebudget/domain/repositories/repository_failure.dart';
import 'package:pookiebudget/domain/result.dart';

import '../../support/builders/config_builders.dart';
import '../../support/builders/movement_builders.dart';
import '../../support/fakes/fake_clock.dart';
import '../../support/movement_fixture.dart';
import '../../support/test_database.dart';

/// Substage 4.6 — INV-04.
void main() {
  late PookieDatabase db;
  late LedgerRepository ledger;
  late BalanceQueries balances;

  setUp(() async {
    db = await openTestDatabase();
    await seedMovementFixture(db);
    ledger = DriftLedgerRepository(db);
    balances = BalanceQueries(db);
  });

  tearDown(() async => db.close());

  Future<void> append(List<LedgerEntry> entries) async {
    final Result<void, RepositoryFailure> result = await ledger.append(entries);
    expect(
      result.isSuccess,
      isTrue,
      reason: 'append failed: ${result.failureOrNull}',
    );
  }

  // ===========================================================================
  // 4.6.1 — derivation
  // ===========================================================================

  group('4.6.1 every balance is derivable from the ledger alone', () {
    test('IN adds and OUT subtracts', () async {
      await append(<LedgerEntry>[
        buildLedgerEntry(id: 'a', amountMinor: 30000),
        buildLedgerEntry(
          id: 'b',
          direction: LedgerDirection.outbound,
          amountMinor: 12000,
          sourceType: LedgerSourceType.spending,
          sourceId: 'spend-1',
          reason: null,
          hopCount: null,
        ),
      ]);

      expect(await balances.derivedBalanceOf('category-groceries'), 18000);
    });

    test('a balance may legitimately be negative', () async {
      // A category can be overspent. Nothing here may treat that as an error,
      // and no clamp to zero may appear anywhere on the path — a hidden clamp
      // would make the overspend invisible while the money stayed gone.
      await append(<LedgerEntry>[
        buildLedgerEntry(
          id: 'over',
          direction: LedgerDirection.outbound,
          amountMinor: 5000,
          sourceType: LedgerSourceType.spending,
          sourceId: 'spend-1',
          reason: null,
          hopCount: null,
        ),
      ]);
      expect(await balances.derivedBalanceOf('category-groceries'), -5000);
    });

    test('A CATEGORY WITH NO ENTRIES IS PRESENT AT ZERO, NOT ABSENT', () async {
      // A dashboard that dropped it would silently hide a bucket the user
      // created and has not funded yet, which reads as the app forgetting it.
      final Map<String, int> all = await balances.derivedBalances();
      expect(all.keys, containsAll(<String>[
        'category-groceries',
        'category-transport',
        'category-sink',
      ]));
      expect(all['category-transport'], 0);
    });

    test('a tombstoned category drops out of the derived map', () async {
      final DriftCategoryRepository categories = DriftCategoryRepository(
        db,
        FakeClock(),
      );
      await categories.deleteCategory('category-transport');
      expect(
        (await balances.derivedBalances()).keys,
        isNot(contains('category-transport')),
      );
    });
  });

  // ===========================================================================
  // 4.6.2 — period-scoped derivation
  // ===========================================================================

  group('4.6.2 allocated-in-period', () {
    test('counts only what falls inside the period', () async {
      final PeriodDefinition february = periodContaining(
        atMs: DateTime.utc(2026, 3, 1).millisecondsSinceEpoch,
        anchorDay: 31,
      );

      await append(<LedgerEntry>[
        buildLedgerEntry(
          id: 'inside',
          amountMinor: 4000,
          occurredAtMs: DateTime.utc(2026, 3, 5).millisecondsSinceEpoch,
        ),
        buildLedgerEntry(
          id: 'before',
          amountMinor: 9000,
          occurredAtMs: DateTime.utc(2026, 2, 20).millisecondsSinceEpoch,
        ),
        buildLedgerEntry(
          id: 'after',
          amountMinor: 7000,
          occurredAtMs: DateTime.utc(2026, 4, 2).millisecondsSinceEpoch,
        ),
      ]);

      expect(
        await balances.allocatedInPeriod('category-groceries', february),
        4000,
      );
    });

    test('the period arrives as an argument — no clock is read', () async {
      // Substage 4.6's second `must_not`. The proof is structural: the same
      // ledger yields different answers for different periods, and nothing in
      // BalanceQueries can pick one.
      await append(<LedgerEntry>[
        buildLedgerEntry(
          id: 'jan',
          amountMinor: 1000,
          occurredAtMs: DateTime.utc(2026, 1, 5).millisecondsSinceEpoch,
        ),
      ]);

      const int anchor = 1;
      final PeriodDefinition january = periodContaining(
        atMs: DateTime.utc(2026, 1, 10).millisecondsSinceEpoch,
        anchorDay: anchor,
      );
      final PeriodDefinition february = periodContaining(
        atMs: DateTime.utc(2026, 2, 10).millisecondsSinceEpoch,
        anchorDay: anchor,
      );

      expect(
        await balances.allocatedInPeriod('category-groceries', january),
        1000,
      );
      expect(
        await balances.allocatedInPeriod('category-groceries', february),
        0,
      );
    });
  });

  // ===========================================================================
  // 4.6.3 — the cache is maintained on every ledger write
  // ===========================================================================

  group('4.6.3 the cache is updated in the same transaction', () {
    test('appending an entry folds it into the cache', () async {
      await append(<LedgerEntry>[buildLedgerEntry(id: 'a', amountMinor: 7500)]);

      expect(
        (await balances.cachedBalances())['category-groceries'],
        7500,
      );
      final QueryRow cache = await db
          .customSelect(
            "SELECT * FROM balance_cache WHERE category_id = 'category-groceries'",
          )
          .getSingle();
      expect(cache.read<int>('entry_count'), 1);
      expect(cache.read<String>('last_entry_id'), 'a');
      expect(cache.read<int>('is_stale'), 0);
    });

    test('A REJECTED WRITE LEAVES THE CACHE UNTOUCHED', () async {
      await append(<LedgerEntry>[buildLedgerEntry(id: 'a', amountMinor: 1000)]);

      // One valid entry, one that trips the foreign key. If the cache were
      // adjusted outside the transaction, the valid one would inflate the
      // balance for an entry that was rolled back.
      await ledger.append(<LedgerEntry>[
        buildLedgerEntry(id: 'good', amountMinor: 500),
        buildLedgerEntry(
          id: 'bad',
          categoryId: 'no-such-category',
          amountMinor: 500,
        ),
      ]);

      expect((await balances.cachedBalances())['category-groceries'], 1000);
      expect(await balances.derivedBalanceOf('category-groceries'), 1000);
      expect(await balances.verify(), isEmpty);
    });

    test('A REPLAYED ENTRY DOES NOT INFLATE THE CACHE', () async {
      // The defect this guards: `insertOrIgnore` silently skips a duplicate, so
      // incrementing the balance regardless would make a retried sync push
      // inflate every category it touched — a corruption caused by the very
      // mechanism that exists to make retries safe.
      final LedgerEntry entry = buildLedgerEntry(id: 'a', amountMinor: 1000);
      await append(<LedgerEntry>[entry]);
      await append(<LedgerEntry>[entry]);
      await append(<LedgerEntry>[entry]);

      expect((await balances.cachedBalances())['category-groceries'], 1000);
      expect(await balances.verify(), isEmpty);
    });

    test('the cache tracks the ledger across many mixed writes', () async {
      await append(<LedgerEntry>[
        buildLedgerEntry(id: 'i1', amountMinor: 10000),
        buildLedgerEntry(id: 'i2', amountMinor: 2500),
        buildLedgerEntry(
          id: 'o1',
          direction: LedgerDirection.outbound,
          amountMinor: 3000,
          sourceType: LedgerSourceType.spending,
          sourceId: 'spend-1',
          reason: null,
          hopCount: null,
        ),
        buildLedgerEntry(
          id: 't1',
          categoryId: 'category-transport',
          amountMinor: 800,
        ),
      ]);

      final Map<String, int> cached = await balances.cachedBalances();
      final Map<String, int> derived = await balances.derivedBalances();
      expect(cached['category-groceries'], 9500);
      expect(cached['category-transport'], 800);
      expect(cached['category-groceries'], derived['category-groceries']);
      expect(await balances.verify(), isEmpty);
    });
  });

  // ===========================================================================
  // 4.6.4 — the verifier
  // ===========================================================================

  group('4.6.4 recompute-and-compare', () {
    setUp(() async {
      await append(<LedgerEntry>[
        buildLedgerEntry(id: 'a', amountMinor: 10000),
        buildLedgerEntry(
          id: 'b',
          categoryId: 'category-transport',
          amountMinor: 4000,
        ),
      ]);
    });

    test('a healthy cache reports nothing', () async {
      expect(await balances.verify(), isEmpty);
      expect(await balances.verify(full: false), isEmpty);
    });

    test('THE VERIFIER FINDS A DELIBERATELY CORRUPTED BALANCE', () async {
      // The acceptance criterion, verbatim. Corrupted by raw SQL because there
      // is no API that could do it — which is itself the point of `must_not`
      // "do not expose a setter for a balance".
      await db.customStatement(
        'UPDATE balance_cache SET balance_minor = 999999 '
        "WHERE category_id = 'category-groceries'",
      );

      final List<BalanceDiscrepancy> found = await balances.verify();
      expect(found, hasLength(1));
      expect(found.single.categoryId, 'category-groceries');
      expect(found.single.kind, DiscrepancyKind.balanceMismatch);
      expect(found.single.derivedMinor, 10000);
      expect(found.single.cachedMinor, 999999);
      expect(found.single.driftMinor, 10000 - 999999);
    });

    test('the verifier RETURNS rather than throwing', () async {
      await db.customStatement(
        'UPDATE balance_cache SET balance_minor = 1 '
        "WHERE category_id = 'category-groceries'",
      );
      // A diagnostic that crashes on finding the thing it went looking for
      // cannot be run from a settings screen, before an export, or after a
      // merge — the three places SCHEMA §7.1 requires it.
      await expectLater(balances.verify(), completes);
    });

    test('TWO CANCELLING ERRORS ARE CAUGHT BY entry_count', () async {
      // The case ADR-007 exists for. The total still matches, so a balance
      // comparison alone reports this as healthy; only the composition is
      // wrong, and a merge that imported one entry while dropping another of
      // equal magnitude produces exactly it.
      await db.customStatement(
        'UPDATE balance_cache SET entry_count = 5 '
        "WHERE category_id = 'category-groceries'",
      );

      final List<BalanceDiscrepancy> found = await balances.verify();
      expect(found, hasLength(1));
      expect(found.single.kind, DiscrepancyKind.entryCountMismatch);
      expect(found.single.derivedMinor, found.single.cachedMinor);
      expect(found.single.derivedEntryCount, 1);
      expect(found.single.cachedEntryCount, 5);
    });

    test('the cheap tier catches an entry written behind the cache', () async {
      // The realistic failure §7.1 names: entries present without the cache
      // being updated. Written by raw SQL, bypassing appendLedgerEntries.
      await db.customStatement(
        'INSERT INTO ledger_entries (id, category_id, direction, amount_minor, '
        'occurred_at_ms, recorded_at_ms, source_type, source_id, '
        'updated_at_ms, updated_by_device, hlc) VALUES '
        "('smuggled', 'category-groceries', 'IN', 500, 0, 0, 'ALLOCATION', "
        "'income-x', 0, 'd', 'h')",
      );

      final List<BalanceDiscrepancy> cheap = await balances.verify(full: false);
      expect(cheap, hasLength(1));
      expect(cheap.single.kind, DiscrepancyKind.entryCountMismatch);
    });

    test('a missing cache row is reported only when entries exist', () async {
      await db.customStatement(
        "DELETE FROM balance_cache WHERE category_id = 'category-groceries'",
      );
      final List<BalanceDiscrepancy> found = await balances.verify();
      expect(found, hasLength(1));
      expect(found.single.kind, DiscrepancyKind.missingCacheRow);
      expect(found.single.cachedMinor, isNull);

      // `category-sink` has no entries and no cache row, and must not be
      // reported — otherwise every clean install fails its first verification.
      expect(
        found.map((BalanceDiscrepancy d) => d.categoryId),
        isNot(contains('category-sink')),
      );
    });

    test('an orphan cache row is reported', () async {
      // The transport category already has a cache row from this group's
      // setUp, so tombstoning the category is all it takes to orphan it. That
      // means something removed a category without clearing its cache:
      // harmless to any displayed balance, but the row would come back to life
      // if the id were ever reused.
      await db.customStatement(
        'UPDATE categories SET is_deleted = 1, deleted_at_ms = 1 '
        "WHERE id = 'category-transport'",
      );

      final List<BalanceDiscrepancy> found = await balances.verify();
      expect(
        found.where(
          (BalanceDiscrepancy d) => d.categoryId == 'category-transport',
        ),
        hasLength(1),
      );
      expect(
        found
            .firstWhere(
              (BalanceDiscrepancy d) => d.categoryId == 'category-transport',
            )
            .kind,
        DiscrepancyKind.orphanCacheRow,
      );
    });

    test('a stale row is reported as stale, not as a mismatch', () async {
      // A merge sets this deliberately. Reporting a *mismatch* on a row already
      // known to need recomputation would bury the real signal under noise.
      await BalanceVerifier(db).markStale(<String>['category-groceries']);
      final List<BalanceDiscrepancy> found = await balances.verify();
      expect(found, hasLength(1));
      expect(found.single.kind, DiscrepancyKind.staleFlagSet);
    });

    test('recomputeAll repairs every kind of damage', () async {
      await db.customStatement(
        'UPDATE balance_cache SET balance_minor = 42, entry_count = 99, '
        'is_stale = 1',
      );
      await db.customStatement(
        'INSERT INTO balance_cache (category_id, balance_minor, entry_count, '
        "computed_at_ms) VALUES ('category-sink', 12345, 7, 0)",
      );

      expect(await balances.verify(), isNotEmpty);
      await balances.recomputeAll();
      expect(await balances.verify(), isEmpty);

      expect((await balances.cachedBalances())['category-groceries'], 10000);
      expect((await balances.cachedBalances())['category-transport'], 4000);
      expect((await balances.cachedBalances())['category-sink'], 0);
    });

    test('recomputeAll takes no number from its caller', () async {
      // Not a setter in disguise. Its only input is `ledger_entries`, so
      // running it twice gives the same answer — which is INV-04's actual
      // requirement: a stored balance anyone can re-derive.
      await balances.recomputeAll();
      final Map<String, int> first = await balances.cachedBalances();
      await balances.recomputeAll();
      expect(await balances.cachedBalances(), first);
    });
  });

  // ===========================================================================
  // 4.6.5 — per-account totals
  // ===========================================================================

  group('4.6.5 account totals reconcile with linked categories', () {
    setUp(() async {
      final DriftCategoryRepository categories = DriftCategoryRepository(
        db,
        FakeClock(),
      );
      await db.customStatement(
        'INSERT INTO accounts (id, name, sort_order, updated_at_ms, '
        "updated_by_device, hlc) VALUES ('acc-1', 'Current', 0, 0, 'd', 'h')",
      );
      await db.customStatement(
        'INSERT INTO accounts (id, name, sort_order, updated_at_ms, '
        "updated_by_device, hlc) VALUES ('acc-2', 'Savings', 1, 0, 'd', 'h')",
      );
      await categories.updateCategory(
        buildCategory(linkedAccountId: 'acc-1'),
      );
      await categories.updateCategory(
        buildCategory(
          id: 'category-transport',
          name: 'Transport',
          sortOrder: 1,
          linkedAccountId: 'acc-1',
        ),
      );
    });

    test('the total equals the sum of its linked categories', () async {
      await append(<LedgerEntry>[
        buildLedgerEntry(id: 'a', amountMinor: 10000),
        buildLedgerEntry(
          id: 'b',
          categoryId: 'category-transport',
          amountMinor: 4000,
        ),
        buildLedgerEntry(
          id: 'c',
          categoryId: 'category-sink',
          amountMinor: 999,
        ),
      ]);

      final int total = await balances.accountTotal('acc-1');
      final Map<String, int> derived = await balances.derivedBalances();
      expect(
        total,
        derived['category-groceries']! + derived['category-transport']!,
      );
      expect(total, 14000);
      expect(
        await balances.accountTotal('acc-2'),
        0,
        reason: 'an account with no linked categories holds nothing',
      );
    });

    test('re-linking moves the total, and history keeps its own record',
        () async {
      await append(<LedgerEntry>[
        buildLedgerEntry(id: 'a', amountMinor: 10000, accountId: 'acc-1'),
      ]);
      expect(await balances.accountTotal('acc-1'), 10000);

      final DriftCategoryRepository categories = DriftCategoryRepository(
        db,
        FakeClock(),
      );
      await categories.updateCategory(
        buildCategory(linkedAccountId: 'acc-2'),
      );

      // The total follows the category, because an account's total is what it
      // holds *now*. The entry's own `account_id` still says acc-1, because
      // history must not be rewritten by a later re-link — the two columns
      // differ on purpose.
      expect(await balances.accountTotal('acc-2'), 10000);
      expect(await balances.accountTotal('acc-1'), 0);
      expect((await ledger.entryById('a'))!.accountId, 'acc-1');
    });
  });
}
