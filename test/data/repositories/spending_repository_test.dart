import 'package:flutter_test/flutter_test.dart';
import 'package:pookiebudget/data/database/database.dart';
import 'package:pookiebudget/data/repositories/drift_ledger_repository.dart';
import 'package:pookiebudget/data/repositories/drift_spending_repository.dart';
import 'package:pookiebudget/domain/entities/enums.dart';
import 'package:pookiebudget/domain/entities/ledger_entry.dart';
import 'package:pookiebudget/domain/entities/spending_transaction.dart';
import 'package:pookiebudget/domain/repositories/ledger_repository.dart';
import 'package:pookiebudget/domain/repositories/repository_failure.dart';
import 'package:pookiebudget/domain/repositories/spending_repository.dart';
import 'package:pookiebudget/domain/result.dart';

import '../../support/builders/movement_builders.dart';
import '../../support/movement_fixture.dart';
import '../../support/test_database.dart';

void main() {
  late PookieDatabase db;
  late SpendingRepository repo;
  late LedgerRepository ledger;

  setUp(() async {
    db = await openTestDatabase();
    await seedMovementFixture(db);
    repo = DriftSpendingRepository(db);
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

  group('record', () {
    test('the transaction and its single OUT entry commit together', () async {
      final SpendingTransaction txn = buildSpending();
      expectOk(
        await repo.record(transaction: txn, entry: spendingEntryFor(txn)),
      );

      expect(await repo.transactionById('spend-1'), isNotNull);
      final List<LedgerEntry> entries =
          await ledger.entriesForSource('spend-1');
      expect(entries, hasLength(1));
      expect(entries.single.direction, LedgerDirection.outbound);
      expect(entries.single.signedMinor, -250000);
    });

    test('a failure leaves neither row', () async {
      final SpendingTransaction txn = buildSpending(
        categoryId: 'no-such-category',
      );
      expectRejected(
        await repo.record(transaction: txn, entry: spendingEntryFor(txn)),
      );
      expect(await rawCount(db, 'spending_transactions'), 0);
      expect(await rawCount(db, 'ledger_entries'), 0);
    });

    test('an entry that does not belong to its transaction throws', () async {
      // A caller bug, not a user action. An entry naming a different category
      // would make the history screen and the balance disagree, each correct
      // about a different number and neither able to tell.
      final SpendingTransaction txn = buildSpending();
      expect(
        () => repo.record(
          transaction: txn,
          entry: buildLedgerEntry(
            id: 'mismatched',
            categoryId: 'category-transport',
            direction: LedgerDirection.outbound,
            amountMinor: txn.amountMinor,
            sourceType: LedgerSourceType.spending,
            sourceId: txn.id,
            reason: null,
            hopCount: null,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('a re-recorded transaction is a no-op', () async {
      final SpendingTransaction txn = buildSpending();
      expectOk(
        await repo.record(transaction: txn, entry: spendingEntryFor(txn)),
      );
      expectOk(
        await repo.record(transaction: txn, entry: spendingEntryFor(txn)),
      );

      expect(await rawCount(db, 'spending_transactions'), 1);
      expect(await rawCount(db, 'ledger_entries'), 1);
    });
  });

  group('correct supersedes rather than edits', () {
    late SpendingTransaction original;

    setUp(() async {
      original = buildSpending(amountMinor: 250000);
      expectOk(
        await repo.record(
          transaction: original,
          entry: spendingEntryFor(original),
        ),
      );
    });

    /// The three rows US-026 describes: a compensating `IN` cancelling the
    /// original's `OUT`, a replacement transaction, and its own `OUT`.
    Future<Result<void, RepositoryFailure>> correctTo(
      int amountMinor, {
      String replacementId = 'spend-2',
    }) {
      final SpendingTransaction replacement = buildSpending(
        id: replacementId,
        amountMinor: amountMinor,
        isCorrection: true,
        correctsTransactionId: original.id,
      );
      return repo.correct(
        originalTransactionId: original.id,
        compensatingEntry: buildLedgerEntry(
          id: '$replacementId-compensating',
          direction: LedgerDirection.inbound,
          amountMinor: original.amountMinor,
          sourceType: LedgerSourceType.spending,
          sourceId: replacementId,
          reason: null,
          hopCount: null,
          reversesEntryId: '${original.id}-entry',
        ),
        replacement: replacement,
        replacementEntry: spendingEntryFor(replacement),
      );
    }

    test('ALL THREE ROWS COMMIT, AND THE ORIGINAL IS UNTOUCHED', () async {
      final List<LedgerEntry> before = await ledger.entriesForSource('spend-1');
      expectOk(await correctTo(180000));

      expect(
        await ledger.entriesForSource('spend-1'),
        before,
        reason:
            'the original transaction and its entry stay exactly as written',
      );
      expect(await repo.transactionById('spend-1'), isNotNull);

      expect(await rawCount(db, 'spending_transactions'), 2);
      expect(await rawCount(db, 'ledger_entries'), 3);

      // Net effect: the original 250,000 cancelled, 180,000 spent instead.
      final int net = (await ledger.entriesForCategory('category-groceries'))
          .fold<int>(0, (int acc, LedgerEntry e) => acc + e.signedMinor);
      expect(net, -180000);
    });

    test('the link is a lookup on the successor', () async {
      expectOk(await correctTo(180000));
      final SpendingTransaction? correction =
          await repo.correctionOf('spend-1');
      expect(correction!.id, 'spend-2');
      expect(correction.isCorrection, isTrue);
    });

    test('correcting twice is refused', () async {
      expectOk(await correctTo(180000));
      final RepositoryFailure failure = expectRejected(
        await correctTo(170000, replacementId: 'spend-3'),
      );
      expect(failure, isA<AlreadyCorrected>());

      // Correcting twice would cancel the original twice and invent money that
      // was never spent, so nothing from the second attempt may survive.
      expect(await repo.transactionById('spend-3'), isNull);
      expect(await rawCount(db, 'ledger_entries'), 3);
    });

    test('a compensating entry that does not cancel exactly is refused',
        () async {
      final SpendingTransaction replacement = buildSpending(
        id: 'spend-4',
        amountMinor: 180000,
        isCorrection: true,
        correctsTransactionId: original.id,
      );
      final RepositoryFailure failure = expectRejected(
        await repo.correct(
          originalTransactionId: original.id,
          compensatingEntry: buildLedgerEntry(
            id: 'short-compensation',
            direction: LedgerDirection.inbound,
            // 250,000 was spent; cancelling only 200,000 leaves 50,000
            // permanently missing from the category, and the ledger is
            // append-only so nothing can quietly fix it later.
            amountMinor: 200000,
            sourceType: LedgerSourceType.spending,
            sourceId: 'spend-4',
            reason: null,
            hopCount: null,
          ),
          replacement: replacement,
          replacementEntry: spendingEntryFor(replacement),
        ),
      );
      expect(failure, isA<ConservationViolated>());
      expect(await rawCount(db, 'ledger_entries'), 1);
      expect(await rawCount(db, 'spending_transactions'), 1);
    });
  });
}
