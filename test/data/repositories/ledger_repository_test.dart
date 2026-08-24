import 'package:flutter_test/flutter_test.dart';
import 'package:pookiebudget/data/database/database.dart';
import 'package:pookiebudget/data/repositories/drift_ledger_repository.dart';
import 'package:pookiebudget/domain/entities/enums.dart';
import 'package:pookiebudget/domain/entities/ledger_entry.dart';
import 'package:pookiebudget/domain/repositories/ledger_repository.dart';
import 'package:pookiebudget/domain/repositories/repository_failure.dart';
import 'package:pookiebudget/domain/repositories/repository_queries.dart';
import 'package:pookiebudget/domain/result.dart';

import '../../support/builders/movement_builders.dart';
import '../../support/movement_fixture.dart';
import '../../support/test_database.dart';

void main() {
  late PookieDatabase db;
  late LedgerRepository repo;

  setUp(() async {
    db = await openTestDatabase();
    await seedMovementFixture(db);
    repo = DriftLedgerRepository(db);
  });

  tearDown(() async => db.close());

  void expectOk(Result<void, RepositoryFailure> result) {
    expect(
      result.isSuccess,
      isTrue,
      reason: 'expected the append to succeed, got ${result.failureOrNull}',
    );
  }

  group('append', () {
    test('all entries commit or none do', () async {
      final Result<void, RepositoryFailure> result = await repo.append(
        <LedgerEntry>[
          buildLedgerEntry(id: 'ok-1', amountMinor: 100),
          buildLedgerEntry(
            id: 'bad',
            categoryId: 'no-such-category',
            amountMinor: 100,
          ),
        ],
      );
      expect(result.isSuccess, isFalse);
      expect(
        await rawCount(db, 'ledger_entries'),
        0,
        reason: 'the valid entry written before the failure rolled back too',
      );
    });

    test('an empty batch is a no-op, not an error', () async {
      expectOk(await repo.append(<LedgerEntry>[]));
      expect(await rawCount(db, 'ledger_entries'), 0);
    });
  });

  group('reads', () {
    setUp(() async {
      expectOk(
        await repo.append(<LedgerEntry>[
          buildLedgerEntry(
            id: 'e-jan',
            amountMinor: 1000,
            occurredAtMs: 1000,
          ),
          buildLedgerEntry(
            id: 'e-feb',
            amountMinor: 2000,
            occurredAtMs: 2000,
          ),
          buildLedgerEntry(
            id: 'e-mar',
            categoryId: 'category-transport',
            amountMinor: 3000,
            occurredAtMs: 3000,
          ),
        ]),
      );
    });

    test('entriesForCategory is newest first and scoped to the category',
        () async {
      final List<LedgerEntry> entries = await repo.entriesForCategory(
        'category-groceries',
      );
      expect(entries.map((LedgerEntry e) => e.id), <String>['e-feb', 'e-jan']);
    });

    test('a date range is half-open', () async {
      final List<LedgerEntry> entries = await repo.entriesForCategory(
        'category-groceries',
        within: const DateRange(fromMs: 1000, toMs: 2000),
      );
      expect(
        entries.map((LedgerEntry e) => e.id),
        <String>['e-jan'],
        reason: '2000 belongs to the next range, never this one',
      );
    });

    test('entriesInRange pages without losing order', () async {
      final List<LedgerEntry> page = await repo.entriesInRange(
        const DateRange(fromMs: 0, toMs: 10000),
        limit: 2,
      );
      expect(page.map((LedgerEntry e) => e.id), <String>['e-mar', 'e-feb']);

      final List<LedgerEntry> next = await repo.entriesInRange(
        const DateRange(fromMs: 0, toMs: 10000),
        limit: 2,
        offset: 2,
      );
      expect(next.map((LedgerEntry e) => e.id), <String>['e-jan']);
    });

    test('entriesForSource orders by id, because timestamps tie', () async {
      // Every entry of one event shares a timestamp, so time cannot order
      // them — and a reversal mirrors this list, so an order that varied
      // between reads would pair reversal entries with different originals.
      expectOk(
        await repo.append(<LedgerEntry>[
          buildLedgerEntry(id: 'z', sourceId: 'evt', amountMinor: 1),
          buildLedgerEntry(id: 'a', sourceId: 'evt', amountMinor: 1),
          buildLedgerEntry(id: 'm', sourceId: 'evt', amountMinor: 1),
        ]),
      );
      expect(
        (await repo.entriesForSource('evt')).map((LedgerEntry e) => e.id),
        <String>['a', 'm', 'z'],
      );
    });
  });

  group('allocatedInPeriodMinor', () {
    test('sums allocations within the period only', () async {
      expectOk(
        await repo.append(<LedgerEntry>[
          buildLedgerEntry(id: 'in-1', amountMinor: 1000, occurredAtMs: 100),
          buildLedgerEntry(id: 'in-2', amountMinor: 2000, occurredAtMs: 200),
          buildLedgerEntry(
            id: 'out-of-period',
            amountMinor: 9000,
            occurredAtMs: 9000,
          ),
        ]),
      );

      expect(
        await repo.allocatedInPeriodMinor(
          'category-groceries',
          const DateRange(fromMs: 0, toMs: 1000),
        ),
        3000,
      );
    });

    test('A REVERSAL GIVES BACK THE HEADROOM IT CONSUMED', () async {
      // Leaving REVERSAL out of the sum would make a reversed bill payment
      // permanently occupy its period's capacity — the category would refuse
      // money for the rest of the month because of an allocation that no longer
      // exists.
      expectOk(
        await repo.append(<LedgerEntry>[
          buildLedgerEntry(id: 'alloc', amountMinor: 5000, occurredAtMs: 100),
          buildLedgerEntry(
            id: 'undo',
            direction: LedgerDirection.outbound,
            amountMinor: 5000,
            occurredAtMs: 200,
            sourceType: LedgerSourceType.reversal,
            sourceId: 'rev-evt',
            reversesEntryId: 'alloc',
          ),
        ]),
      );

      expect(
        await repo.allocatedInPeriodMinor(
          'category-groceries',
          const DateRange(fromMs: 0, toMs: 1000),
        ),
        0,
      );
    });

    test('spending does not count against allocation capacity', () async {
      // A fixed-recurring category caps how much may be *allocated* per period,
      // not how much may be spent. Counting spending here would let a paid bill
      // free up capacity to be funded twice.
      expectOk(
        await repo.append(<LedgerEntry>[
          buildLedgerEntry(id: 'alloc', amountMinor: 5000, occurredAtMs: 100),
          buildLedgerEntry(
            id: 'spent',
            direction: LedgerDirection.outbound,
            amountMinor: 5000,
            occurredAtMs: 200,
            sourceType: LedgerSourceType.spending,
            sourceId: 'spend-1',
            reason: null,
            hopCount: null,
          ),
        ]),
      );

      expect(
        await repo.allocatedInPeriodMinor(
          'category-groceries',
          const DateRange(fromMs: 0, toMs: 1000),
        ),
        5000,
      );
    });
  });
}
