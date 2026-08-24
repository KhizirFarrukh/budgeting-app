import 'package:flutter_test/flutter_test.dart';
import 'package:pookiebudget/data/database/database.dart';
import 'package:pookiebudget/data/repositories/drift_income_event_repository.dart';
import 'package:pookiebudget/data/repositories/drift_ledger_repository.dart';
import 'package:pookiebudget/data/repositories/drift_rule_repository.dart';
import 'package:pookiebudget/domain/entities/income_event.dart';
import 'package:pookiebudget/domain/entities/ledger_entry.dart';
import 'package:pookiebudget/domain/repositories/income_event_repository.dart';
import 'package:pookiebudget/domain/repositories/ledger_repository.dart';
import 'package:pookiebudget/domain/repositories/repository_failure.dart';
import 'package:pookiebudget/domain/result.dart';

import '../../support/builders/movement_builders.dart';
import '../../support/fakes/fake_clock.dart';
import '../../support/movement_fixture.dart';
import '../../support/test_database.dart';

/// Substage 4.5's atomicity and reversal criteria.
void main() {
  late PookieDatabase db;
  late IncomeEventRepository repo;
  late LedgerRepository ledger;

  setUp(() async {
    db = await openTestDatabase();
    await seedMovementFixture(db);
    repo = DriftIncomeEventRepository(db);
    ledger = DriftLedgerRepository(db);
  });

  tearDown(() async => db.close());

  void expectOk(Result<void, RepositoryFailure> result) {
    expect(
      result.isSuccess,
      isTrue,
      reason: 'expected the write to succeed, got ${result.failureOrNull}',
    );
  }

  RepositoryFailure expectRejected(Result<void, RepositoryFailure> result) {
    expect(result.isSuccess, isFalse, reason: 'expected a rejection');
    return result.failureOrNull!;
  }

  // ===========================================================================
  // 4.5.2 — atomicity
  // ===========================================================================

  group('4.5.2 the income write is one transaction', () {
    test('the event and all of its entries commit together', () async {
      final IncomeEvent event = buildIncomeEvent();
      final List<LedgerEntry> entries = allocationEntriesFor(event, <String>[
        'category-groceries',
        'category-transport',
        'category-sink',
      ]);

      expectOk(await repo.record(event: event, entries: entries));

      expect(await repo.eventById('income-1'), isNotNull);
      expect(await ledger.entriesForSource('income-1'), hasLength(3));
    });

    test('A FAILURE MIDWAY LEAVES ZERO ROWS', () async {
      final IncomeEvent event = buildIncomeEvent();
      final List<LedgerEntry> entries = <LedgerEntry>[
        // Valid, and written first.
        buildLedgerEntry(id: 'entry-good', amountMinor: 20000000),
        // Names a category that does not exist. Foreign keys are enforced, so
        // this trips *after* the event row and the first entry are already in
        // the transaction — which is precisely the midway failure the substage
        // asks about, arrived at through a real mechanism rather than a mock.
        buildLedgerEntry(
          id: 'entry-bad',
          categoryId: 'no-such-category',
          amountMinor: 10000000,
        ),
      ];

      final RepositoryFailure failure = expectRejected(
        await repo.record(event: event, entries: entries),
      );
      expect(failure, isA<ConstraintViolation>());

      // Nothing at all survived — not the event, not the entry that succeeded.
      expect(await rawCount(db, 'income_events'), 0);
      expect(await rawCount(db, 'ledger_entries'), 0);
      expect(await repo.eventById('income-1'), isNull);
      expect(await ledger.entryById('entry-good'), isNull);
    });

    test('INV-02 — entries that do not total the amount are refused', () async {
      final IncomeEvent event = buildIncomeEvent(amountMinor: 30000000);
      final RepositoryFailure failure = expectRejected(
        await repo.record(
          event: event,
          entries: <LedgerEntry>[
            buildLedgerEntry(id: 'e1', amountMinor: 20000000),
            // 10,000,000 short. The engine would never produce this, which is
            // the point: the check is here because this is the boundary where a
            // computed split becomes rows that can never be edited.
          ],
        ),
      );
      expect(failure, isA<ConservationViolated>());
      expect((failure as ConservationViolated).expectedMinor, 30000000);
      expect(failure.actualMinor, 20000000);

      expect(await rawCount(db, 'income_events'), 0);
      expect(await rawCount(db, 'ledger_entries'), 0);
    });
  });

  // ===========================================================================
  // 4.5.4 — idempotency
  // ===========================================================================

  group('4.5.4 recording the same event twice is a no-op', () {
    test('a replayed write adds nothing', () async {
      final IncomeEvent event = buildIncomeEvent();
      final List<LedgerEntry> entries = allocationEntriesFor(event, <String>[
        'category-groceries',
        'category-transport',
      ]);

      expectOk(await repo.record(event: event, entries: entries));
      expectOk(await repo.record(event: event, entries: entries));

      expect(await rawCount(db, 'income_events'), 1);
      expect(await rawCount(db, 'ledger_entries'), 2);
    });

    test('A REPLAY CANNOT REWRITE AN EXISTING ENTRY', () async {
      // The half that matters. `insertOrIgnore` skips; `insertOnConflictUpdate`
      // would overwrite — and a retry carrying a different amount under the
      // same id would silently rewrite history, which is an update path wearing
      // an insert's name.
      final IncomeEvent event = buildIncomeEvent(amountMinor: 1000);
      expectOk(
        await repo.record(
          event: event,
          entries: <LedgerEntry>[buildLedgerEntry(id: 'e1', amountMinor: 1000)],
        ),
      );

      expectOk(
        await repo.record(
          event: buildIncomeEvent(amountMinor: 9999),
          entries: <LedgerEntry>[buildLedgerEntry(id: 'e1', amountMinor: 9999)],
        ),
      );

      expect((await repo.eventById('income-1'))!.amountMinor, 1000);
      expect((await ledger.entryById('e1'))!.amountMinor, 1000);
      expect(await rawCount(db, 'ledger_entries'), 1);
    });
  });

  // ===========================================================================
  // INV-11 — sealing happens in the same transaction
  // ===========================================================================

  group('INV-11 the first income event seals its rule version', () {
    test('recording income seals the version it used', () async {
      final DriftRuleRepository rules = DriftRuleRepository(db, FakeClock());
      expect((await rules.versionById('rule-v1'))!.isSealed, isFalse);

      final IncomeEvent event = buildIncomeEvent(recordedAtMs: 1770000000000);
      expectOk(
        await repo.record(
          event: event,
          entries: allocationEntriesFor(event, <String>['category-groceries']),
        ),
      );

      expect((await rules.versionById('rule-v1'))!.sealedAtMs, 1770000000000);
    });

    test('a later event does not move the seal', () async {
      final DriftRuleRepository rules = DriftRuleRepository(db, FakeClock());
      final IncomeEvent first = buildIncomeEvent(recordedAtMs: 1770000000000);
      expectOk(
        await repo.record(
          event: first,
          entries: allocationEntriesFor(first, <String>['category-groceries']),
        ),
      );
      final IncomeEvent second = buildIncomeEvent(
        id: 'income-2',
        recordedAtMs: 1780000000000,
      );
      expectOk(
        await repo.record(
          event: second,
          entries: allocationEntriesFor(second, <String>['category-groceries']),
        ),
      );

      expect(
        (await rules.versionById('rule-v1'))!.sealedAtMs,
        1770000000000,
        reason: 'history became fixed at the first event, not the latest',
      );
    });

    test('a rejected write does not seal', () async {
      final DriftRuleRepository rules = DriftRuleRepository(db, FakeClock());
      expectRejected(
        await repo.record(
          event: buildIncomeEvent(amountMinor: 500),
          entries: <LedgerEntry>[buildLedgerEntry(id: 'e1', amountMinor: 499)],
        ),
      );
      expect(
        (await rules.versionById('rule-v1'))!.isSealed,
        isFalse,
        reason: 'the seal is part of the same transaction, so it rolls back',
      );
    });
  });

  // ===========================================================================
  // 4.5.6 — reversal linkage
  // ===========================================================================

  group('4.5.6 reversal links without altering the original', () {
    late IncomeEvent original;
    late List<LedgerEntry> originalEntries;

    setUp(() async {
      original = buildIncomeEvent();
      originalEntries = allocationEntriesFor(original, <String>[
        'category-groceries',
        'category-transport',
      ]);
      expectOk(await repo.record(event: original, entries: originalEntries));
    });

    IncomeEvent reversalEvent() => buildIncomeEvent(
      id: 'income-rev',
      amountMinor: original.amountMinor,
      isReversal: true,
      reversesEventId: original.id,
      recordedAtMs: 1780000000000,
    );

    test('THE ORIGINAL LEDGER ROWS ARE BYTE-FOR-BYTE UNCHANGED', () async {
      final List<LedgerEntry> before = await ledger.entriesForSource(
        'income-1',
      );

      final IncomeEvent reversal = reversalEvent();
      expectOk(
        await repo.recordReversal(
          originalEventId: 'income-1',
          reversalEvent: reversal,
          reversalEntries: reversalEntriesFor(reversal, originalEntries),
        ),
      );

      final List<LedgerEntry> after = await ledger.entriesForSource('income-1');
      expect(
        after,
        before,
        reason:
            'entity equality covers every field including the sync stamp, so '
            'this asserts nothing about the originals moved at all',
      );
    });

    test('the link is a lookup on the new rows, not a flag on the old',
        () async {
      final IncomeEvent reversal = reversalEvent();
      expectOk(
        await repo.recordReversal(
          originalEventId: 'income-1',
          reversalEvent: reversal,
          reversalEntries: reversalEntriesFor(reversal, originalEntries),
        ),
      );

      for (final LedgerEntry originalEntry in originalEntries) {
        expect(await ledger.isReversed(originalEntry.id), isTrue);
        final LedgerEntry? mirror = await ledger.reversalOf(originalEntry.id);
        expect(mirror!.amountMinor, originalEntry.amountMinor);
        expect(
          mirror.direction,
          isNot(originalEntry.direction),
          reason: 'same magnitude, opposite direction',
        );
      }
    });

    test('the event row carries the one permitted mutation', () async {
      final IncomeEvent reversal = reversalEvent();
      expectOk(
        await repo.recordReversal(
          originalEventId: 'income-1',
          reversalEvent: reversal,
          reversalEntries: reversalEntriesFor(reversal, originalEntries),
        ),
      );

      final IncomeEvent? updated = await repo.eventById('income-1');
      expect(updated!.reversedByEventId, 'income-rev');
      expect(updated.isReversed, isTrue);
    });

    test('R-1 — an event cannot be reversed twice', () async {
      final IncomeEvent reversal = reversalEvent();
      expectOk(
        await repo.recordReversal(
          originalEventId: 'income-1',
          reversalEvent: reversal,
          reversalEntries: reversalEntriesFor(reversal, originalEntries),
        ),
      );

      final IncomeEvent second = buildIncomeEvent(
        id: 'income-rev-2',
        amountMinor: original.amountMinor,
        isReversal: true,
        reversesEventId: original.id,
      );
      final RepositoryFailure failure = expectRejected(
        await repo.recordReversal(
          originalEventId: 'income-1',
          reversalEvent: second,
          reversalEntries: reversalEntriesFor(second, originalEntries),
        ),
      );
      expect(failure, isA<AlreadyReversed>());

      // Reversing twice would silently double the correction, so nothing from
      // the second attempt may survive.
      expect(await repo.eventById('income-rev-2'), isNull);
      expect(await ledger.entriesForSource('income-rev-2'), isEmpty);
      expect(await repo.canReverse('income-1'), isFalse);
    });

    test('R-2 — a reversal cannot itself be reversed', () async {
      final IncomeEvent reversal = reversalEvent();
      expectOk(
        await repo.recordReversal(
          originalEventId: 'income-1',
          reversalEvent: reversal,
          reversalEntries: reversalEntriesFor(reversal, originalEntries),
        ),
      );

      final IncomeEvent undoTheUndo = buildIncomeEvent(
        id: 'income-rev-3',
        amountMinor: original.amountMinor,
        isReversal: true,
        reversesEventId: 'income-rev',
      );
      expect(
        expectRejected(
          await repo.recordReversal(
            originalEventId: 'income-rev',
            reversalEvent: undoTheUndo,
            reversalEntries: reversalEntriesFor(undoTheUndo, originalEntries),
          ),
        ),
        isA<CannotReverseAReversal>(),
      );
      expect(await repo.canReverse('income-rev'), isFalse);
    });

    test('reversing an event that does not exist is rejected', () async {
      final IncomeEvent reversal = reversalEvent();
      expect(
        expectRejected(
          await repo.recordReversal(
            originalEventId: 'never-happened',
            reversalEvent: reversal,
            reversalEntries: reversalEntriesFor(reversal, originalEntries),
          ),
        ),
        isA<RecordNotFound>(),
      );
    });

    test('record() refuses a reversal rather than skipping its guards',
        () async {
      // The hole this closes: record() does not check R-1 or R-2, so a caller
      // using it for a reversal could undo the same income twice. A returned
      // failure would invite handling it; an exception says the code is wrong.
      final IncomeEvent reversal = reversalEvent();
      expect(
        () => repo.record(
          event: reversal,
          entries: reversalEntriesFor(reversal, originalEntries),
        ),
        throwsArgumentError,
      );
    });
  });
}
