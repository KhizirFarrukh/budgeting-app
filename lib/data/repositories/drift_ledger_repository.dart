import 'package:drift/drift.dart';
import 'package:pookiebudget/data/database/database.dart';
import 'package:pookiebudget/data/mappers/movement_mappers.dart';
import 'package:pookiebudget/data/repositories/ledger_writer.dart';
import 'package:pookiebudget/data/repositories/repository_support.dart';
import 'package:pookiebudget/domain/entities/ledger_entry.dart';
import 'package:pookiebudget/domain/repositories/ledger_repository.dart';
import 'package:pookiebudget/domain/repositories/repository_failure.dart';
import 'package:pookiebudget/domain/repositories/repository_queries.dart';
import 'package:pookiebudget/domain/result.dart';

/// The database-backed [LedgerRepository].
///
/// Holds no `Clock`, unlike the configuration repositories. That is not an
/// omission — it is the shape of an append-only store. The other repositories
/// need a clock for the one write they originate, the soft delete. This one
/// originates nothing: every entry arrives fully formed, and there is no
/// deletion to timestamp.
///
/// **No tombstone filter appears in any read below.** Everywhere else in this
/// layer that would be a defect; here C-15 pins `is_deleted` to 0 for every row
/// in the table, so a filter would be a term that can never change the result —
/// and a filter that never matters is a filter that teaches the next reader the
/// wrong thing about this table. `append_only_design_test.dart` asserts the
/// column really is always 0.
class DriftLedgerRepository implements LedgerRepository {
  DriftLedgerRepository(this._db);

  final PookieDatabase _db;

  // ===========================================================================
  // The only write
  // ===========================================================================

  @override
  Future<Result<void, RepositoryFailure>> append(List<LedgerEntry> entries) =>
      writeTransaction(_db, () async {
        await appendLedgerEntries(_db, entries);
      });

  // ===========================================================================
  // Reads
  // ===========================================================================

  @override
  Future<List<LedgerEntry>> entriesForCategory(
    String categoryId, {
    DateRange? within,
  }) async {
    final List<LedgerEntryRow> rows =
        await (_db.select(_db.ledgerEntries)
              ..where(
                (t) =>
                    t.categoryId.equals(categoryId) &
                    _rangeTerm(t.occurredAtMs, within),
              )
              ..orderBy(_newestFirst()))
            .get();
    return rows.map(ledgerEntryFromRow).toList();
  }

  @override
  Stream<List<LedgerEntry>> watchEntriesForCategory(String categoryId) =>
      (_db.select(_db.ledgerEntries)
            ..where((t) => t.categoryId.equals(categoryId))
            ..orderBy(_newestFirst()))
          .watch()
          .map(
            (List<LedgerEntryRow> rows) =>
                rows.map(ledgerEntryFromRow).toList(),
          );

  @override
  Future<List<LedgerEntry>> entriesForSource(String sourceId) async {
    final List<LedgerEntryRow> rows =
        await (_db.select(_db.ledgerEntries)
              ..where((t) => t.sourceId.equals(sourceId))
              // By id, not by time. Every entry of one event shares a
              // timestamp, so time cannot order them — and a reversal mirrors
              // this list, so an order that varied between reads would pair
              // reversal entries with different originals on different runs.
              ..orderBy([(t) => OrderingTerm(expression: t.id)]))
            .get();
    return rows.map(ledgerEntryFromRow).toList();
  }

  @override
  Future<List<LedgerEntry>> entriesInRange(
    DateRange range, {
    int? limit,
    int offset = 0,
  }) async {
    final SimpleSelectStatement<$LedgerEntriesTable, LedgerEntryRow> query =
        _db.select(_db.ledgerEntries)
          ..where((t) => _rangeTerm(t.occurredAtMs, range))
          ..orderBy(_newestFirst());
    if (limit != null) {
      query.limit(limit, offset: offset);
    }
    final List<LedgerEntryRow> rows = await query.get();
    return rows.map(ledgerEntryFromRow).toList();
  }

  @override
  Future<LedgerEntry?> entryById(String id) async {
    final LedgerEntryRow? row =
        await (_db.select(_db.ledgerEntries)..where((t) => t.id.equals(id)))
            .getSingleOrNull();
    return row == null ? null : ledgerEntryFromRow(row);
  }

  @override
  Future<bool> isReversed(String entryId) async =>
      await reversalOf(entryId) != null;

  @override
  Future<LedgerEntry?> reversalOf(String entryId) async {
    final List<LedgerEntryRow> rows =
        await (_db.select(_db.ledgerEntries)
              ..where((t) => t.reversesEntryId.equals(entryId))
              ..orderBy([(t) => OrderingTerm(expression: t.id)])
              ..limit(1))
            .get();
    return rows.isEmpty ? null : ledgerEntryFromRow(rows.first);
  }

  @override
  Future<int> allocatedInPeriodMinor(
    String categoryId,
    DateRange period,
  ) async {
    // Summed in SQL rather than by loading rows and folding. `ledger_entries`
    // is the highest-volume table in the schema, and this runs once per
    // fixed-recurring category on **every** income event — it is on the
    // allocation hot path, not a reporting path.
    //
    // `REVERSAL` is counted alongside `ALLOCATION`, signed, so undoing an
    // allocation gives back the headroom it consumed. Leaving it out would make
    // a reversed bill payment permanently occupy its period's capacity.
    final QueryRow row = await _db
        .customSelect(
          'SELECT COALESCE(SUM('
          "CASE direction WHEN 'IN' THEN amount_minor "
          'ELSE -amount_minor END), 0) AS total '
          'FROM ledger_entries '
          'WHERE category_id = ? '
          'AND occurred_at_ms >= ? AND occurred_at_ms < ? '
          "AND source_type IN ('ALLOCATION','REVERSAL')",
          variables: <Variable<Object>>[
            Variable<String>(categoryId),
            Variable<int>(period.fromMs),
            Variable<int>(period.toMs),
          ],
        )
        .getSingle();
    return row.read<int>('total');
  }

  // ===========================================================================
  // Shared read shapes
  // ===========================================================================

  /// Newest first, `id` breaking the tie.
  ///
  /// The tie-break is not cosmetic: entries written by one event share
  /// `occurred_at_ms` exactly, so without it the history screen's order is
  /// whatever SQLite happens to return, and "whatever it happens to return" is
  /// free to differ between two reads of unchanged data.
  List<OrderClauseGenerator<$LedgerEntriesTable>> _newestFirst() =>
      <OrderClauseGenerator<$LedgerEntriesTable>>[
        (t) => OrderingTerm(
          expression: t.occurredAtMs,
          mode: OrderingMode.desc,
        ),
        (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
      ];

  /// Half-open `[fromMs, toMs)`, or every row when [range] is null.
  Expression<bool> _rangeTerm(GeneratedColumn<int> column, DateRange? range) =>
      range == null
      ? matchAll
      : column.isBiggerOrEqualValue(range.fromMs) &
            column.isSmallerThanValue(range.toMs);
}
