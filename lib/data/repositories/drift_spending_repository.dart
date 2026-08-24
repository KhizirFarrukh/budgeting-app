import 'package:drift/drift.dart';
import 'package:pookiebudget/data/database/database.dart';
import 'package:pookiebudget/data/mappers/movement_mappers.dart';
import 'package:pookiebudget/data/repositories/ledger_writer.dart';
import 'package:pookiebudget/data/repositories/repository_support.dart';
import 'package:pookiebudget/domain/entities/enums.dart';
import 'package:pookiebudget/domain/entities/ledger_entry.dart';
import 'package:pookiebudget/domain/entities/spending_transaction.dart';
import 'package:pookiebudget/domain/repositories/repository_failure.dart';
import 'package:pookiebudget/domain/repositories/repository_queries.dart';
import 'package:pookiebudget/domain/repositories/spending_repository.dart';
import 'package:pookiebudget/domain/result.dart';

/// The database-backed [SpendingRepository].
class DriftSpendingRepository implements SpendingRepository {
  DriftSpendingRepository(this._db);

  final PookieDatabase _db;

  // ===========================================================================
  // Writes
  // ===========================================================================

  @override
  Future<Result<void, RepositoryFailure>> record({
    required SpendingTransaction transaction,
    required LedgerEntry entry,
  }) {
    _requirePairing(transaction, entry, LedgerDirection.outbound);
    return writeTransaction(_db, () async {
      requireConservation(
        expectedMinor: transaction.amountMinor,
        entries: <LedgerEntry>[entry],
      );
      await _insertTransaction(transaction);
      await appendLedgerEntries(_db, <LedgerEntry>[entry]);
    });
  }

  @override
  Future<Result<void, RepositoryFailure>> correct({
    required String originalTransactionId,
    required LedgerEntry compensatingEntry,
    required SpendingTransaction replacement,
    required LedgerEntry replacementEntry,
  }) {
    _requirePairing(replacement, replacementEntry, LedgerDirection.outbound);

    return writeTransaction(_db, () async {
      final SpendingTransactionRow? original = await _transactionRow(
        originalTransactionId,
        false,
      );
      if (original == null) {
        reject(
          RecordNotFound(entity: 'transaction', id: originalTransactionId),
        );
      }

      // Correcting twice cancels the original twice and invents money that was
      // never spent. Checked against stored state inside the transaction, for
      // the same reason guard R-1 is.
      final SpendingTransaction? existing = await correctionOf(
        originalTransactionId,
      );
      if (existing != null) {
        reject(
          AlreadyCorrected(
            transactionId: originalTransactionId,
            correctedByTransactionId: existing.id,
          ),
        );
      }

      // The compensating entry must cancel the original **exactly** — same
      // magnitude, opposite direction. Recomputing it from current state would
      // restore the balance to the wrong value if anything changed in between,
      // which is the identical reason a reversal mirrors rather than recomputes
      // (ALLOCATION_ALGORITHM §4.8).
      if (compensatingEntry.direction != LedgerDirection.inbound ||
          compensatingEntry.amountMinor != original.amountMinor) {
        reject(
          ConservationViolated(
            expectedMinor: original.amountMinor,
            actualMinor: compensatingEntry.signedMinor,
            entryCount: 1,
          ),
        );
      }

      // All three rows or none (US-026). The original transaction and its entry
      // are untouched and stay visible; the correction is a new record that
      // points back at what it replaces.
      await appendLedgerEntries(_db, <LedgerEntry>[compensatingEntry]);
      await _insertTransaction(replacement);
      await appendLedgerEntries(_db, <LedgerEntry>[replacementEntry]);
    });
  }

  /// Throws when the entry does not belong to its transaction.
  ///
  /// A caller bug, not a user action, so it throws — consistent with
  /// `IncomeEventRepository.record` refusing a reversal. SCHEMA §3.8 says one
  /// transaction row produces exactly one entry; an entry naming a different
  /// category would make the history screen and the balance disagree, each
  /// correct about a different number and neither able to tell.
  void _requirePairing(
    SpendingTransaction transaction,
    LedgerEntry entry,
    LedgerDirection expected,
  ) {
    final List<String> problems = <String>[
      if (entry.sourceId != transaction.id)
        'entry.sourceId is "${entry.sourceId}", not the transaction id',
      if (entry.categoryId != transaction.categoryId)
        'entry names category "${entry.categoryId}", the transaction names '
            '"${transaction.categoryId}"',
      if (entry.sourceType != LedgerSourceType.spending)
        'entry.sourceType is ${entry.sourceType.wireName}, not SPENDING',
      if (entry.direction != expected)
        'entry.direction is ${entry.direction.wireName}, not '
            '${expected.wireName}',
    ];
    if (problems.isNotEmpty) {
      throw ArgumentError(
        'The ledger entry does not belong to its spending transaction: '
        '${problems.join("; ")}. One transaction row produces exactly one '
        'entry (SCHEMA §3.8).',
      );
    }
  }

  Future<void> _insertTransaction(SpendingTransaction transaction) async {
    await _db
        .into(_db.spendingTransactions)
        .insert(
          spendingTransactionToCompanion(transaction),
          mode: InsertMode.insertOrIgnore,
        );
  }

  // ===========================================================================
  // Reads
  // ===========================================================================

  @override
  Future<List<SpendingTransaction>> transactionsForCategory(
    String categoryId, {
    DateRange? within,
    bool includeDeleted = false,
  }) async {
    final List<SpendingTransactionRow> rows =
        await (_db.select(_db.spendingTransactions)
              ..where(
                (t) =>
                    t.categoryId.equals(categoryId) &
                    tombstoneTerm(
                      t.isDeleted,
                      includeDeleted: includeDeleted,
                    ) &
                    _rangeTerm(t.occurredAtMs, within),
              )
              ..orderBy(_newestFirst()))
            .get();
    return rows.map(spendingTransactionFromRow).toList();
  }

  @override
  Future<List<SpendingTransaction>> transactions({
    DateRange? within,
    int? limit,
    int offset = 0,
    bool includeDeleted = false,
  }) async {
    final SimpleSelectStatement<$SpendingTransactionsTable,
        SpendingTransactionRow> query = _db.select(_db.spendingTransactions)
      ..where(
        (t) =>
            tombstoneTerm(t.isDeleted, includeDeleted: includeDeleted) &
            _rangeTerm(t.occurredAtMs, within),
      )
      ..orderBy(_newestFirst());
    if (limit != null) {
      query.limit(limit, offset: offset);
    }
    final List<SpendingTransactionRow> rows = await query.get();
    return rows.map(spendingTransactionFromRow).toList();
  }

  @override
  Stream<List<SpendingTransaction>> watchTransactionsForCategory(
    String categoryId,
  ) =>
      (_db.select(_db.spendingTransactions)
            ..where(
              (t) =>
                  t.categoryId.equals(categoryId) &
                  tombstoneTerm(t.isDeleted, includeDeleted: false),
            )
            ..orderBy(_newestFirst()))
          .watch()
          .map(
            (List<SpendingTransactionRow> rows) =>
                rows.map(spendingTransactionFromRow).toList(),
          );

  @override
  Future<SpendingTransaction?> transactionById(
    String id, {
    bool includeDeleted = false,
  }) async {
    final SpendingTransactionRow? row = await _transactionRow(
      id,
      includeDeleted,
    );
    return row == null ? null : spendingTransactionFromRow(row);
  }

  @override
  Future<SpendingTransaction?> correctionOf(String transactionId) async {
    final List<SpendingTransactionRow> rows =
        await (_db.select(_db.spendingTransactions)
              ..where(
                (t) =>
                    t.correctsTransactionId.equals(transactionId) &
                    tombstoneTerm(t.isDeleted, includeDeleted: false),
              )
              ..orderBy([(t) => OrderingTerm(expression: t.id)])
              ..limit(1))
            .get();
    return rows.isEmpty ? null : spendingTransactionFromRow(rows.first);
  }

  Future<SpendingTransactionRow?> _transactionRow(
    String id,
    bool includeDeleted,
  ) => (_db.select(_db.spendingTransactions)..where(
        (t) =>
            t.id.equals(id) &
            tombstoneTerm(t.isDeleted, includeDeleted: includeDeleted),
      ))
      .getSingleOrNull();

  List<OrderClauseGenerator<$SpendingTransactionsTable>> _newestFirst() =>
      <OrderClauseGenerator<$SpendingTransactionsTable>>[
        (t) => OrderingTerm(
          expression: t.occurredAtMs,
          mode: OrderingMode.desc,
        ),
        (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
      ];

  Expression<bool> _rangeTerm(GeneratedColumn<int> column, DateRange? range) =>
      range == null
      ? matchAll
      : column.isBiggerOrEqualValue(range.fromMs) &
            column.isSmallerThanValue(range.toMs);
}
