/// Substage 4.6.6 — *"Measure derivation cost against a synthetic ledger at the
/// five-year volume from the PRD, and record the timing."*
///
/// Budget **P-13: balance recompute-and-compare, all categories ≤ 2 s.**
///
/// ## What this measures, and what it does not
///
/// It measures the query cost on **this** machine's SQLite, not on the mid-tier
/// Android phone NFR-06 names. That device measurement belongs to substage
/// 9.6, which benchmarks on real hardware. What this catches is the failure
/// worth catching now: a derivation that is accidentally quadratic, or one that
/// misses IX-01 and table-scans. Those show up as seconds even on a fast
/// desktop, and they are cheap to fix here and expensive to find at Stage 9.
///
/// So the assertion is deliberately loose. A tight desktop threshold would
/// either fail on a slow CI runner or pass on a machine fast enough to hide a
/// real regression, and neither tells the truth about a phone.
///
/// Not tagged, and therefore not skippable. It is the slowest test in the
/// suite by a wide margin, and tagging it out of the default run is exactly how
/// a performance regression goes unnoticed until Stage 9 — where the budget is
/// measured on hardware and a fix is far more expensive.
library;

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pookiebudget/data/balances/balance_queries.dart';
import 'package:pookiebudget/data/database/database.dart';
import 'package:pookiebudget/domain/repositories/balance_repository.dart';

import '../../support/movement_fixture.dart';
import '../../support/test_database.dart';

void main() {
  /// PRD §7.2, Heavy profile — roughly five years of realistic use. SCHEMA §7.1
  /// estimates 40–80 ms for a full recompute at this volume and asks 4.6.6 to
  /// replace the estimate with a measurement.
  const int heavyProfileEntries = 67000;
  const int categoryCount = 100;

  late PookieDatabase db;
  late BalanceQueries balances;

  setUp(() async {
    db = await openTestDatabase();
    await seedMovementFixture(db);
    balances = BalanceQueries(db);
  });

  tearDown(() async => db.close());

  /// Fills the ledger with [entryCount] entries spread across [categoryCount]
  /// categories.
  ///
  /// Inserted with a Drift batch and **not** through `appendLedgerEntries`. The
  /// point here is the read cost at volume; routing 67,000 rows through the
  /// write path would measure the writer instead and take minutes doing it. The
  /// cache is built afterwards by `recomputeAll`, which is the operation under
  /// test anyway.
  Future<void> fillLedger(int entryCount) async {
    final List<String> categoryIds = <String>[
      for (int i = 0; i < categoryCount; i++) 'bench-cat-$i',
    ];

    await db.batch((Batch batch) {
      batch.insertAll(db.categories, <Insertable<CategoryRow>>[
        for (int i = 0; i < categoryCount; i++)
          CategoriesCompanion.insert(
            id: categoryIds[i],
            groupId: 'group-spending',
            name: 'Bench $i',
            type: 'UNCAPPED_FLOW',
            sortOrder: i,
            updatedAtMs: 0,
            updatedByDevice: 'bench',
            hlc: 'bench',
          ),
      ]);
    });

    // Batched in chunks rather than one 67,000-row batch: a single statement
    // list that large is where SQLite's variable limit bites, and the failure
    // is opaque when it does.
    const int chunk = 2000;
    for (int start = 0; start < entryCount; start += chunk) {
      final int end = start + chunk > entryCount ? entryCount : start + chunk;
      await db.batch((Batch batch) {
        batch.insertAll(db.ledgerEntries, <Insertable<LedgerEntryRow>>[
          for (int i = start; i < end; i++)
            LedgerEntriesCompanion.insert(
              id: 'bench-entry-$i',
              categoryId: categoryIds[i % categoryCount],
              direction: i % 5 == 0 ? 'OUT' : 'IN',
              amountMinor: 100 + (i % 997),
              occurredAtMs: i * 60000,
              recordedAtMs: i * 60000,
              sourceType: i % 5 == 0 ? 'SPENDING' : 'ALLOCATION',
              sourceId: 'bench-source-${i ~/ 10}',
              updatedAtMs: 0,
              updatedByDevice: 'bench',
              hlc: 'bench',
            ),
        ]);
      });
    }
  }

  test('P-13 — full recompute-and-compare at the Heavy profile', () async {
    await fillLedger(heavyProfileEntries);

    final Stopwatch recompute = Stopwatch()..start();
    await balances.recomputeAll();
    recompute.stop();

    final Stopwatch verify = Stopwatch()..start();
    final List<BalanceDiscrepancy> found = await balances.verify();
    verify.stop();

    // Printed so the figure can be pasted into the worklog. A benchmark whose
    // number is never written down is a benchmark nobody can compare against
    // next time.
    // ignore: avoid_print
    print(
      'P-13 @ Heavy ($heavyProfileEntries entries, $categoryCount categories): '
      'recomputeAll ${recompute.elapsedMilliseconds} ms, '
      'verify ${verify.elapsedMilliseconds} ms, '
      'total ${recompute.elapsedMilliseconds + verify.elapsedMilliseconds} ms',
    );

    expect(
      found,
      isEmpty,
      reason: 'a recompute must leave the cache agreeing with the ledger',
    );
    expect(
      recompute.elapsedMilliseconds + verify.elapsedMilliseconds,
      lessThan(2000),
      reason:
          'P-13 budget is 2 s. Exceeding it on a desktop means the derivation '
          'is missing IX-01 or is quadratic in categories — either way it will '
          'be far worse on the mid-tier phone NFR-06 names.',
    );
  });

  test('the derived query plan uses IX-01, not a table scan', () async {
    // Substage 4.6.1: "Verify the query uses the index designed in substage 2.4
    // by inspecting the query plan." Asserted rather than assumed — an index
    // that exists and is not chosen is an index that costs writes and buys
    // nothing.
    await fillLedger(5000);

    final List<QueryRow> plan = await db
        .customSelect(
          'EXPLAIN QUERY PLAN '
          'SELECT COALESCE(SUM(amount_minor), 0) FROM ledger_entries '
          "WHERE category_id = 'bench-cat-1'",
        )
        .get();
    final String detail = plan
        .map((QueryRow r) => r.data['detail']?.toString() ?? '')
        .join(' | ');

    // ignore: avoid_print
    print('EXPLAIN QUERY PLAN (single category): $detail');
    expect(
      detail.toLowerCase(),
      contains('ix_01_ledger_category_time'),
      reason:
          'the single-category balance query must use IX-01 '
          '(category_id, occurred_at_ms). Got: $detail',
    );
  });
}
