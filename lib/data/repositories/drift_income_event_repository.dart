import 'package:drift/drift.dart';
import 'package:pookiebudget/data/database/database.dart';
import 'package:pookiebudget/data/mappers/movement_mappers.dart';
import 'package:pookiebudget/data/repositories/ledger_writer.dart';
import 'package:pookiebudget/data/repositories/repository_support.dart';
import 'package:pookiebudget/domain/entities/income_event.dart';
import 'package:pookiebudget/domain/entities/ledger_entry.dart';
import 'package:pookiebudget/domain/repositories/income_event_repository.dart';
import 'package:pookiebudget/domain/repositories/repository_failure.dart';
import 'package:pookiebudget/domain/repositories/repository_queries.dart';
import 'package:pookiebudget/domain/result.dart';

/// The database-backed [IncomeEventRepository].
class DriftIncomeEventRepository implements IncomeEventRepository {
  DriftIncomeEventRepository(this._db);

  final PookieDatabase _db;

  // ===========================================================================
  // Writes
  // ===========================================================================

  @override
  Future<Result<void, RepositoryFailure>> record({
    required IncomeEvent event,
    required List<LedgerEntry> entries,
  }) {
    // Throws rather than returning a failure, because this is a **caller bug,
    // not a user action**, and the specific bug is dangerous: routing a
    // reversal through here would skip guards R-1 and R-2 entirely, letting the
    // same income be undone twice. A returned failure invites a caller to
    // handle it and move on; an exception says the code is wrong.
    if (event.isReversal) {
      throw ArgumentError.value(
        event.id,
        'event',
        'A reversal must be written through recordReversal, which enforces '
            'guards R-1 and R-2. Recording one here would bypass both.',
      );
    }

    return writeTransaction(_db, () async {
      requireConservation(expectedMinor: event.amountMinor, entries: entries);
      await _insertEvent(event);
      await appendLedgerEntries(_db, entries);
      await _sealRuleVersion(event.ruleVersionId, atMs: event.recordedAtMs);
    });
  }

  @override
  Future<Result<void, RepositoryFailure>> recordReversal({
    required String originalEventId,
    required IncomeEvent reversalEvent,
    required List<LedgerEntry> reversalEntries,
  }) => writeTransaction(_db, () async {
    final IncomeEventRow? original = await _eventRow(originalEventId, false);
    if (original == null) {
      reject(RecordNotFound(entity: 'income entry', id: originalEventId));
    }

    // Both guards are checked against the **stored** original rather than
    // against whatever the caller believed when it built the reversal. Two
    // devices can independently decide to undo the same event, and the one that
    // commits second must be refused — a check made before the transaction
    // opened would not see the first.
    if (original.isReversal) {
      reject(CannotReverseAReversal(originalEventId));
    }
    if (original.reversedByEventId != null) {
      reject(
        AlreadyReversed(
          eventId: originalEventId,
          reversedByEventId: original.reversedByEventId!,
        ),
      );
    }

    requireConservation(
      expectedMinor: reversalEvent.amountMinor,
      entries: reversalEntries,
    );

    await _insertEvent(reversalEvent);
    await appendLedgerEntries(_db, reversalEntries);

    // The one permitted mutation in this design: a column on the *event* row,
    // never on a ledger entry. `AND reversed_by_event_id IS NULL` makes guard
    // R-1 atomic rather than merely checked — if a concurrent transaction won
    // the race, this matches zero rows and the mismatch below rolls everything
    // back.
    final int linked = await _db.customUpdate(
      'UPDATE income_events '
      'SET reversed_by_event_id = ?, updated_at_ms = ? '
      'WHERE id = ? AND reversed_by_event_id IS NULL',
      variables: <Variable<Object>>[
        Variable<String>(reversalEvent.id),
        Variable<int>(reversalEvent.recordedAtMs),
        Variable<String>(originalEventId),
      ],
      updates: <TableInfo<Table, Object?>>{_db.incomeEvents},
    );
    if (linked != 1) {
      reject(
        AlreadyReversed(
          eventId: originalEventId,
          reversedByEventId: reversalEvent.id,
        ),
      );
    }

    await _sealRuleVersion(
      reversalEvent.ruleVersionId,
      atMs: reversalEvent.recordedAtMs,
    );
  });

  /// Idempotent by id (INV-12) — see `appendLedgerEntries` for why this is
  /// ignore-on-conflict and never upsert.
  Future<void> _insertEvent(IncomeEvent event) async {
    await _db
        .into(_db.incomeEvents)
        .insert(
          incomeEventToCompanion(event),
          mode: InsertMode.insertOrIgnore,
        );
  }

  /// Freezes the percentages this event was split by, in the same transaction.
  ///
  /// `AND sealed_at_ms IS NULL` makes it idempotent *and* keeps the first
  /// instant: the moment history became fixed is the moment of the first income
  /// event, not the latest. Zero rows matched simply means it was already
  /// sealed, which is the normal case for every event after the first — so this
  /// deliberately does not check the row count.
  ///
  /// A missing or tombstoned version needs no check here: `income_events`
  /// carries a foreign key to it, so the insert above has already failed.
  Future<void> _sealRuleVersion(String versionId, {required int atMs}) async {
    await _db.customUpdate(
      'UPDATE distribution_rule_versions '
      'SET sealed_at_ms = ?, updated_at_ms = ? '
      'WHERE id = ? AND sealed_at_ms IS NULL AND is_deleted = 0',
      variables: <Variable<Object>>[
        Variable<int>(atMs),
        Variable<int>(atMs),
        Variable<String>(versionId),
      ],
      updates: <TableInfo<Table, Object?>>{_db.distributionRuleVersions},
    );
  }

  // ===========================================================================
  // Reads
  // ===========================================================================

  @override
  Future<List<IncomeEvent>> events({
    DateRange? within,
    int? limit,
    int offset = 0,
    bool includeDeleted = false,
  }) async {
    final SimpleSelectStatement<$IncomeEventsTable, IncomeEventRow> query =
        _db.select(_db.incomeEvents)
          ..where(
            (t) =>
                tombstoneTerm(t.isDeleted, includeDeleted: includeDeleted) &
                (within == null
                    ? matchAll
                    : t.occurredAtMs.isBiggerOrEqualValue(within.fromMs) &
                          t.occurredAtMs.isSmallerThanValue(within.toMs)),
          )
          ..orderBy([
            (t) => OrderingTerm(
              expression: t.occurredAtMs,
              mode: OrderingMode.desc,
            ),
            (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
          ]);
    if (limit != null) {
      query.limit(limit, offset: offset);
    }
    final List<IncomeEventRow> rows = await query.get();
    return rows.map(incomeEventFromRow).toList();
  }

  @override
  Stream<List<IncomeEvent>> watchEvents({int? limit}) {
    final SimpleSelectStatement<$IncomeEventsTable, IncomeEventRow> query =
        _db.select(_db.incomeEvents)
          ..where((t) => tombstoneTerm(t.isDeleted, includeDeleted: false))
          ..orderBy([
            (t) => OrderingTerm(
              expression: t.occurredAtMs,
              mode: OrderingMode.desc,
            ),
            (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
          ]);
    if (limit != null) {
      query.limit(limit);
    }
    return query.watch().map(
      (List<IncomeEventRow> rows) => rows.map(incomeEventFromRow).toList(),
    );
  }

  @override
  Future<IncomeEvent?> eventById(
    String id, {
    bool includeDeleted = false,
  }) async {
    final IncomeEventRow? row = await _eventRow(id, includeDeleted);
    return row == null ? null : incomeEventFromRow(row);
  }

  @override
  Future<bool> canReverse(String eventId) async {
    final IncomeEventRow? row = await _eventRow(eventId, false);
    if (row == null) return false;
    return !row.isReversal && row.reversedByEventId == null;
  }

  Future<IncomeEventRow?> _eventRow(String id, bool includeDeleted) =>
      (_db.select(_db.incomeEvents)..where(
            (t) =>
                t.id.equals(id) &
                tombstoneTerm(t.isDeleted, includeDeleted: includeDeleted),
          ))
          .getSingleOrNull();
}
